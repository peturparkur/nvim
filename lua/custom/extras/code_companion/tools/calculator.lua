-- calculator tool
return {
  description = 'Perform calculations',
  name = 'calculator',
  cmds = {
    ---@param self CodeCompanion.Tool.Calculator The Calculator tool
    ---@param args table The arguments from the LLM's tool call
    ---@param opts { input: any, output_cb: fun(result: table) }
    ---@return nil|{ status: "success"|"error", data: string }
    function(self, args, opts)
      -- Get the numbers and operation requested by the LLM
      local num1 = tonumber(args.num1)
      local num2 = tonumber(args.num2)
      local operation = args.operation

      -- Validate input
      if not num1 then
        return { status = 'error', data = 'First number is missing or invalid' }
      end

      if not num2 then
        return { status = 'error', data = 'Second number is missing or invalid' }
      end

      if not operation then
        return { status = 'error', data = 'Operation is missing' }
      end

      -- Perform the calculation
      local result
      if operation == 'add' then
        result = num1 + num2
      elseif operation == 'subtract' then
        result = num1 - num2
      elseif operation == 'multiply' then
        result = num1 * num2
      elseif operation == 'divide' then
        if num2 == 0 then
          return { status = 'error', data = 'Cannot divide by zero' }
        end
        result = num1 / num2
      else
        return {
          status = 'error',
          data = 'Invalid operation: must be add, subtract, multiply, or divide',
        }
      end

      return { status = 'success', data = result }
    end,
  },
  system_prompt = [[## Calculator Tool (`calculator`)

## CONTEXT
- You have access to a calculator tool running within CodeCompanion, in Neovim.
- You can use it to add, subtract, multiply or divide two numbers.

### OBJECTIVE
- Do a mathematical operation on two numbers when the user asks

### RESPONSE
- Always use the structure above for consistency.
]],

  schema = {
    type = 'function',
    ['function'] = {
      name = 'calculator',
      description = "Perform simple mathematical operations on a user's machine",
      parameters = {
        type = 'object',
        properties = {
          num1 = {
            type = 'integer',
            description = 'The first number in the calculation',
          },
          num2 = {
            type = 'integer',
            description = 'The second number in the calculation',
          },
          operation = {
            type = 'string',
            enum = { 'add', 'subtract', 'multiply', 'divide' },
            description = 'The mathematical operation to perform on the two numbers',
          },
        },
        required = {
          'num1',
          'num2',
          'operation',
        },
        additionalProperties = false,
      },
      strict = true,
    },
  },
  handlers = {
    ---@param self CodeCompanion.Tool.Calculator
    ---@param meta { tools: CodeCompanion.Tools }
    setup = function(self, meta)
      return vim.notify('setup function called', vim.log.levels.INFO)
    end,
    ---@param self CodeCompanion.Tool.Calculator
    ---@param meta { tools: CodeCompanion.Tools }
    on_exit = function(self, meta)
      return vim.notify('on_exit function called', vim.log.levels.INFO)
    end,
  },
  output = {
    ---@param self CodeCompanion.Tool.Calculator
    ---@param stdout table
    ---@param meta { tools: CodeCompanion.Tools, cmd: table }
    success = function(self, stdout, meta)
      local chat = meta.tools.chat
      return chat:add_tool_output(self, tostring(stdout[1]))
    end,
    ---@param self CodeCompanion.Tool.Calculator
    ---@param stderr table The error output from the command
    ---@param meta { tools: CodeCompanion.Tools, cmd: table }
    error = function(self, stderr, meta)
      return vim.notify('An error occurred', vim.log.levels.ERROR)
    end,
  },
}
