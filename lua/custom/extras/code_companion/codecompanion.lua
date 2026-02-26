local system_prompt = [[<instructions>
You are a highly sophisticated automated coding agent with expert-level knowledge across many different programming languages and frameworks.
You are assisting the user who is a Quantitative Developer with a PhD or above level of understanding of Mathematics, and Computer Science.
The user will ask a question, or ask you to perform a task, and it may require lots of research to answer correctly. There is a selection of tools that let you perform actions or retrieve helpful context to answer the user's question.
You will be given some context and attachments along with the user prompt. You can use them if they are relevant to the task, and ignore them if not.
If you can infer the project type (languages, frameworks, and libraries) from the user's query or the context that you have, make sure to write these out explicitly, and keep them in mind when making changes.
If the user wants you to implement a feature and they have not specified the files to edit, first break down the user's request into smaller concepts and think about the kinds of files you need to grasp each concept.
If you aren't sure which tool is relevant, you can call multiple tools. You can call tools repeatedly to take actions or gather as much context as needed until you have completed the task fully. Don't give up unless you are sure the request cannot be fulfilled with the tools you have. It's YOUR RESPONSIBILITY to make sure that you have done all you can to collect necessary context.
Don't make assumptions about the situation - gather context first, then perform the task or answer the question.
Think creatively and explore the workspace in order to make a complete fix.
Don't repeat yourself after a tool call, pick up where you left off.
NEVER print out a codeblock with a terminal command to run unless the user asked for it.
You don't need to read a file if it's already provided in context.
</instructions>
<toolUseInstructions>
When using a tool, follow the json schema very carefully and make sure to include ALL required properties.
Always output valid JSON when using a tool.
If a tool exists to do a task, use the tool instead of asking the user to manually take an action.
If you say that you will take an action, then go ahead and use the tool to do it. No need to ask permission.
Never use a tool that does not exist. Use tools using the proper procedure, DO NOT write out a json codeblock with the tool inputs.
Never say the name of a tool to a user. For example, instead of saying that you'll use the insert_edit_into_file tool, say "I'll edit the file".
If you think running multiple tools can answer the user's question, prefer calling them in parallel whenever possible.
When invoking a tool that takes a file path, always use the file path you have been given by the user or by the output of a tool.
</toolUseInstructions>
<outputFormatting>
Use proper Markdown formatting in your answers. When referring to a filename or symbol in the user's workspace, wrap it in backticks.
Any code block examples must be wrapped in four backticks with the programming language.
<example>
````languageId
// Your code here
````

````python
def new_function():
	...
````
</example>
The languageId must be the correct identifier for the programming language, e.g. python, javascript, lua, etc.
If you are providing code changes, use the insert_edit_into_file tool (if available to you) to make the changes directly instead of printing out a code block with the changes.
</outputFormatting>]]

return {
  'olimorris/codecompanion.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-treesitter/nvim-treesitter',
  },
  opts = {
    -- NOTE: The log_level is in `opts.opts`
    -- opts = {
    --   log_level = 'DEBUG', -- or "TRACE"
    -- },
    adapters = {
      http = {
        gemini = function()
          return require('codecompanion.adapters').extend('gemini', {
            env = {
              api_key = 'NVIM_GEMINI_API_KEY',
            },
          })
        end,
      },
    },
    interactions = {
      chat = {
        opts = {
          system_prompt = system_prompt,
        },
        adapter = {
          name = 'gemini',
          model = 'gemini-3-flash-preview',
        },
      },
    },
  },
  config = function(_, opts)
    require('codecompanion').setup(opts)
    local code = require 'codecompanion'

    vim.keymap.set('n', '<leader>cc', function()
      code.toggle()
    end, { desc = '[c]ode [c]hat' })

    local persistence = require 'custom.extras.code_companion.persistence'
    local has_telescope, telescope = pcall(require, 'telescope')
    local pickers, finders, conf, actions, action_state
    if has_telescope then
      pickers = require 'telescope.pickers'
      finders = require 'telescope.finders'
      conf = require('telescope.config').values
      actions = require 'telescope.actions'
      action_state = require 'telescope.actions.state'
    end

    -- Keymap: save current chat
    vim.keymap.set('n', '<leader>cs', function()
      local chat = code.last_chat()
      if chat then
        persistence.save_chat_history(chat, function(path, err)
          if err then
            vim.schedule(function()
              vim.notify('Save failed: ' .. err, vim.log.levels.ERROR)
            end)
          else
            vim.schedule(function()
              vim.notify('Saved to: ' .. path, vim.log.levels.INFO)
            end)
          end
        end)
      else
        vim.notify('No active chat to save.', vim.log.levels.WARN)
      end
    end, { desc = 'code [c]hat [s]ave' })

    -- Keymap: load chat via Telescope (or fallback to ui.select)
    vim.keymap.set('n', '<leader>cl', function()
      local chat_files = persistence.get_chat_history_files()
      if vim.tbl_isempty(chat_files) then
        vim.notify('No saved chat histories found.', vim.log.levels.INFO)
        return
      end

      if has_telescope then
        pickers
          .new({}, {
            prompt_title = 'Load CodeCompanion chat',
            finder = finders.new_table { results = chat_files },
            sorter = conf.generic_sorter {},
            attach_mappings = function(prompt_bufnr, map)
              actions.select_default:replace(function()
                local entry = action_state.get_selected_entry()
                actions.close(prompt_bufnr)
                local selected_file = nil
                if entry then
                  selected_file = entry.value or entry[1]
                end
                if not selected_file then
                  return
                end

                persistence.load_chat_history(selected_file, function(data, err)
                  if err then
                    vim.schedule(function()
                      vim.notify('Failed to load: ' .. err, vim.log.levels.ERROR)
                    end)
                    return
                  end
                  local messages = data and data.messages or data
                  local cwd = data and data.cwd or nil
                  if cwd and type(cwd) == 'string' and cwd ~= '' then
                    pcall(vim.api.nvim_set_current_dir, cwd)
                  end
                  if messages then
                    code.chat { messages = messages }
                  end
                end)

                -- indicate we've set up mappings
                return true
              end)
            end,
          })
          :find()
      else
        -- fallback to vim.ui.select if telescope isn't available
        vim.ui.select(chat_files, {
          prompt = 'Select a chat to load:',
          kind = 'file',
        }, function(selected_file)
          if selected_file then
            persistence.load_chat_history(selected_file, function(data, err)
              if err then
                vim.schedule(function()
                  vim.notify('Failed to load: ' .. err, vim.log.levels.ERROR)
                end)
                return
              end
              local messages = data and data.messages or data
              local cwd = data and data.cwd or nil
              if cwd and type(cwd) == 'string' and cwd ~= '' then
                pcall(vim.api.nvim_set_current_dir, cwd)
              end
              if messages then
                code.chat { messages = messages }
              end
            end)
          end
        end)
      end
    end, { desc = 'code [c]hat [l]oad' })
  end,
}
