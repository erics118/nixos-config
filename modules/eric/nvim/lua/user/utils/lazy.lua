local M = {}

-- lz.n events for plugins that act on file buffers
-- InsertEnter covers :enew buffers, which fire neither read event, and BufWritePre one saved without typing
M.file_events = { "BufReadPost", "BufNewFile", "InsertEnter", "BufWritePre" }

-- lz.n events for insert-mode plugins
-- loaded once the screen is drawn, so the first insert doesn't wait on them
M.insert_events = { "DeferredUIEnter", "InsertEnter" }

return M
