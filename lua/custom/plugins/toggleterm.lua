-- Floating toggleterms with a centered title bar, <C-h>/<C-l> cycling and
-- :TermClose, which kills the current terminal instance while keeping the rest.
return {
  'akinsho/toggleterm.nvim',
  version = '9a88eae817ef395952e08650b3283726786fb5fb', -- want commit version since latest release does not contain TermNew command
  opts = {},
  config = function(_, opts)
    local api = vim.api
    local fmt = string.format
    local terms = require 'toggleterm.terminal'

    --- Build the label shown in a terminal's title bar, e.g. " 2/3 · zsh ".
    --- Also seeds a default display_name (so toggleterm itself keeps a title on
    --- reopen/resize) from the shell running in the terminal.
    ---@param term table toggleterm Terminal
    ---@return string?
    local function title_label(term)
      local all = terms.get_all()
      local idx
      for i, t in ipairs(all) do
        if t.id == term.id then
          idx = i
          break
        end
      end
      if not idx then
        return nil
      end
      if not term.display_name or term.display_name == '' then
        term.display_name = vim.fn.fnamemodify(term:_display_name(), ':t')
      end
      return fmt(' %d/%d · %s ', idx, #all, term.display_name)
    end

    --- Show the current terminal's label centered at the top of its float.
    ---@param term table toggleterm Terminal
    local function set_title(term)
      if not term or not term:is_float() then
        return
      end
      if not term.window or not api.nvim_win_is_valid(term.window) then
        return
      end
      local label = title_label(term)
      if label then
        api.nvim_win_set_config(term.window, { title = label, title_pos = 'center' })
      end
    end

    --- Cycle to the previous/next terminal, wrapping around at the ends. The
    --- target is focused if its window is open, opened otherwise; the float we
    --- leave is hidden automatically but its process keeps running.
    ---@param dir -1 | 1 -1 = previous (<C-h>), 1 = next (<C-l>)
    local function switch(dir)
      local _, term = terms.identify()
      if not term then
        return
      end
      local all = terms.get_all()
      if #all < 2 then
        return vim.notify('No other terminals', vim.log.levels.INFO)
      end
      local idx
      for i, t in ipairs(all) do
        if t.id == term.id then
          idx = i
          break
        end
      end
      if not idx then
        return
      end
      local target = all[(idx + dir - 1) % #all + 1]
      if target.id == term.id then
        return
      end
      -- scheduled so we run outside of the terminal-mode mapping context
      vim.schedule(function()
        if target:is_open() then
          target:focus()
        else
          target:open()
        end
        set_title(target)
      end)
    end

    --- Kill a terminal instance: its process is terminated, its buffer wiped
    --- and it is removed from the <C-h>/<C-l> cycle. All other terminals,
    --- including their processes and scrollback, are untouched. If the closed
    --- terminal's window was open, the next terminal (by id, wrapping around)
    --- takes its place -- unless the command was invoked with a bang, in which
    --- case we simply return to the editor. Target is the current terminal, or
    --- the one given as a count (`:2TermClose`) or argument (`:TermClose 2`).
    local function close_term(opts)
      local arg = opts.args ~= '' and tonumber(opts.args) or nil
      if opts.args ~= '' and not arg then
        return vim.notify('TermClose: expected a terminal id, got "' .. opts.args .. '"', vim.log.levels.WARN)
      end
      local id = opts.count >= 1 and opts.count or arg
      local term
      if id then
        term = terms.get(id)
        if not term then
          return vim.notify(fmt('TermClose: no terminal %d', id), vim.log.levels.WARN)
        end
      else
        local _, t = terms.identify()
        if not t then
          return vim.notify('TermClose: not inside a terminal (use :TermClose <id> for a specific one)', vim.log.levels.WARN)
        end
        term = t
      end

      local was_open = term:is_open()
      local ok, err = pcall(term.shutdown, term)
      if not ok then
        return vim.notify(fmt('TermClose: %s', err), vim.log.levels.ERROR)
      end
      if opts.bang or not was_open then
        return
      end

      local remaining = terms.get_all()
      if #remaining == 0 then
        return vim.notify('No terminals remaining', vim.log.levels.INFO)
      end
      local succ
      for _, t in ipairs(remaining) do
        if t.id > term.id then
          succ = t
          break
        end
      end
      succ = succ or remaining[1]
      if succ:is_open() then
        succ:focus()
      else
        succ:open()
      end
      set_title(succ)
      -- quirk: startinsert is silently suppressed in the same event-loop turn
      -- as the killed job's exit processing, so the successor opens in
      -- terminal-normal mode; re-enter terminal mode once things settle
      vim.defer_fn(function()
        if succ:is_focused() and api.nvim_get_mode().mode == 'nt' then
          vim.cmd 'startinsert'
        end
      end, 50)
    end

    require('toggleterm').setup {
      open_mapping = [[<c-\>]],
      direction = 'float',
      float_opts = {
        title_pos = 'center',
      },
      on_open = function(term)
        set_title(term)
        -- Cycle terminals with <C-h>/<C-l>, active in terminal- and
        -- normal-mode while inside a terminal buffer
        local map_opts = { buffer = term.bufnr, silent = true }
        vim.keymap.set({ 't', 'n' }, '<C-h>', function()
          switch(-1)
        end, map_opts)
        vim.keymap.set({ 't', 'n' }, '<C-l>', function()
          switch(1)
        end, map_opts)
      end,
    }

    -- Kill the current terminal (or the one given as count/argument), keeping
    -- the rest; see close_term above for the exact semantics
    api.nvim_create_user_command('TermClose', close_term, { bang = true, count = true, nargs = '?' })

    -- Keep the position/count part of open titles accurate
    local group = api.nvim_create_augroup('custom_toggleterm', { clear = true })
    local refresh_titles = function()
      for _, t in ipairs(terms.get_all()) do
        set_title(t)
      end
    end
    api.nvim_create_autocmd('TermClose', {
      group = group,
      pattern = { 'term://*#toggleterm#*', 'term://*::toggleterm::*' },
      callback = vim.schedule_wrap(refresh_titles),
    })
    api.nvim_create_autocmd('VimResized', {
      group = group,
      callback = vim.schedule_wrap(refresh_titles),
    })
  end,
}
