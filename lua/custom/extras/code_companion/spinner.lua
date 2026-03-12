-- Source: https://github.com/olimorris/codecompanion.nvim/discussions/813#discussioncomment-12031954
-- Modified to process only inline requests.

local progress = require 'fidget.progress'

local M = {}

function M:init()
  local group = vim.api.nvim_create_augroup('CodeCompanionInlineFidgetSpinner', {})

  vim.api.nvim_create_autocmd({ 'User' }, {
    pattern = 'CodeCompanionRequestStarted',
    group = group,
    callback = function(request)
      if request.data.interaction ~= 'inline' and request.data.interaction ~= 'chat' then
        return
      end
      local handle = M:create_progress_handle(request)
      M:store_progress_handle(request.data.id, handle)
    end,
  })

  vim.api.nvim_create_autocmd({ 'User' }, {
    pattern = 'CodeCompanionRequestFinished',
    group = group,
    callback = function(request)
      if request.data.interaction ~= 'inline' and request.data.interaction ~= 'chat' then
        return
      end
      local handle = M:pop_progress_handle(request.data.id)
      if handle then
        M:report_exit_status(handle, request)
        handle:finish()
      end
    end,
  })
end

M.handles = {}

function M:store_progress_handle(id, handle)
  M.handles[id] = handle
end

function M:pop_progress_handle(id)
  local handle = M.handles[id]
  M.handles[id] = nil
  return handle
end

function M:create_progress_handle(request)
  return progress.handle.create {
    title = ' Requesting assistance (' .. (request.data.interaction or 'unknown') .. ')',
    message = 'In progress...',
    lsp_client = {
      name = M:llm_role_title(request.data.adapter),
    },
  }
end

function M:llm_role_title(adapter)
  if not adapter then
    return 'CodeCompanion'
  end
  local parts = {}

  -- Handle both 'formatted_name' and 'name' fallback
  local name = adapter.formatted_name or adapter.name or 'LLM'
  table.insert(parts, name)

  -- Handle model string or table
  local model = ''
  if type(adapter.model) == 'table' then
    model = adapter.model.name or ''
  elseif type(adapter.model) == 'string' then
    model = adapter.model
  end

  if model ~= '' then
    table.insert(parts, '(' .. model .. ')')
  end
  return table.concat(parts, ' ')
end

function M:report_exit_status(handle, request)
  if request.data.status == 'success' then
    handle.message = 'Completed'
  elseif request.data.status == 'error' then
    handle.message = ' Error'
  else
    handle.message = '󰜺 Cancelled'
  end
end

return M
