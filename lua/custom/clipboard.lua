local M = {}

local function warn(message)
  vim.schedule(function()
    vim.notify('Clipboard bridge: ' .. message, vim.log.levels.WARN)
  end)
end

---@param socket string
---@return integer? channel
local function connect(socket)
  -- An inherited NVIM should identify the parent, never this instance.
  if vim.tbl_contains(vim.fn.serverlist(), socket) then
    return nil
  end
  local ok, channel = pcall(vim.fn.sockconnect, 'pipe', socket, { rpc = true })
  if not ok or channel <= 0 then
    warn('cannot connect to parent Neovim at ' .. socket)
    return nil
  end
  local valid, pid = pcall(vim.rpcrequest, channel, 'nvim_call_function', 'getpid', {})
  if not valid or pid == vim.fn.getpid() then
    vim.fn.chanclose(channel)
    warn 'NVIM does not identify another reachable Neovim'
    return nil
  end
  return channel
end

---@param channel integer
---@return table
local function parent_provider(channel)
  local reported_failure = false
  local function request(code, args)
    local ok, result = pcall(vim.rpcrequest, channel, 'nvim_exec_lua', code, args)
    if not ok then
      local message = 'parent Neovim request failed: ' .. tostring(result)
      -- Neovim may replace callback errors with "provider returned invalid
      -- data". Keep the actual cause visible, without repeating it on each p.
      if not reported_failure then
        reported_failure = true
        warn(message)
      end
      error('Clipboard bridge: ' .. message, 0)
    end
    return result
  end

  local function copy(lines, regtype)
    -- Clipboard providers append an empty-string marker to linewise and
    -- blockwise text. setreg() with a List expects only actual buffer lines.
    local contents = vim.deepcopy(lines)
    if regtype ~= 'v' and contents[#contents] == '' then
      table.remove(contents)
    end
    request(
      [[
      local lines, regtype = ...
      vim.fn.setreg('"', lines, regtype)
      -- Keep normal p consistent if the parent has its own clipboard provider.
      -- In particular, this also supports an explicitly configured OSC 52 copier.
      -- No clipboard read is needed, and a provider is not required.
      if vim.fn.has('clipboard') == 1 then
        vim.fn.setreg('+', lines, regtype)
      end
    ]],
      { contents, regtype }
    )
  end

  local function paste()
    -- One request keeps contents and type together. Explicitly reading the
    -- unnamed register bypasses the parent's system clipboard provider. The
    -- provider protocol accepts a one-character type; block width is inferred.
    return request(
      [[
      local reg = vim.fn.getreginfo('"')
      return { reg.regcontents or {}, (reg.regtype or 'v'):sub(1, 1) }
    ]],
      {}
    )
  end

  return {
    name = 'Parent Neovim registers',
    copy = { ['+'] = copy, ['*'] = copy },
    paste = { ['+'] = paste, ['*'] = paste },
    cache_enabled = 0, -- Always read the parent's latest register, not a local copy.
  }
end

--- Share the parent's unnamed register only when no native clipboard is detected.
--- Call early in init.lua, after setting 'clipboard' and before loading plugins.
---@param opts? { mode?: 'auto'|'parent'|'off' }
function M.setup(opts)
  local mode = (opts or {}).mode or 'auto'
  assert(mode == 'auto' or mode == 'parent' or mode == 'off', 'Invalid clipboard bridge mode: ' .. tostring(mode))
  if mode == 'off' then
    return
  end
  -- Respect user-supplied providers. g:clipboard=false requests built-in detection.
  if vim.g.clipboard ~= nil and vim.g.clipboard ~= false then
    return
  end
  local socket = vim.env.NVIM
  if not socket or socket == '' then
    return -- Standalone editor: desktop/SSH clipboard configuration is independent.
  end

  -- Reuse Neovim's platform-specific detection (macOS, Wayland, X11, Windows,
  -- tmux, etc.), rather than treating SSH alone as evidence of no clipboard.
  if mode == 'auto' then
    local provider = vim.fn['provider#clipboard#Executable']()
    if provider ~= '' and provider ~= 'OSC 52' then
      return
    end
  end
  -- OSC 52 is not a usable fallback for reading inside a :terminal buffer.
  local channel = connect(socket)
  if not channel then
    return
  end
  vim.g.clipboard = parent_provider(channel)
  -- Detection above initializes the built-in provider. Reload its callbacks now
  -- that g:clipboard has changed (see :help faq-runtime).
  vim.g.loaded_clipboard_provider = nil
  vim.cmd 'runtime autoload/provider/clipboard.vim'
end

return M
