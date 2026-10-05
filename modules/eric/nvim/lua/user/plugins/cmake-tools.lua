local function map(lhs, command, desc)
    vim.keymap.set("n", lhs, "<cmd>" .. command .. "<CR>", { silent = true, desc = desc })
end

map("<leader>cg", "CMakeGenerate", "CMake generate")
map("<leader>cb", "CMakeBuild", "CMake build")
map("<leader>cr", "CMakeRun", "CMake run")

return {
    "cmake-tools.nvim",
    -- load on filetype: cmd-only lazy-loading runs setup() too late for cmake_regenerate_on_save
    -- the cmds let the keymaps work from other buffers
    -- the default compile_commands action symlinks compile_commands.json into cwd for clangd
    ft = { "cmake", "c", "cpp" },
    cmd = { "CMakeGenerate", "CMakeBuild", "CMakeRun" },
    after = function()
        require("cmake-tools").setup({ cmake_regenerate_on_save = true })
    end,
}
