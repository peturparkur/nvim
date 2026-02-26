return {
  {
    'CopilotC-Nvim/CopilotChat.nvim',
    dependencies = {
      { 'nvim-lua/plenary.nvim', branch = 'master' },
    },
    -- build = 'make tiktoken',
    opts = {
      -- See Configuration section for options
    },
    setup = function(_, opts)
      require('CopilotChat').setup(opts)
      require('CopilotChat.config').providers.gemini = {
        gemini = {
          prepare_input = require('CopilotChat.config.providers').copilot.prepare_input,
          prepare_output = require('CopilotChat.config.providers').copilot.prepare_output,
          get_headers = function(is_json)
            local api_key = assert(os.getenv 'NVIM_GEMINI_API_KEY', 'NVIM_GEMINI_API_KEY env not set')
            local result = {
              Authorization = 'Bearer ' .. api_key,
              -- result['Content-Type'] = 'application/json'
            }
            return result
          end,

          get_models = function(headers)
            local response, err = require('CopilotChat.utils').curl_get('https://generativelanguage.googleapis.com/v1beta/openai/models', {
              headers = headers,
              json_response = true,
            })

            if err then
              error(err)
            end

            return vim.tbl_map(function(model)
              local id = model.id:gsub('^models/', '')
              return {
                id = id,
                name = id,
                streaming = true,
                tools = true,
              }
            end, response.body.data)
          end,

          get_url = function()
            return 'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions'
          end,
        },
      }
    end,
  },
  -- gemini key:
}
