-- caches compiled lua, since nix byte-compiles nothing here
vim.loader.enable()

require("user.options")
require("user.keymaps")

-- during startup, :packadd! only adds the plugin to the runtimepath, and the load-plugins
-- step sources its plugin/ once. plain :packadd there would source it twice
vim.g.lz_n = {
    load = function(name)
        vim.cmd.packadd({ name, bang = vim.v.vim_did_init == 0 })
    end,
}

-- every file in lua/user/plugins returns lz.n specs, so a new plugin file needs no entry here
require("lz.n").load("user.plugins")

require("user.lsp")
require("user.statusline")
require("user.autocmds")
