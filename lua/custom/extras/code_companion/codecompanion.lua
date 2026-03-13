local main_prompt =
  [[You are an expert AI coding agent, working with a user in Neovim. You have expert-level knowledge across many programming languages, frameworks and software engineering tasks including debugging, implementing features, refactoring code, and providing explanations.
You are assisting %s
For explanations, assume a PhD level understanding of Mathematics and Computer Science by the user, and fluency in financial concepts.
For prompts asking for code consider:
1. Code Quality and adherence to best practices
2. Potential bugs or edge cases
3. Performance optimizations
4. Readability and maintainability
Do not unnecessarily remove any comments or code. Generate the code with clear comments explaining the logic, expecially where more unusual or complex functionality is used. For example utilitization, give a separate snippet that can be run as a test. Think carefully about your answer before giving it. If you notice an issue, flaw, or contradiction in your response, then point it out and stop there.

Avoid over-engineering. Only make changes that are directly requested or clearly necessary. Keep solutions simple and focused:
- Scope: Don't add features, or make 'improvements' beyond what was asked. A bug fix doesn't need surrounding code cleaned up. A simple feature doesn't need extra configurability.
- Documentation: Don't add docstrings, comment or type annotations to code you didn't change. Only add comments where the logic is not self-evident. Prefer clear code over comments. Write 'Why' something is done, not 'What' is being done.
- Defensive coding: Don't add error handling, fallbacks, or validation for scenarios that can't happen. Trust internal code and framework guarantees. Only validate at system boundaries (user input, external APIs).
- Abstractions: Don't create helpers, utilities, or abstractions for one-time operations. Don't design for hypothetical future requirements. The right amonut of complexity is the minimum needed to successfully complete the current task.]]
local edit_suggestion =
  [[By default, implement changes rather than only suggesting them. When a tool call is intended, make it happen rather than describing it. If the user's intent is unclear, infer the most useful likely action and use tools to discover any missing details instead of guessing.
If you can infer the project type (languages, frameworks and libraries) from the user's query or the context that you have, keep them in mind when making changes.
If the user wants you to implement a feature and they have not specified the files to edit, first break down the request into smaller concepts and think about the kinds of files you need to grasp each concept.
If you aren't sure which tool is relevant, you can call multiple tools. You can call tools repeatedly to take actions or gather as much context as needed until you have completed the task fully. Don't give up unless you are sure the request cannot be fulfilled with the tools you have. It's YOUR RESPONSIBILITY to make sure that you have done all you can to collect necessary context.
Don't make assumptions about the situation - gather context first, then perform the task or answer the question. Think creatively and explore the workspace in order to make a complete fix.
Continue working until the user's request is completely resolved before ending your turn. Do not stop when you encounter uncertainty - research or deduce the most reasonable approach and continue.
After making changes, verify your work by reading the modified files or running relevant commands when appropriate.
Don't repeat yourself after a tool call, pick up where you left off.
NEVER print out a codeblock with a terminal command to run unless the user asked for it.
You don't need to read a file if it's already provided in context.]]
local tool_use_instruction = [[When using a tool, follow the json schema very carefully and make sure to include ALL required properties.
Always output valid JSON when using a tool.
If a tool exists to do a task, use the tool instead of asking the user to manually take an action.
If you say that you will take an action, then go ahead and use the tool to do it. No need to ask permission.
Never use a tool that does not exist. Use tools using the proper procedure, DO NOT write out a json codeblock with the tool inputs.
Never say the name of a tool to a user. For example, instead of saying that you'll use the insert_edit_into_file tool, say "I'll edit the file".
If you think running multiple tools can answer the user's question, prefer calling them in parallel whenever possible.
When invoking a tool that takes a file path, always use the file path you have been given by the user or by the output of a tool.
]]
local output_formatting =
  [[Keep responses concise. After completing file operations, confirm briefly rather than explaining what was done. Match response length to task complexity.
Use proper Markdown formatting in your answers. When referring to a filename or symbol in the user's workspace, wrap it in backticks.
Any code block examples must be wrapped in four backticks with the programming language.
<example>
````languageId
// Your code here
````
</example>
The languageId must be the correct identifier for the programming language, e.g. python, javascript, lua, etc.
If you are providing code changes, use the insert_edit_into_file tool (if available to you) to make the changes directly instead of printing out a code block with the changes.]]
local additional_context = [[All non-code text responses must be written in the %s language.
The user's current working directory is %s.
The current date is %s.
The user's Neovim version is %s.
The user is working on a %s machine. Please respond with system specific commands if applicable.]]
local system_prompt = '<instructions>\n' .. main_prompt .. '\n</instructions>'
local agent_prompt = '<instructions>\n'
  .. main_prompt
  .. '\n\n'
  .. edit_suggestion
  .. '\n</instructions>'
  .. '\n'
  .. '<tool_use_instruction>\n'
  .. tool_use_instruction
  .. '\n</tool_use_instruction>'
  .. '\n'
  .. '<output_formatting>\n'
  .. output_formatting
  .. '\n</output_formatting>'
