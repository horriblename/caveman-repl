if vim.b.caveman_repl_loaded == 1 then
    return
end

vim.api.nvim_create_user_command(
    'CavemanReplStart',
    function(opts)
        require('caveman.repl').start(opts.fargs)
    end,
    { nargs = "*", complete = "shellcmd" }
)

vim.api.nvim_create_user_command(
    'CavemanReplSend',
    function(opts)
        require('caveman.repl').send_range(opts)
    end,
    {
        nargs = "*",
        range = true,
        addr = "lines",
        complete = function(lead, line, pos)
            local cmdline = require('caveman.repl.commandline')
            return cmdline.gen_complete(cmdline.send_flags)(lead, line, pos)
        end,
    }
)
