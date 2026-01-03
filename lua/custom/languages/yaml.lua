return {
  lsp = {
    yamlls = {
      alias = 'yaml-language-server',
      settings = {
        yaml = {
          schemas = {
            kubernetes = '*.k8s.yaml', -- TODO: consider using *.k8s.yaml for kubernetes schemas
            extra = {
              ['http://json.schemastore.org/github-workflow'] = '.github/workflows/*',
              ['http://json.schemastore.org/github-action'] = '.github/action.{yml,yaml}',
              ['http://json.schemastore.org/ansible-stable-2.9'] = 'roles/tasks/**/*.{yml,yaml}',
              ['http://json.schemastore.org/prettierrc'] = '.prettierrc.{yml,yaml}',
              ['http://json.schemastore.org/kustomization'] = 'kustomization.{yml,yaml}',
              ['http://json.schemastore.org/chart'] = 'Chart.{yml,yaml}',
              ['http://json.schemastore.org/circleciconfig'] = '.circleci/**/*.{yml,yaml}',
            },
          },
          format = {
            enable = true,
          },
          redhat = { telemetry = { enabled = false } },
        },
      },
    },
  },
  format = {
    yamlfmt = {},
  },
}
