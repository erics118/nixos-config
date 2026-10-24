local map = require("user.utils.map")

local function move(direction)
    return function()
        require("smart-splits")["move_cursor_" .. direction]()
    end
end

-- split navigation, continuing into the next tmux pane at an edge (see tmux/keys.conf)
map("n", "<C-J>", move("down"), "Move to window below")
map("n", "<C-K>", move("up"), "Move to window above")
map("n", "<C-L>", move("right"), "Move to window right")
map("n", "<C-H>", move("left"), "Move to window left")

return {
    -- no trigger, so it loads at startup and tmux sees @pane-is-vim before the first C-h/j/k/l
    "smart-splits.nvim",
    after = function()
        require("smart-splits").setup({
            -- nvim also runs outside tmux, where the backend is expected to be missing
            mux = { backend = "smart-splits-backend-tmux", warn_if_unusable = false },
            move = { at_edge = "stop" },
        })
    end,
}
