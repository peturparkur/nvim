-- Run from the repository root: nvim --headless -u NONE -i NONE -l tests/clipboard.lua
-- Real isolated Neovim processes exercise provider callbacks, RPC and normal y/p.
local root = vim.fn.getcwd()
local temp = vim.fn.tempname()
vim.fn.mkdir(temp, 'p')
local jobs = {}
local passed = 0

local function exec(job, code, ...)
  return vim.rpcrequest(job, 'nvim_exec_lua', code, { ... })
end

local function editor(env)
  local clean_env = { SSH_CONNECTION = '', SSH_TTY = '', NVIM = '', DISPLAY = '', WAYLAND_DISPLAY = '', TMUX = '', PATH = temp }
  local job = vim.fn.jobstart({ vim.v.progpath, '--embed', '--headless', '-u', 'NONE', '-i', 'NONE', '-n' }, {
    rpc = true,
    env = vim.tbl_extend('force', clean_env, env or {}),
  })
  assert(job > 0, 'failed to start Neovim')
  jobs[#jobs + 1] = job
  exec(
    job,
    [[
    vim.opt.rtp:prepend(...)
    vim.opt.clipboard = 'unnamedplus'
  ]],
    root
  )
  return job
end

local function setup(job, mode)
  exec(job, [[require('custom.clipboard').setup { mode = ... }]], mode or 'auto')
end

local function check(name, fn)
  fn()
  passed = passed + 1
  print('PASS ' .. name)
end

local function equal(expected, actual)
  assert(vim.deep_equal(expected, actual), 'expected ' .. vim.inspect(expected) .. ', got ' .. vim.inspect(actual))
end

local function provider(job)
  return exec(job, [[return vim.fn['provider#clipboard#Executable']()]])
end

local function reg(job, name)
  return exec(job, [[local r = vim.fn.getreginfo(...); return { r.regcontents or {}, r.regtype or 'v' }]], name or '"')
end

local function setreg(job, lines, regtype)
  exec(job, [[local lines, regtype = ...; vim.fn.setreg('"', lines, regtype)]], lines, regtype)
end

local function yank(job, lines, command)
  exec(
    job,
    [[
    local lines, command = ...
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
    vim.cmd('normal! ' .. command)
  ]],
    lines,
    command
  )
end

local ok, err = xpcall(function()
  local parent = editor()
  local socket = exec(parent, [[return vim.fn.serverstart(...)]], temp .. '/parent.sock')

  check('standalone SSH uses write-only OSC 52', function()
    local remote = editor { SSH_CONNECTION = 'test' }
    setup(remote)
    equal('OSC 52 copy (local paste cache)', provider(remote))
  end)

  check('SSH terminal-buffer yanks reach OSC 52 without clipboard reads', function()
    local remote = editor { SSH_TTY = '/dev/pts/test' }
    exec(remote, [[
      _G.copies = {}
      package.loaded['vim.ui.clipboard.osc52'] = {
        copy = function(register)
          return function(lines)
            table.insert(_G.copies, { register, vim.deepcopy(lines) })
          end
        end,
        paste = function() error('must not query the terminal clipboard') end,
      }
    ]])
    equal('', provider(remote)) -- Also exercise reloading unavailable callbacks.
    setup(remote)
    equal('OSC 52 copy (local paste cache)', provider(remote))
    equal({ {}, 'v' }, reg(remote, '+'))
    exec(remote, [[
      local channel = vim.api.nvim_open_term(0, {})
      vim.api.nvim_chan_send(channel, 'LLM response: λ雪\r\nsecond line\r\n')
      vim.wait(50)
      assert(vim.bo.buftype == 'terminal')
      vim.cmd 'normal! gg0v15ly'
    ]])
    equal({ '+', { 'LLM response: λ雪' } }, exec(remote, [[return _G.copies[#_G.copies] ]]))
    equal({ { 'LLM response: λ雪' }, 'v' }, reg(remote, '+'))
    exec(remote, [[vim.fn.setreg('+', { 'first', '' }, 'V')]])
    equal({ { 'first', '' }, 'V' }, reg(remote, '+'))
    exec(remote, [[vim.fn.setreg('*', { 'ab', 'cd' }, '\0222')]])
    equal({ { 'ab', 'cd' }, '\0222' }, reg(remote, '*'))
    equal({ { 'first', '' }, 'V' }, reg(remote, '+'))
    local messages = exec(remote, [[return vim.fn.execute('messages')]])
    assert(not messages:find('E319', 1, true), messages)
  end)

  check('standalone without SSH is unchanged', function()
    local standalone = editor()
    setup(standalone)
    equal('', provider(standalone))
    equal(true, exec(standalone, [[return vim.g.clipboard == nil]]))
  end)

  check('off mode also disables the SSH fallback', function()
    local remote = editor { SSH_CONNECTION = 'test' }
    setup(remote, 'off')
    equal('', provider(remote))
  end)

  check('explicit SSH providers are preserved', function()
    local remote = editor { SSH_CONNECTION = 'test' }
    exec(remote, [[vim.g.clipboard = 'osc52']])
    setup(remote)
    equal('OSC 52', provider(remote))
  end)

  check('SSH fallback emits an OSC 52 write, never a read query', function()
    local remote = editor { SSH_CONNECTION = 'test' }
    exec(remote, [[
      _G.writes = {}
      vim.api.nvim_ui_send = function(text) table.insert(_G.writes, text) end
    ]])
    setup(remote)
    yank(remote, { 'λ雪' }, 'ggyy')
    equal({ '\027]52;c;' .. vim.base64.encode('λ雪\n') .. '\027\\' }, exec(remote, [[return _G.writes]]))
    equal({ { 'λ雪' }, 'V' }, reg(remote, '+'))
    exec(remote, [[vim.cmd 'normal! ggp']])
    equal({ 'λ雪', 'λ雪' }, exec(remote, [[return vim.api.nvim_buf_get_lines(0, 0, -1, false)]]))
    equal(1, exec(remote, [[return #_G.writes]]))
  end)

  check('nested editor copies through the SSH parent to the local terminal', function()
    local remote = editor { SSH_CONNECTION = 'test' }
    exec(remote, [[
      _G.writes = {}
      vim.api.nvim_ui_send = function(text) table.insert(_G.writes, text) end
    ]])
    setup(remote)
    local remote_socket = exec(remote, [[return vim.fn.serverstart(...)]], temp .. '/remote.sock')
    local nested = editor { NVIM = remote_socket, SSH_CONNECTION = 'test' }
    setup(nested)
    equal('Parent Neovim registers', provider(nested))
    yank(nested, { 'from inner editor' }, 'ggyy')
    equal({ { 'from inner editor' }, 'V' }, reg(remote, '+'))
    equal({ { 'from inner editor' }, 'V' }, reg(nested, '+'))
    equal({ '\027]52;c;' .. vim.base64.encode('from inner editor\n') .. '\027\\' }, exec(remote, [[return _G.writes]]))
  end)

  local child = editor { NVIM = socket, SSH_CONNECTION = 'test' }
  check('nested SSH chooses the bridge', function()
    -- Exercise replacing a provider that was already initialized as unavailable.
    equal('', provider(child))
    setup(child)
    equal('Parent Neovim registers', provider(child))
  end)

  check('nesting without SSH also works when no native provider exists', function()
    local nested = editor { NVIM = socket, SSH_CONNECTION = '' }
    setup(nested)
    equal('Parent Neovim registers', provider(nested))
  end)

  check('an initially empty parent register is safe to paste', function()
    equal({ {}, 'v' }, reg(child, '+'))
  end)

  check('false explicitly requests built-in detection, not an override', function()
    local nested = editor { NVIM = socket }
    exec(nested, [[vim.g.clipboard = false]])
    setup(nested)
    equal('Parent Neovim registers', provider(nested))
  end)

  check('auto-detected OSC 52 is replaced for nested reads', function()
    local nested = editor { NVIM = socket }
    exec(nested, [[vim.opt.clipboard = ''; vim.g.termfeatures = { osc52 = true }]])
    equal('OSC 52', provider(nested))
    setup(nested)
    equal('Parent Neovim registers', provider(nested))
  end)

  check('parent linewise yank pastes normally in the child', function()
    yank(parent, { 'first', 'second' }, 'ggVjy')
    equal({ { 'first', 'second' }, 'V' }, reg(child, '+'))
    exec(
      child,
      [[
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'destination' })
      vim.cmd 'normal! ggp'
    ]]
    )
    equal({ 'destination', 'first', 'second' }, exec(child, [[return vim.api.nvim_buf_get_lines(0, 0, -1, false)]]))
  end)

  check('characterwise and blockwise register types survive RPC', function()
    for _, kind in ipairs { 'v', '\0224' } do
      setreg(parent, { 'abcd', 'efgh' }, kind)
      equal({ { 'abcd', 'efgh' }, kind }, reg(child, '+'))
    end
  end)

  check('paste reads subsequent parent yanks, not a stale local cache', function()
    setreg(parent, { 'new value' }, 'v')
    equal({ { 'new value' }, 'v' }, reg(child, '+'))
    equal({ { 'new value' }, 'v' }, reg(child, '*'))
  end)

  check('Unicode and a characterwise trailing newline survive in both directions', function()
    yank(child, { 'λ', '雪' }, 'gg0vj0y')
    equal({ { 'λ', '雪' }, 'v' }, reg(parent))
    exec(child, [[vim.fn.setreg('+', { 'λ', '' }, 'v')]])
    equal({ { 'λ', '' }, 'v' }, reg(parent))
    setreg(parent, { '雪', 'λ' }, 'v')
    equal({ { '雪', 'λ' }, 'v' }, reg(child, '+'))
  end)

  check('child linewise yank updates parent without adding a blank line', function()
    yank(child, { 'back', '', 'to parent' }, 'ggV2jy')
    equal({ { 'back', '', 'to parent' }, 'V' }, reg(parent))
    exec(
      parent,
      [[
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'destination' })
      vim.cmd 'normal! ggp'
    ]]
    )
    equal({ 'destination', 'back', '', 'to parent' }, exec(parent, [[return vim.api.nvim_buf_get_lines(0, 0, -1, false)]]))
  end)

  check('linewise text ending in an actual blank line retains that line', function()
    yank(child, { 'last', '' }, 'ggVjy')
    equal({ { 'last', '' }, 'V' }, reg(parent))
  end)

  check('child characterwise and blockwise yanks retain their types', function()
    yank(child, { 'abcd' }, 'gg0v2ly')
    equal({ { 'abc' }, 'v' }, reg(parent))
    yank(child, { 'abcd', 'efgh' }, 'gg0\022jly')
    equal({ { 'ab', 'ef' }, '\0222' }, reg(parent))
  end)

  check('explicit providers are preserved, even in parent mode', function()
    local explicit = editor { NVIM = socket }
    exec(explicit, [[vim.g.clipboard = 'osc52']])
    setup(explicit, 'parent')
    equal('OSC 52', provider(explicit))
  end)

  check('off mode disables the bridge', function()
    local disabled = editor { NVIM = socket }
    setup(disabled, 'off')
    equal('', provider(disabled))
  end)

  -- Give Neovim a detectable Wayland provider without requiring a real desktop.
  local native_dir = temp .. '/native'
  vim.fn.mkdir(native_dir, 'p')
  for _, name in ipairs { 'wl-copy', 'wl-paste' } do
    local path = native_dir .. '/' .. name
    vim.fn.writefile({ '#!/bin/sh', 'exit 0' }, path)
    vim.fn.setfperm(path, 'rwx------')
  end
  check('native Wayland provider wins on a nested desktop session', function()
    local desktop = editor { NVIM = socket, PATH = native_dir, WAYLAND_DISPLAY = 'test-display' }
    setup(desktop)
    equal('wl-copy', provider(desktop))
    equal(true, exec(desktop, [[return vim.g.clipboard == nil]]))
  end)

  check('native provider wins for standalone SSH too', function()
    local remote = editor { SSH_CONNECTION = 'test', PATH = native_dir, WAYLAND_DISPLAY = 'test-display' }
    setup(remote)
    equal('wl-copy', provider(remote))
    equal(true, exec(remote, [[return vim.g.clipboard == nil]]))
  end)

  check('parent mode overrides native detection', function()
    local forced = editor { NVIM = socket, PATH = native_dir, WAYLAND_DISPLAY = 'test-display' }
    setup(forced, 'parent')
    equal('Parent Neovim registers', provider(forced))
  end)

  check('a broken inherited socket leaves configuration unchanged', function()
    local stale = editor { NVIM = temp .. '/missing.sock' }
    setup(stale)
    equal('', provider(stale))
    equal(true, exec(stale, [[return vim.g.clipboard == nil]]))
  end)

  check('a socket belonging to this instance is rejected', function()
    local self = editor()
    exec(self, [[vim.env.NVIM = vim.fn.serverstart(...)]], temp .. '/self.sock')
    setup(self)
    equal('', provider(self))
  end)

  check('copying also updates a configured parent clipboard', function()
    exec(
      parent,
      [[
      local data = { {}, 'v' }
      local function copy(lines, kind) data = { lines, kind } end
      local function paste() return data end
      vim.g.clipboard = {
        name = 'Test clipboard',
        copy = { ['+'] = copy, ['*'] = copy },
        paste = { ['+'] = paste, ['*'] = paste },
      }
      vim.g.loaded_clipboard_provider = nil
      vim.cmd 'runtime autoload/provider/clipboard.vim'
    ]]
    )
    yank(child, { 'shared clipboard' }, 'ggyy')
    equal({ { 'shared clipboard' }, 'V' }, reg(parent))
    equal({ { 'shared clipboard' }, 'V' }, reg(parent, '+'))
  end)

  check('lost parent connections report errors rather than empty clipboard data', function()
    vim.fn.jobstop(parent)
    vim.fn.jobwait({ parent }, 2000)
    local success, message = pcall(exec, child, [[return vim.g.clipboard.paste['+']()]])
    equal(false, success)
    local lookup_ok, lookup_error = pcall(reg, child, '+')
    equal(false, lookup_ok)
    assert(tostring(lookup_error):find('provider returned invalid data', 1, true), tostring(lookup_error))
    local messages = exec(child, [[vim.wait(20); return vim.fn.execute('messages')]])
    assert(messages:find('parent Neovim request failed', 1, true), messages)
    assert(tostring(message):find('parent Neovim request failed', 1, true), tostring(message))
  end)
end, debug.traceback)

for _, job in ipairs(jobs) do
  pcall(vim.fn.jobstop, job)
end
vim.fn.jobwait(jobs, 2000)
vim.fn.delete(temp, 'rf')
if not ok then
  io.stderr:write(tostring(err) .. '\n')
  vim.cmd 'cquit 1'
end
print(string.format('%d clipboard integration tests passed', passed))
