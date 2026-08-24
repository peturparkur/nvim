return {
  'akinsho/toggleterm.nvim',
  version = '9a88eae817ef395952e08650b3283726786fb5fb', -- want commit version since latest release does not contain TermNew command
  opts = {},
  config = function(_, opts)
    require('toggleterm').setup {
      open_mapping = [[<c-\>]],
      direction = 'float',
    }
  end,
}
