-- direnv-instant applies the env to the shell after the prompt, so an nvim started early lacks it
-- runs before plugins, since vimtex and the lsp servers look up their tools when they load
if vim.env.DIRENV_DIR or not vim.fs.root(vim.fn.getcwd(), ".envrc") or vim.fn.executable("direnv") == 0 then
    return
end

local res = vim.system({ "direnv", "export", "json" }, { text = true }):wait()
if res.code ~= 0 then
    vim.notify("direnv: " .. vim.trim(res.stderr), vim.log.levels.WARN)
    return
end
-- empty when the .envrc changes nothing
if res.stdout == "" then
    return
end
-- a null value means direnv unsets the variable
for name, value in pairs(vim.json.decode(res.stdout)) do
    vim.env[name] = value ~= vim.NIL and value or nil
end
