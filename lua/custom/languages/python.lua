return {
  dap = {
    -- <name of DAP> -> configuration
    python = {
      {
        name = 'Python: Launch file',
        type = 'python',
        request = 'launch',
        program = '${file}',
        console = 'integratedTerminal',
      },
      {
        name = 'Pytest: Current File',
        type = 'python',
        request = 'launch',
        module = 'pytest',
        args = {
          '${file}',
          '-sv',
        },
        console = 'integratedTerminal',
      },
    },
  },
  lsp = {
    pyrefly = { pyrefly = { python = { pyrefly = { displayTypeErrors = 'force-on' } }, lspPath = '/run/current-system/sw/bin/pyrefly' } },
    -- pyright = {
    --   settings = {
    --     python = {
    --       analysis = {
    --         autoSearchPaths = true,
    --         diagnosticMode = 'workspace',
    --         useLibraryCodeForTypes = true,
    --         autoImportCompletions = true,
    --       },
    --     },
    --   },
    --   disableLanguageServices = false,
    -- },
    -- basedpyright = {
    --   capabilities = {
    --     -- Basedpyright does not support these capabilities well.
    --     definitionProvider = false,
    --     typeDefinitionProvider = false,
    --     implementationProvider = false,
    --     referencesProvider = false,
    --     -- hoverProvider = false, -- decide if pyright or basedpyright
    --   },
    --   settings = {
    --     basedpyright = {
    --       analysis = {
    --         autoSearchPaths = true,
    --         typeCheckingMode = 'basic',
    --         diagnosticMode = 'openFilesOnly',
    --         useLibraryCodeForTypes = true,
    --       },
    --     },
    --   },
    -- },
  },
  format = {
    ruff = {
      'ruff_fix',
      'ruff_organize_imports',
      'ruff_format',
    },
  },
}
