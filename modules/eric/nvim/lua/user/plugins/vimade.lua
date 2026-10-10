return {
    "vimade",
    -- fading only matters once a second window exists
    event = "WinNew",
    after = function()
        require("vimade").setup({
            ncmode = "windows",
            -- matches tmux's dim=30% on inactive panes (see tmux/main.conf)
            fadelevel = 0.7,
            -- fade toward black, which scales every colour like tmux's dim and wezterm's inactive_pane_hsb.
            -- NormalNC gives the transparent background a colour to darken (see catppuccin_overrides.lua)
            basebg = "#000000",
        })
        -- tmux already dims a whole unfocused pane, so fading splits too would dim them twice.
        -- focus also leaves when the terminal window does, which tmux doesn't dim, so ask whether this pane is still active
        vim.api.nvim_create_autocmd("FocusLost", {
            callback = function()
                local pane = vim.env.TMUX_PANE
                if pane and vim.fn.system({ "tmux", "display", "-p", "-t", pane, "#{pane_active}" }) == "0\n" then
                    vim.cmd("VimadeDisable")
                end
            end,
        })
        vim.api.nvim_create_autocmd("FocusGained", { command = "VimadeEnable" })
    end,
}
