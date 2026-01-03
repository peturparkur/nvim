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
    local funcm = require 'utils.functional'
    local M = require 'utils.mason' -- implicit dependency for now

    local languages = require('utils.profile').Languages()
    local formatters = funcm.tbl_index_keyvalue_map(function(i, _, v)
      return i, require('custom.languages')[v].format
    end, languages)
    formatters = funcm.extract(formatters)
    M.install_formatter(M.missing(formatters))

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
      formatters_by_ft = {
        lua = { 'stylua' },
        -- Conform can also run multiple formatters sequentially
        -- python = { "isort", "black" },
        python = {
          'ruff_fix',
          'ruff_organize_imports',
          'ruff_format',
          -- ruff_format = {
          --   args = function(_, _)
          --     return {
          --       'format',
          --       '--force-exclude',
          --       '--line-length',
          --       '120',
          --       '--stdin-filename',
          --       '$FILENAME',
          --       '-',
          --     }
          --   end,
          -- },
        },
        --
        -- You can use a sub-list to tell conform to run *until* a formatter
        -- is found.
        -- javascript = { { "prettierd", "prettier" } },
      },
    }
  end,
}
