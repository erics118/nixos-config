return function(bufnr, on_dir)
    local function has_tailwind(deps)
        if type(deps) ~= "table" then
            return false
        end

        return deps.tailwindcss ~= nil
            or vim.iter(vim.tbl_keys(deps)):any(function(name)
                return vim.startswith(name, "@tailwindcss/")
            end)
    end

    local bufname = vim.api.nvim_buf_get_name(bufnr)
    if bufname == "" then
        return
    end

    local path = vim.fs.dirname(bufname)
    if path == nil then
        return
    end

    local package_json = vim.fs.find("package.json", { upward = true, path = path })[1]
    if package_json == nil then
        return
    end

    local ok, decoded = pcall(vim.json.decode, table.concat(vim.fn.readfile(package_json), "\n"))
    if not ok or type(decoded) ~= "table" then
        return
    end

    if has_tailwind(decoded.dependencies) or has_tailwind(decoded.devDependencies) then
        on_dir(vim.fs.dirname(package_json))
    end
end
