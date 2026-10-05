local function map(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, { silent = true, desc = desc })
end

-- split navigation
map("n", "<C-J>", "<C-W>j", "Move to window below")
map("n", "<C-K>", "<C-W>k", "Move to window above")
map("n", "<C-L>", "<C-W>l", "Move to window right")
map("n", "<C-H>", "<C-W>h", "Move to window left")
map("n", "<C-W>\\", "<Cmd>vsplit<CR>", "Vertical split")
map("n", "<C-W>-", "<Cmd>split<CR>", "Horizontal split")

-- terminal
map("t", "<Esc>", "<C-\\><C-n>", "Exit terminal mode")

-- <C-L> moves windows, so <Esc> takes over its nohlsearch and diffupdate
map("n", "<Esc>", "<Cmd>nohlsearch<Bar>diffupdate<CR>", "Clear search highlight")

-- centered scrolling/search
map("n", "<C-d>", "<C-d>zz", "Scroll down and center")
map("n", "<C-u>", "<C-u>zz", "Scroll up and center")
map("n", "n", "nzzzv", "Next search result and center")
map("n", "N", "Nzzzv", "Previous search result and center")

map("n", "<leader>te", "<Cmd>NvimTreeToggle<CR>", "Toggle file tree")
map("n", "<leader>tw", "<cmd>set wrap!<CR>", "Toggle word wrap")
map("n", "<leader>ts", "<cmd>set spell!<CR>", "Toggle spell")

-- on macOS Alt is consumed by the WM, so use <leader>b... for non-digit bufferline ops
-- digits use <C-N> on all platforms (modern terminals support it via the kitty/CSI-u keyboard protocol)
local is_darwin = vim.uv.os_uname().sysname == "Darwin"
local function buf_key(suffix)
    return is_darwin and "<leader>b" .. suffix or "<A-" .. suffix .. ">"
end

map("n", buf_key(","), "<Cmd>BufferLineCyclePrev<CR>", "Previous buffer")
map("n", buf_key("."), "<Cmd>BufferLineCycleNext<CR>", "Next buffer")
map("n", buf_key("<"), "<Cmd>BufferLineMovePrev<CR>", "Move buffer left")
map("n", buf_key(">"), "<Cmd>BufferLineMoveNext<CR>", "Move buffer right")
for i = 1, 9 do
    map("n", "<C-" .. i .. ">", "<Cmd>BufferLineGoToBuffer " .. i .. "<CR>", "Go to buffer " .. i)
end
map("n", "<C-0>", "<Cmd>BufferLineGoToBuffer -1<CR>", "Go to last buffer")
map("n", buf_key("p"), "<Cmd>BufferLineTogglePin<CR>", "Pin/unpin buffer")
map("n", buf_key("x"), "<Cmd>bdelete<CR>", "Close buffer")
map("n", buf_key("X"), "<Cmd>bdelete!<CR>", "Force close buffer")
map("n", buf_key("c"), "<Cmd>enew<CR>", "Create new buffer")
-- buf_key would build "<A-<Space>>", which is not a key
map("n", is_darwin and "<leader>b<Space>" or "<A-Space>", "<Cmd>BufferLinePick<CR>", "Pick buffer")
map("n", "<leader>bd", "<Cmd>BufferLineSortByDirectory<CR>", "Sort buffers by directory")
map("n", "<leader>bl", "<Cmd>BufferLineSortByExtension<CR>", "Sort buffers by extension")
