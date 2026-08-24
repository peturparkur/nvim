return {
  'sainnhe/everforest',
  lazy = false,
  priority = 1000,
  config = function()
    -- " Set contrast.
    -- " This configuration option should be placed before `colorscheme everforest`.
    -- " Available values: 'hard', 'medium'(default), 'soft'
    vim.g.everforest_background = 'soft'

    -- " For better performance
    vim.g.everforest_better_performance = 1
    -- Optionally configure and load the colorscheme
    -- directly inside the plugin declaration.
    vim.g.everforest_enable_italic = true
    vim.cmd.colorscheme 'everforest'
  end,
}
