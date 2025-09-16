local M = {}

-- any cases where name of package is different from the binary name
local name_to_bin = {
  -- ['csharp-language-server'] = 'csharp-ls',
  -- ['python-lsp-server'] = 'pylsp',
  -- ['docker-compose-language-service'] = 'docker-compose-langserver',
}

--- filter table for packages which are not in path
---@param ensure_installed table<string, table>
---@return table
M.missing = function(ensure_installed)
  if type(ensure_installed) == 'string' then
    ensure_installed = { ensure_installed }
  end

  local result = {}
  for lsp_name, config in pairs(ensure_installed) do
    local executable_name = lsp_name
    if config['alias'] then
      executable_name = config['alias']
    end

    -- check if executable exists
    if vim.fn.executable(executable_name) ~= 1 then
      result[lsp_name] = config
    end
  end
  print('missing packages: ', vim.inspect(result))
  return result
end

---comment
---@param ensure_installed table<string, table>
M.install_packages = function(ensure_installed)
  local registry = require 'mason-registry'
  registry.refresh(function()
    for package, _ in pairs(ensure_installed) do
      local pkg = registry.get_package(package)
      if not pkg:is_installed() then
        pkg:install()
      end
    end
  end)
end

---comment
---@param ensure_installed table<string, table>
M.install_dap = function(ensure_installed)
  -- ensure installed is expected of the form <lspname>: {cmd: "", settings: {...}}

  -- ensure_installed = M.missing(ensure_installed, enforce_local)
  local source_mappings = require('mason-nvim-dap.mappings.source').nvim_dap_to_package
  local packages = {}
  for lsp_cfg, v in pairs(ensure_installed) do
    packages[source_mappings[lsp_cfg]] = v
  end
  print('install packages: ', vim.inspect(packages))
  M.install_packages(packages)
end

---@param ensure_installed table<string, table>
M.install_formatter = function(ensure_installed)
  local specs = require('mason-registry').get_all_package_specs()
  specs = vim.tbl_filter(function(v)
    return vim.list_contains(v['categories'], 'Formatter')
  end, specs)

  -- filter names that are in ensure installed
  specs = vim.tbl_filter(function(v)
    return ensure_installed[v['name']] ~= nil
  end, specs)

  if vim.tbl_count(specs) <= 0 then
    print('Could not find packages in Mason registry', vim.inspect(ensure_installed))
    return
  end

  -- filter installable elements
  local installable = {}
  for _, data in pairs(specs) do
    local k = data['name']
    installable[k] = ensure_installed[k]
  end
  M.install_packages(installable)
end

-- We guarantee 'ensure_installed' package is installed locally
-- If enforce_local is false then we install it via mason-registry
-- By default we install LSPs via mason
---comment
---@param ensure_installed table<string, table>
M.install_lsp = function(ensure_installed)
  -- ensure installed is expected of the form <lspname>: {cmd: "", settings: {...}}

  --- [bin -> name -> "", languages -> "", categories -> []]

  -- ensure_installed = M.missing(ensure_installed, enforce_local)
  local lspconfig_to_pkg = require('mason-lspconfig').get_mappings().lspconfig_to_package
  local packages = {}
  for lsp_cfg, v in pairs(ensure_installed) do
    packages[lspconfig_to_pkg[lsp_cfg]] = v
  end
  M.install_packages(packages)
end

return M