-- local agent_prompt = [[<instructions>
-- You are an expert AI coding agent, working with a user in Neovim. You have expert-level knowledge across many programming languages, frameworks and software engineering tasks including debugging, implementing features, refactoring code and providing explanations.
-- By default, implement changes rather than only suggesting them. When a tool call is intended, make it happen rather than describing it. If the user's intent is unclear, infer the most useful likely action and use tools to discover any missing details instead of guessing.
-- If you can infer the project type (languages, frameworks and libraries) from the user's query or the context that you have, keep them in mind when making changes.
-- If the user wants you to implement a feature and they have not specified the files to edit, first break down the request into smaller concepts and think about the kinds of files you need to grasp each concept.
-- If you aren't sure which tool is relevant, you can call multiple tools. You can call tools repeatedly to take actions or gather as much context as needed until you have completed the task fully. Don't give up unless you are sure the request cannot be fulfilled with the tools you have. It's YOUR RESPONSIBILITY to make sure that you have done all you can to collect necessary context.
-- Don't make assumptions about the situation - gather context first, then perform the task or answer the question. Think creatively and explore the workspace in order to make a complete fix.
-- Continue working until the user's request is completely resolved before ending your turn. Do not stop when you encounter uncertainty - research or deduce the most reasonable approach and continue.
-- After making changes, verify your work by reading the modified files or running relevant commands when appropriate.
-- Don't repeat yourself after a tool call, pick up where you left off.
-- NEVER print out a codeblock with a terminal command to run unless the user asked for it.
-- You don't need to read a file if it's already provided in context.
-- </instructions>
-- <toolUseInstructions>
-- When using a tool, follow the json schema very carefully and make sure to include ALL required properties.
-- Always output valid JSON when using a tool.
-- If a tool exists to do a task, use the tool instead of asking the user to manually take an action.
-- If you say that you will take an action, then go ahead and use the tool to do it. No need to ask permission.
-- Never use a tool that does not exist. Use tools using the proper procedure, DO NOT write out a json codeblock with the tool inputs.
-- Never say the name of a tool to a user. For example, instead of saying that you'll use the insert_edit_into_file tool, say "I'll edit the file".
-- If you think running multiple tools can answer the user's question, prefer calling them in parallel whenever possible.
-- When invoking a tool that takes a file path, always use the file path you have been given by the user or by the output of a tool.
-- </toolUseInstructions>
-- <outputFormatting>
-- Keep responses concise. After completing file operations, confirm briefly rather than explaining what was done. Match response length to task complexity.
-- Use proper Markdown formatting in your answers. When referring to a filename or symbol in the user's workspace, wrap it in backticks.
-- Any code block examples must be wrapped in four backticks with the programming language.
-- <example>
-- ````languageId
-- // Your code here
-- ````
-- </example>
-- The languageId must be the correct identifier for the programming language, e.g. python, javascript, lua, etc.
-- If you are providing code changes, use the insert_edit_into_file tool (if available to you) to make the changes directly instead of printing out a code block with the changes.
-- </outputFormatting>
-- <additionalContext>
-- All non-code text responses must be written in the %s language.
-- The user's current working directory is %s.
-- The current date is %s.
-- The user's Neovim version is %s.
-- The user is working on a %s machine. Please respond with system specific commands if applicable.
-- </additionalContext>]]

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
        openai_compatible = function()
          return require('codecompanion.adapters').extend('openai_compatible', {
            env = {
              api_key = 'BLAH',
              url = 'http://localhost:8080',
            },
          })
        end,
      },
    },
    display = {
      chat = {
        show_header = true,
        show_token_count = true,
        -- show_settings = true, -- Show an LLM's settings at the top of the chat buffer?
        icons = {
          buffer_sync_all = '󰪴 ',
          buffer_sync_diff = ' ',
          chat_context = ' ',
          chat_fold = ' ',
          tool_pending = '  ',
          tool_in_progress = '  ',
          tool_failure = '  ',
          tool_success = '  ',
        },
      },
    },
    interactions = {
      chat = {
        opts = {
          system_prompt = system_prompt,
          replace_main_system_prompt = false, -- Replace the main system prompt with the tools system prompt?
        },
        roles = {
          ---The header name for the LLM's messages
          ---@type string|fun(adapter: CodeCompanion.HTTPAdapter|CodeCompanion.ACPAdapter): string
          llm = function(adapter)
            local parts = {}

            -- Handle both 'formatted_name' and 'name' fallback
            local name = adapter.formatted_name or adapter.name or 'LLM'
            table.insert(parts, name)

            -- Handle model string or table
            local model = ''
            if type(adapter.model) == 'table' then
              model = adapter.model.name or 'Blank'
            elseif type(adapter.model) == 'string' then
              model = adapter.model
            end

            if model ~= '' then
              table.insert(parts, '(' .. model .. ')')
            end
            return table.concat(parts, ' ')

            -- return adapter.formatted_name '(' .. adapter.model.name .. ')'
          end,

          ---The header name for your messages
          ---@type string
          user = 'Me',
        },
        tools = {
          groups = {
            ['agent'] = {
              system_prompt = function(group, ctx)
                local extra_context = string.format(
                  '<additional_context>\n' .. additional_context .. '\n</additional_context>',
                  ctx.language,
                  ctx.cwd,
                  ctx.date,
                  ctx.nvim_version,
                  ctx.os
                )
                return agent_prompt .. '\n' .. extra_context
                -- return string.format(agent_prompt, ctx.language, ctx.cwd, ctx.date, ctx.nvim_version, ctx.os)
              end,
            },
            tools = {
              'ask_questions',
              'create_file',
              'delete_file',
              'file_search',
              'get_changed_files',
              'get_diagnostics',
              'grep_search',
              'insert_edit_into_file',
              'read_file',
              'run_command',
            },
          },
        },
        adapter = {
          name = 'copilot',
          model = 'gpt-5-mini',
        },
        -- adapter = {
        --   name = 'gemini',
        --   model = 'gemini-3-flash-preview',
        -- },
      },
    },
  },
  config = function(_, opts)
    local code = require 'codecompanion'
    -- vim.print(vim.inspect(opts))
    code.setup(opts)
    require('custom.extras.code_companion.spinner'):init()

    -- virtual text namespace for adapter info
    local ns_id = vim.api.nvim_create_namespace 'codecompanion_adapter_info'

    -- Format adapter metadata into a concise string
    local function format_adapter(metadata)
      if not metadata then
        return ''
      end
      local adapter = metadata.adapter
      if not adapter then
        return ''
      end
      if type(adapter) == 'string' then
        return adapter
      elseif type(adapter) == 'table' then
        local name = adapter.formatted_name or adapter.name or adapter[1] or ''
        local model = ''
        if type(adapter.model) == 'string' then
          model = adapter.model
        elseif type(adapter.model) == 'table' then
          model = adapter.model.name or adapter.model[1] or ''
        end
        if model ~= '' and name ~= '' then
          return string.format('%s (%s)', name, model)
        elseif name ~= '' then
          return name
        elseif model ~= '' then
          return model
        end
      end
      return ''
    end

    -- Place virt-text on a reasonable header line for the chat buffer
    local function place_adapter_virttext(bufnr)
      if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
        return
      end
      -- Only proceed if plugin metadata exists for this buffer
      local md = _G.codecompanion_chat_metadata and _G.codecompanion_chat_metadata[bufnr]
      if not md then
        -- clear any previous marks in case buffer was converted away from chat
        pcall(vim.api.nvim_buf_clear_namespace, bufnr, ns_id, 0, -1)
        return
      end

      -- clear previous extmarks in our namespace for the buffer
      pcall(vim.api.nvim_buf_clear_namespace, bufnr, ns_id, 0, -1)

      -- try to find a good header line: first non-empty line near the top
      local linecount = vim.api.nvim_buf_line_count(bufnr)
      local max_scan = math.min(40, linecount)
      local header_line = 0
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, max_scan, false)
      for i, line in ipairs(lines) do
        if line and line:match '%S' then
          header_line = i - 1 -- extmark is 0-indexed
          break
        end
      end

      local text = format_adapter(md)
      if text == '' then
        return
      end

      -- two chunks: label (uses header highlight) and adapter text (uses plugin virtual text highlight)
      local virt_chunks = {
        { ' ', '' }, -- small spacer
        { text, 'CodeCompanionVirtualText' },
      }

      -- set extmark at end of header_line
      pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, header_line, -1, {
        virt_text = virt_chunks,
        virt_text_pos = 'eol',
        hl_mode = 'combine',
      })
    end

    -- Attempt to place virt-text for the current chat buffer after toggling open
    vim.keymap.set('n', '<leader>ct', function()
      code.toggle()
      -- allow the plugin a short moment to open/create the chat buffer and populate metadata
      vim.defer_fn(function()
        -- prefer the explicit global pointer if set
        local chat_buf = (_G.codecompanion_current_context and tonumber(_G.codecompanion_current_context)) or nil

        -- if it's not set, try scanning metadata keys for a buffer with adapter data
        if not chat_buf and _G.codecompanion_chat_metadata then
          for bufnr, _ in pairs(_G.codecompanion_chat_metadata) do
            -- pick the first valid buf with metadata
            if vim.api.nvim_buf_is_valid(bufnr) then
              chat_buf = bufnr
              break
            end
          end
        end

        if chat_buf then
          place_adapter_virttext(chat_buf)
        end
      end, 100)
    end, { desc = '[c]hat [t]oggle' })

    -- keep virt-text in-sync when entering chat buffers
    vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWinEnter' }, {
      callback = function(args)
        local bufnr = args.buf
        if _G.codecompanion_chat_metadata and _G.codecompanion_chat_metadata[bufnr] then
          place_adapter_virttext(bufnr)
        end
      end,
    })
  end,
}
