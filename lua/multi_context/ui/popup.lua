local api = vim.api
local M   = {}

M.popup_buf = nil
M.popup_win = nil

function M.create_popup(initial_content_or_bufnr)
    if M.popup_win and api.nvim_win_is_valid(M.popup_win) then
        api.nvim_set_current_win(M.popup_win)
        return M.popup_buf, M.popup_win
    end

    local config = require('multi_context.config')
    local hl     = require('multi_context.ui.highlights')
    
    local buf
    
    if type(initial_content_or_bufnr) == "number" and api.nvim_buf_is_valid(initial_content_or_bufnr) then
        buf = initial_content_or_bufnr
    else
        buf = api.nvim_create_buf(false, true)
        
        -- >>> DE VOLTA À PAZ: O Coc ignora buffers nofile, o que mata os menus fantasmas! <<<
        vim.bo[buf].buftype   = 'nofile'
        vim.bo[buf].bufhidden = 'hide'
        vim.bo[buf].swapfile  = false
        
        local user_prefix = "## " .. config.options.user_name .. " >> "
        if type(initial_content_or_bufnr) == "string" and initial_content_or_bufnr ~= "" then
            local init_lines = vim.split(initial_content_or_bufnr, "\n", { plain = true })
            api.nvim_buf_set_lines(buf, 0, -1, false, init_lines)
            
            local has_prompt = false
            for i = #init_lines, 1, -1 do
                if init_lines[i] ~= "" then
                    if init_lines[i]:match("^## " .. config.options.user_name .. " >>") then
                        has_prompt = true
                    end
                    break
                end
            end
            
            if not has_prompt then
                api.nvim_buf_set_lines(buf, -1, -1, false, { "", user_prefix })
            end
        else
            api.nvim_buf_set_lines(buf, 0, -1, false, { user_prefix })
        end
    end

    M.popup_buf = buf
    vim.bo[buf].filetype  = 'multicontext_chat'

    local km = { noremap = true, silent = true }
    api.nvim_buf_set_keymap(buf, "n", "<CR>", "<Cmd>lua require('multi_context').SendFromPopup()<CR>", km)
    api.nvim_buf_set_keymap(buf, "i", "<C-CR>", "<Esc><Cmd>lua require('multi_context').SendFromPopup()<CR>", km)
    api.nvim_buf_set_keymap(buf, "n", "<C-CR>", "<Cmd>lua require('multi_context').SendFromPopup()<CR>", km)
    api.nvim_buf_set_keymap(buf, "i", "<S-CR>", "<Esc><Cmd>lua require('multi_context').SendFromPopup()<CR>", km)
    api.nvim_buf_set_keymap(buf, "n", "<S-CR>", "<Cmd>lua require('multi_context').SendFromPopup()<CR>", km)
    
    -- O nosso atalho perfeito do menu de Agentes:
    api.nvim_buf_set_keymap(buf, "i", "@", "@<Esc><Cmd>lua require('multi_context.agents').open_agent_selector()<CR>", km)

    api.nvim_buf_set_keymap(buf, "n", "<A-b>", "<Cmd>lua require('multi_context.utils').copy_code_block()<CR>", km)
    api.nvim_buf_set_keymap(buf, "i", "<A-b>", "<Esc><Cmd>lua require('multi_context.utils').copy_code_block()<CR>a", km)
    api.nvim_buf_set_keymap(buf, "n", "q", "<Cmd>q<CR>", km)

    api.nvim_buf_set_keymap(buf, "i", "@", "@<Esc><Cmd>lua require('multi_context.agents').open_agent_selector()<CR>", km)

    local width  = math.ceil(vim.o.columns * 0.8)
    local height = math.ceil(vim.o.lines   * 0.8)
    local row    = math.ceil((vim.o.lines   - height) / 2)
    local col    = math.ceil((vim.o.columns - width)  / 2)

    local win = api.nvim_open_win(buf, true, {
        relative  = 'editor',
        width     = width,
        height    = height,
        row       = row,
        col       = col,
        style     = 'minimal',
        border    = 'rounded',
        title     = " Multi_Context_Chat ",
        title_pos = 'center',
    })
    M.popup_win = win

    api.nvim_create_autocmd("WinClosed", {
        pattern  = tostring(win),
        once     = true,
        callback = function() M.popup_win = nil end,
    })

    local last_ln  = api.nvim_buf_line_count(buf)
    local last_txt = api.nvim_buf_get_lines(buf, last_ln - 1, last_ln, false)[1] or ""
    api.nvim_win_set_cursor(win, { last_ln, #last_txt })

    hl.apply_chat(buf)
    M.create_folds(buf)

    return buf, win
end

function M.fold_text()
	local lines_count = vim.v.foldend - vim.v.foldstart + 1
	local preview = ""
	for i = vim.v.foldstart, vim.v.foldend do
		local l = vim.fn.getline(i)
		if l:match("%S") then
			preview = vim.trim(l)
			break
		end
	end
	return "    ↳ ⋯ [" .. lines_count .. " linhas ocultas] ⋯  " .. preview
end

function M.create_folds(buf)
	if not buf or not api.nvim_buf_is_valid(buf) then return end

	local config = require('multi_context.config')
	local user_name = config.options.user_name or "User"

	vim.schedule(function()
		if not api.nvim_buf_is_valid(buf) then return end

		local windows = vim.fn.win_findbuf(buf)
		for _, win in ipairs(windows) do
			if api.nvim_win_is_valid(win) then
				vim.api.nvim_win_call(win, function()
					vim.cmd("setlocal foldmethod=manual")
					vim.cmd("setlocal foldexpr=")
					vim.cmd("setlocal foldtext=v:lua.require('multi_context.ui.popup').fold_text()")
					pcall(vim.cmd, 'normal! zE')

					local total_lines = vim.api.nvim_buf_line_count(buf)
					local headers = {}

					for lnum = 1, total_lines do
						local line = vim.api.nvim_buf_get_lines(buf, lnum - 1, lnum, false)[1]
						if line and (line:match("^===") or line:match("^== Arquivo:") or 
							line:match("^## " .. user_name .. " >>") or line:match("^## IA")) then
							table.insert(headers, lnum)
						end
					end

					for idx, h_lnum in ipairs(headers) do
						local header_text = vim.api.nvim_buf_get_lines(buf, h_lnum - 1, h_lnum, false)[1]

						if not header_text:match("^## " .. user_name) then
							local start_fold = h_lnum + 1
							local end_fold = total_lines

							-- A dobra engole TUDO até a linha imediatamente antes do próximo arquivo
							if idx < #headers then
								end_fold = headers[idx + 1] - 1
							end

							if end_fold >= start_fold then
								pcall(vim.cmd, string.format("%d,%dfold", start_fold, end_fold))
								pcall(vim.cmd, string.format("%dfoldclose", start_fold))
							end
						end
					end

					for i = #headers, 1, -1 do
						local h_lnum = headers[i]
						local l = vim.api.nvim_buf_get_lines(buf, h_lnum - 1, h_lnum, false)[1]
						if l and l:match("^## IA") then
							pcall(vim.cmd, string.format("silent! %dfoldopen!", h_lnum + 1))
							break
						end
					end

					-- TRUQUE DE MESTRE: Posicionamento elegante a 2/3 da tela
					local win_height = vim.api.nvim_win_get_height(win)
					local target_scrolloff = math.floor(win_height / 3)
					local current_so = vim.wo.scrolloff

					-- Aplica o scrolloff (que atua como um "colchão" no fundo da janela)
					vim.wo.scrolloff = target_scrolloff

					-- Move o cursor logicamente para o fundo ('zb') que será barrado pelo colchão
					pcall(vim.cmd, "normal! zb")

					-- Devolve o scrolloff padrão para não afetar sua navegação depois
					vim.wo.scrolloff = current_so
				end)
			end
		end
	end)
end

function M.update_title() end
return M
