local map = require("user.utils.map")

-- on macOS Alt is consumed by the WM, so use <leader>b... for non-digit bufferline ops
-- <C-1> to <C-9> select numbered buffers, and <C-0> selects the last buffer, on all platforms
-- modern terminals send these through the kitty/CSI-u keyboard protocol
local is_darwin = vim.uv.os_uname().sysname == "Darwin"
local function buffer_key(suffix)
    return is_darwin and "<leader>b" .. suffix or "<A-" .. suffix .. ">"
end

map("n", buffer_key(","), "<Cmd>BufferLineCyclePrev<CR>", "Previous buffer")
map("n", buffer_key("."), "<Cmd>BufferLineCycleNext<CR>", "Next buffer")
map("n", buffer_key("<"), "<Cmd>BufferLineMovePrev<CR>", "Move buffer left")
map("n", buffer_key(">"), "<Cmd>BufferLineMoveNext<CR>", "Move buffer right")
for i = 1, 9 do
    map("n", "<C-" .. i .. ">", "<Cmd>BufferLineGoToBuffer " .. i .. "<CR>", "Go to buffer " .. i)
end
map("n", "<C-0>", "<Cmd>BufferLineGoToBuffer -1<CR>", "Go to last buffer")
map("n", buffer_key("p"), "<Cmd>BufferLineTogglePin<CR>", "Pin/unpin buffer")
map("n", buffer_key("x"), "<Cmd>bdelete<CR>", "Close buffer")
map("n", buffer_key("X"), "<Cmd>bdelete!<CR>", "Force close buffer")
map("n", buffer_key("c"), "<Cmd>enew<CR>", "Create new buffer")
-- buffer_key would build "<A-<Space>>", which is not a key
map("n", is_darwin and "<leader>b<Space>" or "<A-Space>", "<Cmd>BufferLinePick<CR>", "Pick buffer")
map("n", "<leader>bd", "<Cmd>BufferLineSortByDirectory<CR>", "Sort buffers by directory")
map("n", "<leader>bl", "<Cmd>BufferLineSortByExtension<CR>", "Sort buffers by extension")

return {
    "bufferline.nvim",
    after = function()
        require("bufferline").setup({ highlights = require("catppuccin.special.bufferline").get_theme() })
    end,
}
