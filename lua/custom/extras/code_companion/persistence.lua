local api = vim.api
local fn = vim.fn
local M = {}

-- Define a directory for chat history within the Neovim data directory
-- This ensures data is stored in a standard, user-specific location
local CHAT_HISTORY_DIR = fn.stdpath 'data' .. '/codecompanion/chats'

-- Autocmd group for persistence events
local persistence_augroup = api.nvim_create_augroup('CodeCompanionPersistence', { clear = true })

-- Helper function to ensure the chat history directory exists
local function ensure_chat_history_dir()
  if fn.isdirectory(CHAT_HISTORY_DIR) == 0 then
    -- Create the directory and any necessary parent directories
    fn.mkdir(CHAT_HISTORY_DIR, 'p')
  end
end

--- Saves the current chat buffer's messages to a JSON file.
--- The filename includes a timestamp and the chat's unique ID for easy identification.
---@param chat CodeCompanion.Chat The chat object to save.
---@return string|nil filepath The path to the saved file, or nil if saving failed.
---@return string|nil err_msg An error message if saving failed.
function M.save_chat_history(chat, callback)
  -- Ensure the directory for saving chat history exists
  ensure_chat_history_dir()

  local messages = chat.messages
  -- If there are no messages, notify the user and return an error
  if vim.tbl_isempty(messages) then
    vim.notify('No messages to save.', vim.log.levels.WARN)
    local err = 'No messages to save'
    if callback then
      -- Ensure callback runs on main loop
      vim.schedule(function()
        callback(nil, err)
      end)
    end
    return nil, err
  end

  -- Create a deep copy of messages to avoid modifying the live chat object
  -- and to ensure all parts are serializable (e.g., no metatables causing issues)
  local serializable_messages = vim.deepcopy(messages)

  -- Also save the current working directory so we can restore it when loading
  local cwd = vim.fn.getcwd()
  local to_save = { messages = serializable_messages, cwd = cwd }

  -- Encode the messages table (and metadata) into a JSON string
  local ok_encode, json_content = pcall(vim.json.encode, to_save)
  if not ok_encode then
    vim.notify('Failed to encode messages to JSON.', vim.log.levels.ERROR)
    local err = 'Failed to encode messages to JSON'
    if callback then
      vim.schedule(function()
        callback(nil, err)
      end)
    end
    return nil, err
  end

  -- Generate a unique filename using timestamp and chat ID
  local timestamp = os.date '%Y%m%d_%H%M%S'
  local filename = string.format('chat_%s_%d.json', timestamp, chat.id)
  local filepath = CHAT_HISTORY_DIR .. '/' .. filename

  -- Perform async file write using luv (vim.loop)
  local uv = vim.loop
  uv.fs_open(filepath, 'w', tonumber('644', 8), function(open_err, fd)
    if open_err then
      vim.schedule(function()
        vim.notify(string.format('Failed to open file for writing: %s. Error: %s', filepath, tostring(open_err)), vim.log.levels.ERROR)
        if callback then
          callback(nil, 'Failed to open file for writing')
        end
      end)
      return
    end

    uv.fs_write(fd, json_content, 0, function(write_err, _)
      if write_err then
        uv.fs_close(fd, function() end)
        vim.schedule(function()
          vim.notify(string.format('Failed to write to file: %s. Error: %s', filepath, tostring(write_err)), vim.log.levels.ERROR)
          if callback then
            callback(nil, 'Failed to write file')
          end
        end)
        return
      end

      uv.fs_close(fd, function()
        vim.schedule(function()
          vim.notify(string.format('Chat history saved to: %s', filepath), vim.log.levels.INFO)

          -- Fire autocmd after successful save
          api.nvim_exec_autocmds('User', {
            group = persistence_augroup,
            pattern = 'CodeCompanionChatSaved',
            data = { filepath = filepath, chat_id = chat.id },
          })

          if callback then
            callback(filepath, nil)
          end
        end)
      end)
    end)
  end)

  -- Return the intended filepath immediately for convenience; actual write happens async.
  return filepath
end

--- Loads chat messages from a specified JSON file.
---@param filepath string The full path to the chat history file.
---@return CodeCompanion.Chat.Messages|nil messages The loaded messages, or nil if loading failed.
---@return string|nil err_msg An error message if loading failed.
function M.load_chat_history(filepath, callback)
  -- Check if the file exists and is readable
  if fn.filereadable(filepath) ~= 1 then
    vim.notify(string.format('File not found or not readable: %s', filepath), vim.log.levels.ERROR)
    local err = 'File not found or not readable'
    if callback then
      vim.schedule(function()
        callback(nil, err)
      end)
    end
    return nil, err
  end

  local uv = vim.loop
  uv.fs_open(filepath, 'r', 0, function(open_err, fd)
    if open_err then
      vim.schedule(function()
        vim.notify(string.format('Failed to open file for reading: %s. Error: %s', filepath, tostring(open_err)), vim.log.levels.ERROR)
        if callback then
          callback(nil, 'Failed to open file for reading')
        end
      end)
      return
    end

    uv.fs_fstat(fd, function(stat_err, stat)
      if stat_err then
        uv.fs_close(fd, function() end)
        vim.schedule(function()
          vim.notify(string.format('Failed to stat file: %s. Error: %s', filepath, tostring(stat_err)), vim.log.levels.ERROR)
          if callback then
            callback(nil, 'Failed to stat file')
          end
        end)
        return
      end

      local size = stat.size
      uv.fs_read(fd, size, 0, function(read_err, data)
        uv.fs_close(fd, function() end)
        if read_err then
          vim.schedule(function()
            vim.notify(string.format('Failed to read file: %s. Error: %s', filepath, tostring(read_err)), vim.log.levels.ERROR)
            if callback then
              callback(nil, 'Failed to read file')
            end
          end)
          return
        end

        -- Safely decode JSON content, handling potential errors
        local ok, messages = pcall(vim.json.decode, data)
        vim.schedule(function()
          if ok then
            vim.notify(string.format('Chat history loaded from: %s', filepath), vim.log.levels.INFO)

            -- Fire autocmd after successful load
            api.nvim_exec_autocmds('User', {
              group = persistence_augroup,
              pattern = 'CodeCompanionChatLoaded',
              data = { filepath = filepath, messages = messages },
            })

            if callback then
              callback(messages, nil)
            end
          else
            vim.notify(string.format('Failed to decode JSON from %s: %s', filepath, messages), vim.log.levels.ERROR)
            if callback then
              callback(nil, 'Failed to decode JSON')
            end
          end
        end)
      end)
    end)
  end)

  -- Return true to indicate the load was started; result will come via callback.
  return true
end

--- Retrieves a list of all saved chat history files, sorted by modification time (newest first).
---@return string[] files A list of file paths to saved chat histories.
function M.get_chat_history_files()
  ensure_chat_history_dir()
  local files = {}
  -- Using `find` and `xargs` with `ls -t` to get files sorted by modification time, newest first.
  -- Properly escape the glob pattern for the shell command.
  local cmd = string.format('find %q -maxdepth 1 -name %q -print0 | xargs -0 ls -t', CHAT_HISTORY_DIR, 'chat_*.json')
  local handle = io.popen(cmd)
  if handle then
    local output = handle:read '*all'
    handle:close()
    -- Extract each file path from the output
    for file in output:gmatch '([^\\n]+)' do
      table.insert(files, file)
    end
  end
  return files
end

return M
