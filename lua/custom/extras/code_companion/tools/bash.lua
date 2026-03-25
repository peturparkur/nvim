---@class CodeCompanion.Tool.bash : CodeCompanion.Tools.Tool
return {
  name = 'bash',
  description = [[Run shell commands on the user's Linux based system. Use linux piping to combine the commands to feed the output into another commands input.
	You can always use `--help` flag with any of the commands, to see how they should be used.
	To have a full list of available commands, use the `help` command.

	A non-exchaustive list of bash commands available:
	- mkdir [purpose: make directories]
	- echo [purpose: write a string to stdout]
	- ls [purpose: list files and directories within a path]
	- tree [purpose: show filetree of current working directory]
	- rg [purpose: find text content within file(s); fast alternative to grep; equivalent to grep]
	- fd [purpose: find files; fast alternative to find; equivalent to find]
	- jq [purpose: apply operations on json objects; json query]
	- fzf [purpose: fuzzy find elements within options; fuzzy finder]
	]],
  schema = {
    type = 'function',
    ['function'] = {
      name = 'bash',
      description = "Run shell commands on the user's Linux system",
      parameters = {
        type = 'object',
        properties = {
          cmd = {
            type = 'string',
            description = 'The command(s) to run including all their flags and stdout piping',
          },
        },
        required = {
          'cmd',
        },
        additionalProperties = false,
      },
      strict = true,
    },
  },
  cmds = {
    ---@param self CodeCompanion.Tool.bash The Calculator tool
    ---@param args{cmd: string} The arguments from the LLM's tool call
    ---@param opts { input: any, output_cb: fun(result: table) }
    ---@return nil|{ status: "success"|"error", data: string }
    function(self, args, opts)
      cb = opts.output_cb -- asynchronous callback to give back the result
      local ms = os.clock() * 1000

      vim.print('running: ' .. args.cmd)
      if args.cmd == 'help' then
        cb { status = 'success', data = [[available commands:\ncat\nls\ntree\nrg\nfd\njq\nfzf\npython\nwhich]] }
        return
      end

      ---@param out vim.SystemCompleted
      local on_exit = function(out)
        local time_taken = os.clock() * 1000 - ms
        local time_taken_output = string.format('took: %d ms', time_taken)
        if out.code == 0 then
          cb { status = 'success', data = time_taken_output .. '\n' .. out.stdout }
        elseif out.code == 1 then
          cb { status = 'error', data = time_taken_output .. '\n' .. out.stderr }
        else
          cb { status = 'success', data = time_taken_output .. '\n' .. out.stdout }
        end
      end

      local result = vim.system({ 'bash', '-c', args.cmd }, { text = true }):wait(1000) -- 1000ms
      on_exit(result)
    end,
  },
  handlers = {
    ---@param self CodeCompanion.Tool.bash
    ---@param meta { tools: CodeCompanion.Tools }
    setup = function(self, meta)
      return vim.notify('setup function called', vim.log.levels.INFO)
    end,
    ---@param self CodeCompanion.Tool.bash
    ---@param meta { tools: CodeCompanion.Tools }
    on_exit = function(self, meta)
      return vim.notify('on_exit function called', vim.log.levels.INFO)
    end,
  },
  output = {
    ---@param self CodeCompanion.Tool.bash
    ---@param stdout table
    ---@param meta { tools: CodeCompanion.Tools, cmd: table }
    success = function(self, stdout, meta)
      local chat = meta.tools.chat
      return chat:add_tool_output(self, tostring(stdout[1]))
    end,
    ---@param self CodeCompanion.Tool.bash
    ---@param stderr table The error output from the command
    ---@param meta { tools: CodeCompanion.Tools, cmd: table }
    error = function(self, stderr, meta)
      return vim.notify('An error occurred\n' .. vim.inspect(stderr), vim.log.levels.ERROR)
    end,
    ---The message which is shared with the user when asking for their approval
    ---@param self CodeCompanion.Tool.bash
    ---@param meta { tools: CodeCompanion.Tools }
    ---@return string
    prompt = function(self, meta)
      return string.format('Perform the bash command `%s`?', self.args.cmd)
    end,
  },
}
