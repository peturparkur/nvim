return {
  dir = '~/projects/nvim-plugins/lumina.nvim', -- Absolute path to the folder
  name = 'lumina',
  config = function()
    require('lumina').setup {
      profiles = {
        default = {
          -- endpoint = 'https://api.openai.com/v1/chat/completions',
          endpoint = 'http://localhost:8080/v1/chat/completions',
          model = 'ministral-3b',
          api_key_name = 'BLAH', -- Some local servers don't need a key
          tools = {},
        },
      },
      templates = {},
      roles = {
        system = '=== SYSTEM ===',
        user = '=== USER ===',
        assistant = '=== ASSISTANT ===',
      },
    }
  end,
}
