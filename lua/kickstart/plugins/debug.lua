-- Shows how to use the DAP plugin to debug your code.
--
-- Primarily focused on configuring the debugger for Go, but can
-- be extended to other languages as well. That's why it's called
-- kickstart.nvim and not kitchen-sink.nvim ;)
--

---@param config {type?:string, args?:string[]|fun():string[]?}
local function get_arguments(config)
  local args = type(config.args) == 'function' and (config.args() or {}) or config.args or {} --[[@as string[] | string ]]
  local args_str = type(args) == 'table' and table.concat(args, ' ') or args --[[@as string]]

  config = vim.deepcopy(config)
  ---@cast args string[]
  config.args = function()
    local new_args = vim.fn.expand(vim.fn.input('Run with args: ', args_str)) --[[@as string]]
    if config.type and config.type == 'java' then
      ---@diagnostic disable-next-line: return-type-mismatch
      return new_args
    end
    return require('dap.utils').splitstr(new_args)
  end
  return config
end

return {
  -- NOTE: Yes, you can install new plugins here!
  'mfussenegger/nvim-dap',
  -- NOTE: And you can specify dependencies as well
  dependencies = {
    -- Creates a beautiful debugger UI
    'rcarriga/nvim-dap-ui',

    -- Required dependency for nvim-dap-ui
    'nvim-neotest/nvim-nio',

    -- Installs the debug adapters for you
    'mason-org/mason.nvim',
    'jay-babu/mason-nvim-dap.nvim',

    -- Add your own debuggers here
    'leoluz/nvim-dap-go',
  },
  keys = {
    {
      '<leader>dB',
      function()
        require('dap').set_breakpoint(vim.fn.input 'Breakpoint condition: ')
      end,
      desc = '[d]ebug: [B]reakpoint condition',
    },
    {
      '<leader>db',
      function()
        require('dap').toggle_breakpoint()
      end,
      desc = '[d]ebug: toggle [b]reakpoint',
    },
    {
      '<leader>dc',
      function()
        require('dap').continue()
      end,
      desc = '[d]ebug: run/[c]ontinue',
    },
    {
      '<leader>da',
      function()
        require('dap').continue { before = get_arguments }
      end,
      desc = '[d]ebug: run with [a]rgs',
    },
    {
      '<leader>dC',
      function()
        require('dap').run_to_cursor()
      end,
      desc = '[d]ebug: run to [C]ursor',
    },
    {
      '<leader>dg',
      function()
        require('dap').goto_()
      end,
      desc = '[d]ebug: [g]o to line (No Execute)',
    },
    {
      '<leader>di',
      function()
        require('dap').step_into()
      end,
      desc = '[d]ebug: step [i]nto',
    },
    {
      '<leader>dj',
      function()
        require('dap').down()
      end,
      desc = '[d]ebug: down(j)',
    },
    {
      '<leader>dk',
      function()
        require('dap').up()
      end,
      desc = '[d]ebug: up(k)',
    },
    {
      '<leader>dl',
      function()
        require('dap').run_last()
      end,
      desc = '[d]ebug: run [l]ast',
    },
    {
      '<leader>du',
      function()
        require('dap').step_out()
      end,
      desc = '[d]ebug: step o[u]t',
    },
    {
      '<leader>do',
      function()
        require('dap').step_over()
      end,
      desc = '[d]ebug: step [o]ver',
    },
    {
      '<leader>dP',
      function()
        require('dap').pause()
      end,
      desc = '[d]ebug: [P]ause',
    },
    {
      '<leader>dr',
      function()
        require('dap').repl.toggle()
      end,
      desc = '[d]ebug: toggle [r]epl', -- REPL
    },
    {
      '<leader>ds',
      function()
        require('dap').session()
      end,
      desc = '[d]ebug: [s]ession',
    },
    {
      '<leader>dt',
      function()
        require('dap').terminate()
      end,
      desc = '[d]ebug: [t]erminate',
    },
    {
      '<leader>dw',
      function()
        require('dap.ui.widgets').hover()
      end,
      desc = '[d]ebug: UI [w]idgets',
    },
    {
      '<leader>dp',
      function()
        require('dapui').toggle()
      end,
      desc = 'Debug: See [p]revious session result.',
    },
  },
  -- keys = {
  --   -- Basic debugging keymaps, feel free to change to your liking!
  --   {
  --     '<F5>',
  --     function()
  --       require('dap').continue()
  --     end,
  --     desc = 'Debug: Start/Continue',
  --   },
  --   {
  --     '<F1>',
  --     function()
  --       require('dap').step_into()
  --     end,
  --     desc = 'Debug: Step Into',
  --   },
  --   {
  --     '<F2>',
  --     function()
  --       require('dap').step_over()
  --     end,
  --     desc = 'Debug: Step Over',
  --   },
  --   {
  --     '<F3>',
  --     function()
  --       require('dap').step_out()
  --     end,
  --     desc = 'Debug: Step Out',
  --   },
  --   {
  --     '<leader>b',
  --     function()
  --       require('dap').toggle_breakpoint()
  --     end,
  --     desc = 'Debug: Toggle Breakpoint',
  --   },
  --   {
  --     '<leader>B',
  --     function()
  --       require('dap').set_breakpoint(vim.fn.input 'Breakpoint condition: ')
  --     end,
  --     desc = 'Debug: Set Breakpoint',
  --   },
  --   -- Toggle to see last session result. Without this, you can't see session output in case of unhandled exception.
  --   {
  --     '<F7>',
  --     function()
  --       require('dapui').toggle()
  --     end,
  --     desc = 'Debug: See last session result.',
  --   },
  -- },
  config = function()
    vim.notify('HELLO!', vim.log.levels.WARN, nil)
    local dap = require 'dap'

    -- will run this on first save
    local funcm = require 'utils.functional'
    local M = require 'utils.mason' -- implicit dependency for now

    local languages = require('utils.profile').Languages()
    local debuggers = funcm.tbl_index_keyvalue_map(function(i, _, v)
      return i, require('custom.languages')[v].dap
    end, languages)
    debuggers = funcm.extract(debuggers)
    vim.print 'debuggers'
    vim.print(debuggers)
    M.install_dap(M.missing(debuggers))

    -- local ensure_installed = { ['delve'] = {}, ['python'] = {} }
    -- mutils.install_dap(mutils.missing(ensure_installed))
    for key, config in pairs(debuggers) do
      require 'kickstart.plugins.dap.adapters.generic'(key, config)
    end
    -- require 'kickstart.plugins.dap.adapters.generic' 'python'

    -- require('mason-nvim-dap').setup {
    --   ensure_installed = {}, --{ 'delve', 'python', 'debugpy' },
    --   automatic_installation = false,
    --   handlers = {
    --     function(config)
    --       -- all sources with no handler get passed here
    --
    --       -- Keep original functionality
    --       require('mason-nvim-dap').default_setup(config)
    --     end,
    --     python = function(config)
    --       print('test', vim.inspect { test = {} })
    --       -- config.adapters = {
    --       --   type = 'executable',
    --       --   command = '/usr/bin/python3',
    --       --   args = {
    --       --     '-m',
    --       --     'debugpy.adapter',
    --       --   },
    --       -- }
    --       print(vim.inspect(config))
    --       require('mason-nvim-dap').default_setup(config) -- don't forget this!
    --     end,
    --   },
    -- }

    -- require('mason-nvim-dap').setup {
    --   -- Makes a best effort to setup the various debuggers with
    --   -- reasonable debug configurations
    --   automatic_installation = true,
    --
    --   -- You can provide additional configuration to the handlers,
    --   -- see mason-nvim-dap README for more information
    --   handlers = {},
    --
    --   -- You'll need to check that you have the required things installed
    --   -- online, please don't ask me how to install them :)
    --   ensure_installed = ensure_installed,
    -- }

    local dapui = require 'dapui'
    -- Dap UI setup
    -- For more information, see |:help nvim-dap-ui|
    dapui.setup {
      -- Set icons to characters that are more likely to work in every terminal.
      --    Feel free to remove or use ones that you like more! :)
      --    Don't feel like these are good choices.
      icons = { expanded = '▾', collapsed = '▸', current_frame = '*' },
      controls = {
        icons = {
          pause = '⏸',
          play = '▶',
          step_into = '⏎',
          step_over = '⏭',
          step_out = '⏮',
          step_back = 'b',
          run_last = '▶▶',
          terminate = '⏹',
          disconnect = '⏏',
        },
      },
    }

    -- Change breakpoint icons
    -- vim.api.nvim_set_hl(0, 'DapBreak', { fg = '#e51400' })
    -- vim.api.nvim_set_hl(0, 'DapStop', { fg = '#ffcc00' })
    -- local breakpoint_icons = vim.g.have_nerd_font
    --     and { Breakpoint = '', BreakpointCondition = '', BreakpointRejected = '', LogPoint = '', Stopped = '' }
    --   or { Breakpoint = '●', BreakpointCondition = '⊜', BreakpointRejected = '⊘', LogPoint = '◆', Stopped = '⭔' }
    -- for type, icon in pairs(breakpoint_icons) do
    --   local tp = 'Dap' .. type
    --   local hl = (type == 'Stopped') and 'DapStop' or 'DapBreak'
    --   vim.fn.sign_define(tp, { text = icon, texthl = hl, numhl = hl })
    -- end

    dap.listeners.after.event_initialized['dapui_config'] = dapui.open
    dap.listeners.before.event_terminated['dapui_config'] = dapui.close
    dap.listeners.before.event_exited['dapui_config'] = dapui.close

    -- Install golang specific config
    require('dap-go').setup {
      delve = {
        -- On Windows delve must be run attached or it crashes.
        -- See https://github.com/leoluz/nvim-dap-go/blob/main/README.md#configuring
        detached = vim.fn.has 'win32' == 0,
      },
    }
  end,
}
