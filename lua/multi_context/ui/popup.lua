-- ui/popup.lua
-- Cria e gerencia a janela flutuante de chat.
-- Não sabe nada sobre histórico, API ou envio de mensagens.
local api = vim.api
local M   = {}

M.popup_buf = nil
M.popup_win = nil

-- Cria o popup ou foca no existente se já estiver aberto.
-- initial_content: string com contexto a pré-popular (ou "" para janela limpa).
function M.create_popup(initial_content)
    if M.popup_win and api.nvim_win_is_valid(M.popup_win) then
        api.nvim_set_current_win(M.popup_win)
        return M.popup_buf, M.popup_win
    end

    local config = require('multi_context.config')
    local hl     = require('multi_context.ui.highlights')

    local buf = api.nvim_create_buf(false, true)
    M.popup_buf = buf

    vim.bo[buf].buftype   = 'nofile'
    vim.bo[buf].filetype  = 'markdown'
    vim.bo[buf].bufhidden = 'hide'
    vim.bo[buf].swapfile  = false

    local km = { noremap = true, silent = true }
    api.nvim_buf_set_keymap(buf, "n", "<CR>",
        "<Cmd>lua require('multi_context').SendFromPopup()<CR>", km)
    api.nvim_buf_set_keymap(buf, "n", "<A-b>",
        "<Cmd>lua require('multi_context.utils').copy_code_block()<CR>", km)
    api.nvim_buf_set_keymap(buf, "i", "<A-b>",
        "<Esc><Cmd>lua require('multi_context.utils').copy_code_block()<CR>a", km)
    api.nvim_buf_set_keymap(buf, "n", "q", "<Cmd>q<CR>", km)

    local width  = math.ceil(vim.o.columns * 0.8)
    local height = math.ceil(vim.o.lines   * 0.8)
    local row    = math.ceil((vim.o.lines   - height) / 2)
    local col    = math.ceil((vim.o.columns - width)  / 2)

    local api_name = config.get_current_api()
    local title    = " " .. (api_name ~= "" and api_name or "MultiContext AI") .. " "

    local win = api.nvim_open_win(buf, true, {
        relative  = 'editor',
        width     = width,
        height    = height,
        row       = row,
        col       = col,
        style     = 'minimal',
        border    = 'rounded',
        title     = title,
        title_pos = 'center',
    })
    M.popup_win = win

		api.nvim_create_autocmd("WinClosed", {
				pattern  = tostring(win),
				once     = true,
				callback = function() M.popup_win = nil; M.popup_buf = nil end,
		})

		api.nvim_create_autocmd("BufWipeout", {
				buffer   = buf,
				once     = true,
				callback = function()
						if vim.api.nvim_buf_is_valid(buf) then
								vim.bo[buf].modifiable = true
						end
				end,
		})

    -- Popula conteúdo inicial e posiciona cursor
    local user_prefix = "## " .. config.options.user_name .. " >> "
    if initial_content and initial_content ~= "" then
        local init_lines = vim.split(initial_content, "\n", { plain = true })
        api.nvim_buf_set_lines(buf, 0, -1, false, init_lines)
        api.nvim_buf_set_lines(buf, -1, -1, false, { "", user_prefix })
    else
        api.nvim_buf_set_lines(buf, 0, -1, false, { user_prefix })
    end

    local last_ln  = api.nvim_buf_line_count(buf)
    local last_txt = api.nvim_buf_get_lines(buf, last_ln - 1, last_ln, false)[1] or ""
    api.nvim_win_set_cursor(win, { last_ln, #last_txt })

    hl.apply_chat(buf)
    M._setup_folds()

    return buf, win
end

function M._setup_folds()
    if not M.popup_win or not api.nvim_win_is_valid(M.popup_win) then return end
    vim.wo[M.popup_win].foldmethod = 'marker'
    vim.wo[M.popup_win].foldmarker = '## IA >>,## API atual:'
    vim.wo[M.popup_win].foldlevel  = 99
end

-- Atualiza o título da janela com a API atual (chamado após :ContextApis)
function M.update_title()
    if not M.popup_win or not api.nvim_win_is_valid(M.popup_win) then return end
    local api_name = require('multi_context.config').get_current_api()
    local title    = " " .. (api_name ~= "" and api_name or "MultiContext AI") .. " "
    api.nvim_win_set_config(M.popup_win, { title = title, title_pos = 'center' })
end

-- Alias para compatibilidade com código que ainda chama create_folds(buf)
M.create_folds = M._setup_folds

return M
