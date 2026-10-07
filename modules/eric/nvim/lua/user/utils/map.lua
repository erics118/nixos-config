-- vim.keymap.set with the options every global mapping here shares
return function(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, { silent = true, desc = desc })
end
