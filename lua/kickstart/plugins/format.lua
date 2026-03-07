-- Autoformat of save -> conform
return {
  'stevearc/conform.nvim',
  event = { 'BufWritePre' },
  cmd = { 'ConformInfo' },
  keys = {
    {
      '<leader>f',
      function()
        require('conform').format { async = true, lsp_fallback = true }
      end,
      mode = '',
      desc = '[F]ormat buffer',
    },
  },
  opts = function(_, _)
    -- will run this on first save
    local ft = require 'utils.functional'
    local M = require 'utils.mason' -- implicit dependency for now

    local languages = require('utils.profile').Languages()
    local formatters = ft.tbl_index_keyvalue_map(function(_, k, v)
      local lang = require('custom.languages')[v]
      return v, lang.format
    end, languages)

    -- formatters define a mapping
    -- <language> -> <format_executable> -> [<command1>, <command2>]
    local list_formatters = ft.to_list(ft.tbl_index_keyvalue_map(function(i, _, value)
      return i, value
    end, formatters))
    M.install_formatter(M.missing(list_formatters))

    local formatters_by_ft = ft.tbl_keyvalue_map(function(k, v)
      -- TODO: this is a hack, because we know that v has length 1 (1 formatter)
      -- Preferably we want to collect all commands into an array
      return k, ft.values(v)[0]
    end, formatters)
    formatters_by_ft = ft.filter(function(_, v)
      return ft.len(v) > 0
    end, formatters_by_ft)

    return {
      notify_on_error = false,
      format_on_save = function(bufnr)
        -- Disable "format_on_save lsp_fallback" for languages that don't
        -- have a well standardized coding style. You can add additional
        -- languages here or re-enable it for the disabled ones.
        local disable_filetypes = { c = true, cpp = true }
        if disable_filetypes[vim.bo[bufnr].filetype] then
          return nil
        else
          return {
            timeout_ms = 500,
            lsp_format = 'fallback',
          }
        end
      end,
      -- formatters_by_ft needs a mapping
      -- <language> -> [<command1>, <command2>]
      -- formatters_by_ft = formatters,
      formatters_by_ft = formatters_by_ft,
      -- formatters_by_ft = {
      --   lua = { 'stylua' },
      --   -- Conform can also run multiple formatters sequentially
      --   -- python = { "isort", "black" },
      --   python = {
      --     'ruff_fix',
      --     'ruff_organize_imports',
      --     'ruff_format',
      --     -- ruff_format = {
      --     --   args = function(_, _)
      --     --     return {
      --     --       'format',
      --     --       '--force-exclude',
      --     --       '--line-length',
      --     --       '120',
      --     --       '--stdin-filename',
      --     --       '$FILENAME',
      --     --       '-',
      --     --     }
      --     --   end,
      --     -- },
      --   },
      --   --
      --   -- You can use a sub-list to tell conform to run *until* a formatter
      --   -- is found.
      --   -- javascript = { { "prettierd", "prettier" } },
      -- },
    }
  end,
}
