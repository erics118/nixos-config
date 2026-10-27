-- the first vim.notify call loads nvim-notify, whose setup replaces this stub
local builtin = vim.notify
local function stub(...)
    require("lz.n").trigger_load("nvim-notify")
    -- a failed load falls back to the builtin instead of recursing
    if vim.notify == stub then
        vim.notify = builtin
    end
    return vim.notify(...)
end
vim.notify = stub

return {
    "nvim-notify",
    lazy = true,
    after = function()
        local notify = require("notify")
        notify.setup({ timeout = 1000, render = "compact", stages = "fade" })
        vim.notify = notify
    end,
}
