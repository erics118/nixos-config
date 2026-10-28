local M = {}

-- source action kinds to apply on save, per server
local kinds_by_client = {
    eslint = { "source.fixAll.eslint" },
    ts_ls = {
        "source.addMissingImports.ts",
        "source.organizeImports.ts",
        "source.fixAll.ts",
    },
    -- conform already runs ruff_format and ruff_organize_imports
    ruff = { "source.fixAll.ruff" },
}

-- every request blocks the save, so all of them share one time budget
local budget_ms = 2000

local function remaining(deadline)
    return deadline - vim.uv.hrtime() / 1e6
end

-- applied one kind at a time so they run in the order listed above
local function apply_source_actions(client, bufnr, kinds, deadline)
    for _, kind in ipairs(kinds) do
        if remaining(deadline) <= 0 then
            return
        end
        local params = vim.lsp.util.make_range_params(0, client.offset_encoding) --[[@as lsp.CodeActionParams]]
        params.context = { only = { kind }, diagnostics = {} }

        local res = client:request_sync("textDocument/codeAction", params, remaining(deadline), bufnr)
        -- a JSON null result arrives as vim.NIL, not nil
        local actions = res and type(res.result) == "table" and res.result or {}
        for _, action in ipairs(actions) do
            -- servers may return an unresolved action carrying only `data`
            if not action.edit and action.data and remaining(deadline) > 0 then
                local resolved = client:request_sync("codeAction/resolve", action, remaining(deadline), bufnr)
                if resolved and type(resolved.result) == "table" then
                    action = resolved.result
                end
            end
            if action.edit then
                vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
            end
        end
    end
end

function M.run(bufnr)
    local deadline = vim.uv.hrtime() / 1e6 + budget_ms
    for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
        local kinds = kinds_by_client[client.name]
        if kinds then
            apply_source_actions(client, bufnr, kinds, deadline)
        end
    end
end

return M
