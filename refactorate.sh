#!/bin/bash
TARGET_DIR="lua/multi_context"

cat << 'EOF' > "$TARGET_DIR/ui/scroller.lua"
-- lua/multi_context/ui/scroller.lua
local api = vim.api
local M = {}

M.state = {
    is_streaming = false,
    is_following = true,
    last_row = 0,
    augroup = api.nvim_create_augroup("MultiContextScroller", { clear = true })
}

M.start_streaming = function(buf, win)
    M.state.is_streaming = true
    M.state.is_following = true
    M.state.last_row = 0

    if win and api.nvim_win_is_valid(win) and buf and api.nvim_buf_is_valid(buf) then
        local lines = api.nvim_buf_line_count(buf)
        pcall(api.nvim_win_set_cursor, win, {lines, 0})
        M.state.last_row = lines
    end

    api.nvim_clear_autocmds({ group = M.state.augroup, buffer = buf })
    api.nvim_create_autocmd("CursorMoved", {
        group = M.state.augroup,
        buffer = buf,
        callback = function()
            if not M.state.is_streaming then return end
            if not api.nvim_win_is_valid(win) then return end
            
            local cursor_row = api.nvim_win_get_cursor(win)[1]
            local total_lines = api.nvim_buf_line_count(buf)
            
            -- A SUA LÓGICA: Tem que estar estritamente na última linha para seguir!
            if cursor_row == total_lines then
                M.state.is_following = true
            -- Qualquer subida real (mesmo que apenas 1 k) vai ser menor que a last_row
            elseif cursor_row < M.state.last_row then
                M.state.is_following = false
            end
            
            M.state.last_row = cursor_row
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
                vim.cmd("normal! G")
            end)
        end
    end
end

M.stop_streaming = function(buf)
    M.state.is_streaming = false
    M.state.is_following = true
    M.state.last_row = 0
    pcall(api.nvim_clear_autocmds, { group = M.state.augroup, buffer = buf })
end

return M
EOF

echo "✅ Scroller atualizado: Matemática simplificada e exata aplicada com sucesso!"
