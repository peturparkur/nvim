return {
  lsp = {
    lua_ls = {
      -- cmd = {...},
      -- filetypes = { ...},
      -- capabilities = {},
      alias = 'lua-language-server',
      settings = {
        Lua = {
          completion = {
            callSnippet = 'Replace',
          },
          hint = {
            enable = true,
          },
          -- You can toggle below to ignore Lua_LS's noisy `missing-fields` warnings
          -- diagnostics = { disable = { 'missing-fields' } },
        },
      },
    },
  },
  format = {
    stylua = {},
  },
}
