local map = require("user.utils.map")

-- split navigation
map("n", "<C-J>", "<C-W>j", "Move to window below")
map("n", "<C-K>", "<C-W>k", "Move to window above")
map("n", "<C-L>", "<C-W>l", "Move to window right")
map("n", "<C-H>", "<C-W>h", "Move to window left")
map("n", "<C-W>\\", "<Cmd>vsplit<CR>", "Vertical split")
map("n", "<C-W>-", "<Cmd>split<CR>", "Horizontal split")
map("n", "<C-W>x", "<Cmd>q<CR>", "Close window")

-- terminal
map("t", "<Esc>", "<C-\\><C-n>", "Exit terminal mode")

-- while recording, q stops at once
-- otherwise a stray q: opens the normal cmdline instead of the command-line window
-- not silent, since a silent mapping hides the cmdline it opens
vim.keymap.set("n", "q", function()
    return vim.fn.reg_recording() ~= "" and "q" or "<Plug>(q)"
end, { expr = true, remap = true, desc = "Record macro" })
vim.keymap.set("n", "<Plug>(q):", ":", { desc = "Open cmdline" })
vim.keymap.set("n", "<Plug>(q)", "q")

-- <C-L> moves windows, so <Esc> takes over its nohlsearch and diffupdate
-- redrawstatus clears the statusline search count, which nohlsearch alone leaves stale
map("n", "<Esc>", "<Cmd>nohlsearch<Bar>diffupdate<Bar>redrawstatus<CR>", "Clear search highlight")

-- indent keeps the selection, so > can be pressed repeatedly
map("x", ">", ">gv", "Indent and reselect")
map("x", "<", "<gv", "Dedent and reselect")

-- centered scrolling/search
map("n", "<C-d>", "<C-d>zz", "Scroll down and center")
map("n", "<C-u>", "<C-u>zz", "Scroll up and center")
map("n", "n", "nzzzv", "Next search result and center")
map("n", "N", "Nzzzv", "Previous search result and center")

map("n", "<leader>tw", "<cmd>set wrap!<CR>", "Toggle word wrap")
map("n", "<leader>ts", "<cmd>set spell!<CR>", "Toggle spell")
