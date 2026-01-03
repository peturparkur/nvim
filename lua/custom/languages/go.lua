return {
  lsp = {
    gopls = {
      settings = {
        gopls = {
          analyses = {
            unusedparams = true,
          },
          staticcheck = true,
          hints = {
            rangeVariableTypes = true,
            parameterNames = true,
            constantValues = true,
            assignVariableTypes = true,
            compositeLiteralFields = true,
            compositeLiteralTypes = true,
            functionTypeParameters = true,
          },
          gofumpt = true,
        },
      },
    },
  },
  dap = {
    delve = {},
  },
}
