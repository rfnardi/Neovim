-- queue_editor.lua
-- Buffer interativo para reordenar a fila de APIs (dd/p para mover, :w para salvar).
local api = vim.api
local M   = {}

M.open_editor = function()
    local config = require('multi_context.config')
    local cfg    = config.load_api_config()
    if not cfg then
        vim.notify("Configuração não encontrada.", vim.log.levels.ERROR)
        return
    end

    local names = {}
    for _, a in ipairs(cfg.apis) do table.insert(names, a.name) end

    local buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_lines(buf, 0, -1, false, names)

    -- buftype 'acwrite' permite :w sem arquivo físico (evita E32)
    vim.bo[buf].buftype = 'acwrite'
    api.nvim_buf_set_name(buf, "MultiContext_Queue_Editor")

    local height = math.min(#names + 2, 20)
    local win    = api.nvim_open_win(buf, true, {
        relative  = 'editor',
        width     = 52,
        height    = height,
        row       = 5,
        col       = 10,
        border    = 'rounded',
        title     = ' Ordenar Fila  (dd/p mover · :w salvar) ',
        title_pos = 'center',
    })

    api.nvim_create_autocmd("BufWriteCmd", {
        buffer   = buf,
        callback = function()
            local lines     = api.nvim_buf_get_lines(buf, 0, -1, false)
            local reordered = {}
            for _, name in ipairs(lines) do
                for _, a in ipairs(cfg.apis) do
                    if a.name == name then table.insert(reordered, a); break end
                end
            end
            cfg.apis = reordered
            if config.save_api_config(cfg) then
                vim.notify("Fila salva!", vim.log.levels.INFO)
                vim.bo[buf].modified = false
                api.nvim_win_close(win, true)
            else
                vim.notify("Erro ao salvar.", vim.log.levels.ERROR)
            end
        end,
    })

    api.nvim_buf_set_keymap(buf, "n", "q", ":q!<CR>", { noremap = true, silent = true })
end

return M
