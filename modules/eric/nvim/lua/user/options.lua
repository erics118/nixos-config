vim.g.mapleader = " "

-- filetypes where per-window ui (dropbar, indent guides, relative numbers) stays off
vim.g.ignored_ui_filetypes = {
    "",
    "alpha",
    "fugitive",
    "help",
    "NeogitCommitView",
    "NeogitConsole",
    "NeogitStatus",
    "NvimTree",
    "TelescopePrompt",
    "trouble",
}

-- nvim-tree replaces netrw
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

vim.g.yaml_recommended_style = 0

local opt = vim.opt

opt.exrc = true

-- enable mouse support
opt.mouse = "a"

-- show line numbers
opt.number = true
opt.relativenumber = true

-- scroll offsets
opt.scrolloff = 3
opt.sidescrolloff = 10

-- one global statusline
opt.laststatus = 3

-- the statusline shows the mode, so the cmdline doesn't repeat -- INSERT --
opt.showmode = false

-- the cmdline takes no row until it is in use
opt.cmdheight = 0

-- always show tab line (bufferline)
opt.showtabline = 2

-- completion height
opt.pumheight = 15

-- idle delay for CursorHold and swap writes
opt.updatetime = 250

-- wait for the next key of a mapping, like the : after q
opt.timeoutlen = 300

-- the cmdline types like insert mode, so it gets the same bar cursor
opt.guicursor = "n-v-sm:block,i-c-ci-ve:ver25,r-cr-o:hor20,t:block-blinkon500-blinkoff500-TermCursor"

-- default border for floating windows (hover, signature help, etc.)
opt.winborder = "rounded"

-- split directions
opt.splitbelow = true
opt.splitright = true
opt.wrap = false
opt.ignorecase = true
opt.smartcase = true

-- tab settings
opt.shiftwidth = 2
opt.tabstop = 2
opt.softtabstop = 2
opt.expandtab = true

-- always show 1 column of sign column (gitsigns, etc.)
opt.signcolumn = "yes:1"

-- true colors
opt.termguicolors = true

-- hide the ~ on lines past the end of the buffer
opt.fillchars = { eob = " " }

-- undo history persists across restarts, in stdpath("state")/undo
opt.undofile = true

-- :q with unsaved changes asks to save instead of failing
opt.confirm = true

-- visual block can extend past the end of short lines
opt.virtualedit = "block"

-- :s previews every matching line in a split, including off-screen ones
opt.inccommand = "split"

-- folding via treesitter. files open fully unfolded, use zc/zo/za to manage
opt.foldmethod = "expr"
opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
opt.foldenable = true
opt.foldlevel = 99
opt.foldlevelstart = 99

-- filetypes Neovim doesn't detect on its own or detects as something else, like .tex, which it would often call plaintex
-- hujson gets jsonc so jsonls, prettier, and colorizer apply
vim.filetype.add({
    extension = {
        hujson = "jsonc",
        mdx = "markdown",
        mxx = "cpp",
        tex = "tex",
    },
    pattern = {
        [".*/%.ssh/config%.local"] = "sshconfig",
    },
})

-- only override clipboard provider over SSH; locally use pbcopy/pbpaste (or xclip)
if vim.env.SSH_TTY ~= nil then
    local function paste()
        return { vim.fn.split(vim.fn.getreg('"'), "\n"), vim.fn.getregtype('"') }
    end
    vim.g.clipboard = {
        name = "OSC 52",
        copy = {
            ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
            ["*"] = require("vim.ui.clipboard.osc52").copy("*"),
        },
        paste = { ["+"] = paste, ["*"] = paste },
    }
end
