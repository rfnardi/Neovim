-- lua/multi_context/ui/scroller.lua
local api = vim.api
local M = {}

M.state = {
    is_streaming = false,
    is_following = true,
    augroup = api.nvim_create_augroup("MultiContextScroller", { clear = true })
}

M.start_streaming = function(buf, win)
    M.state.is_streaming = true
    M.state.is_following = true

    if win and api.nvim_win_is_valid(win) and buf and api.nvim_buf_is_valid(buf) then
        local lines = api.nvim_buf_line_count(buf)
        pcall(api.nvim_win_set_cursor, win, {lines, 0})
    end

    -- Liga o monitor de cursor APENAS durante a entrega da IA
    api.nvim_clear_autocmds({ group = M.state.augroup, buffer = buf })
    api.nvim_create_autocmd("CursorMoved", {
        group = M.state.augroup,
        buffer = buf,
        callback = function()
            if not M.state.is_streaming then return end
            if not api.nvim_win_is_valid(win) then return end
            
            local cursor_row = api.nvim_win_get_cursor(win)[1]
            local total_lines = api.nvim_buf_line_count(buf)
            
            -- Margem de 1 linha caso o usuário esbarre.
            -- Se ele subir para a linha 10 num texto de 20, is_following vira false.
            if cursor_row >= total_lines - 1 then
                M.state.is_following = true
            else
                M.state.is_following = false
            end
        end
    })
end

M.on_chunk_received = function(buf, win)
    if not M.state.is_streaming then return end
    
    if M.state.is_following then
        if win and api.nvim_win_is_valid(win) and buf and api.nvim_buf_is_valid(buf) then
            local lines = api.nvim_buf_line_count(buf)
            pcall(api.nvim_win_set_cursor, win, {lines, 0})
            vim.api.nvim_win_call(win, function()
                vim.cmd("normal! zz")
            end)
        end
    end
end

M.stop_streaming = function(buf)
    M.state.is_streaming = false
    M.state.is_following = true
    -- Destrói o monitor de cursor para economizar processamento do Neovim
    pcall(api.nvim_clear_autocmds, { group = M.state.augroup, buffer = buf })
end

return M
