-- files copilot may never see, even when toggled on
local function allowed(bufnr)
    if not vim.bo[bufnr].buflisted or vim.bo[bufnr].buftype ~= "" then
        return false
    end
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    if vim.fn.fnamemodify(bufname, ":t"):match("^%.env") or bufname:match("/secrets/") then
        return false
    end
    return true
end

-- copilot attaches to no file on its own, <leader>tc attaches or detaches the current one
vim.keymap.set("n", "<leader>tc", function()
    require("lz.n").trigger_load("copilot.lua")
    local client = require("copilot.client")
    local bufnr = vim.api.nvim_get_current_buf()
    if client.buf_is_attached(bufnr) then
        require("copilot.command").detach()
        vim.notify("Copilot: OFF for this file", vim.log.levels.INFO)
    elseif allowed(bufnr) then
        -- force skips should_attach, which refuses every file to stop automatic attaching
        client.buf_attach(true, bufnr)
        vim.notify("Copilot: ON for this file", vim.log.levels.INFO)
    else
        vim.notify("Copilot: not allowed for this file", vim.log.levels.WARN)
    end
end, { silent = true, desc = "Toggle Copilot for this file" })

return {
    "copilot.lua",
    -- ready once the screen is drawn, so the first toggle is instant
    event = "DeferredUIEnter",
    after = function()
        require("copilot").setup({
            panel = { enabled = false },
            should_attach = function()
                return false
            end,
            suggestion = {
                enabled = true,
                auto_trigger = true,
                debounce = 75,
                keymap = { accept = "<C-h>" },
                -- <C-h> is also backspace, so pass it through when there is no suggestion to accept
                trigger_on_accept = false,
            },
        })
    end,
}
