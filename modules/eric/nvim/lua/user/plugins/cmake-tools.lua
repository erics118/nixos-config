return {
    "cmake-tools.nvim",
    -- load on filetype: cmd-only lazy-loading runs setup() too late for cmake_regenerate_on_save
    -- the cmds let :CMakeBuild and friends work from other buffers
    -- the default compile_commands action symlinks compile_commands.json into cwd for clangd
    ft = { "cmake", "c", "cpp" },
    cmd = { "CMakeGenerate", "CMakeBuild", "CMakeRun" },
    after = function()
        require("cmake-tools").setup({ cmake_regenerate_on_save = true })
    end,
}
