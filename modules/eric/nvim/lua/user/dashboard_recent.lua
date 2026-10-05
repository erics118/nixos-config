return function()
    local buttons = {}
    local max = 9
    -- only files under the folder nvim was opened in, like <leader>fr
    local cwd = vim.fn.getcwd()
    for _, file in ipairs(vim.v.oldfiles) do
        if vim.fn.filereadable(file) == 1 and vim.fs.relpath(cwd, file) then
            local n = #buttons + 1
            if n > max then
                break
            end
            local key = tostring(n)
            local short = vim.fn.fnamemodify(file, ":~:.")
            if #short > 46 then
                short = "…" .. string.sub(short, -45)
            end
            table.insert(buttons, {
                type = "button",
                val = "  " .. short,
                on_press = function()
                    vim.cmd("edit " .. vim.fn.fnameescape(file))
                end,
                opts = {
                    shortcut = key,
                    align_shortcut = "right",
                    hl_shortcut = "Keyword",
                    position = "center",
                    width = 50,
                    keymap = {
                        "n",
                        key,
                        "<cmd>edit " .. vim.fn.fnameescape(file) .. "<cr>",
                        { noremap = true, silent = true, nowait = true },
                    },
                },
            })
        end
    end
    return buttons
end
