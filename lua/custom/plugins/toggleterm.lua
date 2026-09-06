-- Floating toggleterms with a centered title bar and <C-h>/<C-l> cycling.
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
      if not idx then return nil end
      if not term.display_name or term.display_name == '' then
        term.display_name = vim.fn.fnamemodify(term:_display_name(), ':t')
      end
      return fmt(' %d/%d · %s ', idx, #all, term.display_name)
    end

    --- Show the current terminal's label centered at the top of its float.
    ---@param term table toggleterm Terminal
    local function set_title(term)
      if not term or not term:is_float() then return end
      if not term.window or not api.nvim_win_is_valid(term.window) then return end
      local label = title_label(term)
      if label then api.nvim_win_set_config(term.window, { title = label, title_pos = 'center' }) end
    end

    --- Cycle to the previous/next terminal, wrapping around at the ends. The
    --- target is focused if its window is open, opened otherwise; the float we
    --- leave is hidden automatically but its process keeps running.
    ---@param dir -1 | 1 -1 = previous (<C-h>), 1 = next (<C-l>)
    local function switch(dir)
      local _, term = terms.identify()
      if not term then return end
      local all = terms.get_all()
      if #all < 2 then return vim.notify('No other terminals', vim.log.levels.INFO) end
      local idx
      for i, t in ipairs(all) do
        if t.id == term.id then
          idx = i
          break
        end
      end
      if not idx then return end
      local target = all[(idx + dir - 1) % #all + 1]
      if target.id == term.id then return end
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
        vim.keymap.set({ 't', 'n' }, '<C-h>', function() switch(-1) end, map_opts)
        vim.keymap.set({ 't', 'n' }, '<C-l>', function() switch(1) end, map_opts)
      end,
    }

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
