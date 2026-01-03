return {
  'MeanderingProgrammer/render-markdown.nvim',
  dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-mini/mini.nvim' }, -- if you use the mini.nvim suite
  -- dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-mini/mini.icons' },        -- if you use standalone mini plugins
  -- dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' }, -- if you prefer nvim-web-devicons
  ---@module 'render-markdown'
  ---@type render.md.UserConfig
  opts = {
    completions = { lsp = { enabled = true } },
    anti_conceal = { above = 2, below = 2 },
    -- restart_highlighter = false, -- maybe
  },
}
-- return {
--   -- For `plugins/markview.lua` users.
--   'OXY2DEV/markview.nvim',
--   lazy = false,
--
--   -- Completion for `blink.cmp`
--   -- dependencies = { "saghen/blink.cmp" },
-- }
