local api = vim.api
local utils = require('multi_context.utils')
local popup = require('multi_context.popup')
local commands = require('multi_context.commands')
local api_handlers = require('multi_context.api_handlers')

local M = {}

M.popup_buf = popup.popup_buf
M.popup_win = popup.popup_win
M.history = {}
M.context_text = nil

-- Expor funções públicas
M.ContextChatFull = commands.ContextChatFull
M.ContextChatSelection = commands.ContextChatSelection
M.ContextChatFolder = commands.ContextChatFolder
M.ContextChatHandler = commands.ContextChatHandler
M.ContextChatRepo = commands.ContextChatRepo
M.ContextChatGit = commands.ContextChatGit
M.ContextApis = commands.ContextApis


-- ======================================================
-- Envio para LLM
-- ======================================================
function M.SendFromPopup()
	if not popup.popup_buf or not api.nvim_buf_is_valid(popup.popup_buf) then
		vim.notify("Popup não está aberto. Use :Context, :ContextRange ou :ContextFolder", vim.log.levels.WARN)
		return
	end

	local buf = popup.popup_buf
	local start_idx, _ = utils.find_last_user_line(buf)
	if not start_idx then
		vim.notify("Nenhuma linha '## Nardi >>' encontrada.", vim.log.levels.WARN)
		return
	end

	local lines = api.nvim_buf_get_lines(buf, start_idx, -1, false)
	local user_text = table.concat(lines, "\n"):gsub("^## Nardi >>%s*", "")
	if user_text == "" then
		vim.notify("Digite algo após '## Nardi >>' antes de enviar.", vim.log.levels.WARN)
		return
	end

	-- marca envio
	api.nvim_buf_set_lines(buf, -1, -1, false, { "[mensagem enviada]" })
	vim.notify("mensagem enviada", vim.log.levels.INFO)

	table.insert(M.history, { user = user_text, ai = nil })

	-- Obter TODO o conteúdo do popup (contexto + histórico)
	local full_context = utils.get_popup_content(buf)

	-- Construir mensagens para a API
	local messages = {}

	-- Adicionar todo o contexto do popup como mensagem de sistema
	table.insert(messages, { role = "system", content = full_context })

	-- Adicionar apenas a última mensagem do usuário (o que foi digitado após ## Nardi >>)
	table.insert(messages, { role = "user", content = user_text })

	-- Carregar configurações das APIs
	local api_config = utils.load_api_config()
	if not api_config then
		vim.notify("Arquivo de configuração das APIs não encontrado", vim.log.levels.ERROR)
		return
	end

	-- Carregar chaves de API
	local api_keys = utils.load_api_keys()

	local selected_api = api_config.default_api
	local fallback_mode = api_config.fallback_mode or false
	local apis = api_config.apis or {}

	-- Função para tentar a próxima API em caso de falha
	local function try_apis(api_list, index)
		if index > #api_list then
			vim.notify("Todas as APIs falharam", vim.log.levels.ERROR)
			return
		end

		local current_api = api_list[index]
		local handler = api_handlers[current_api.api_type or "openai"]

		if not handler then
			vim.notify("Tipo de API não suportado: " .. (current_api.api_type or "unknown"), vim.log.levels.ERROR)
			if fallback_mode then
				try_apis(api_list, index + 1)
			end
			return
		end

		handler.make_request(current_api, messages, api_keys, function(success, result)
			if success then
				local ai_content, error_msg = handler.parse_response(result)
				if not ai_content then
					vim.notify("Erro ao processar resposta: " .. error_msg, vim.log.levels.ERROR)
					if fallback_mode then
						try_apis(api_list, index + 1)
					end
					return
				end

				ai_content = "## IA (" .. current_api.model .. ") >> \n" .. ai_content
				M.history[#M.history].ai = ai_content

				vim.schedule(function()
					local last_line = api.nvim_buf_line_count(buf) - 1
					local ai_lines = utils.split_lines(ai_content)

					-- Inserir a resposta da IA
					utils.insert_after(buf, last_line, ai_lines)

					-- Inserir a linha da API atual e o novo prompt
					local current_api_name = current_api and current_api.name or "API desconhecida"
					utils.insert_after(buf, -1, { "## API atual: " .. current_api_name, "## Nardi >> " })

					-- Aplicar highlights novamente para incluir as novas linhas
					utils.apply_highlights(buf)

					-- Recriar as folds
					popup.create_folds(buf)

					if popup.popup_win and api.nvim_win_is_valid(popup.popup_win) then
						api.nvim_win_set_cursor(popup.popup_win, { api.nvim_buf_line_count(buf), #"## Nardi >> " })
					end
					vim.cmd("normal! zz")
					vim.notify("mensagem recebida de " .. (current_api and current_api.name or "API desconhecida"), vim.log.levels.INFO)
				end)
			else
				vim.notify("API " .. current_api.name .. " falhou: " .. result, vim.log.levels.WARN)
				if fallback_mode then
					try_apis(api_list, index + 1)
				end
			end
		end)
	end

	-- Determinar qual API(s) usar
	local api_list = {}
	if fallback_mode then
		api_list = apis
	else
		-- Encontrar a API pelo nome
		for _, api in ipairs(apis) do
			if api.name == selected_api then
				api_list = {api}
				break
			end
		end
		if #api_list == 0 and #apis > 0 then
			api_list = {apis[1]}
		end
	end

	-- Fazer a requisição
	if #api_list > 0 then
		try_apis(api_list, 1)
	else
		vim.notify("Nenhuma API configurada", vim.log.levels.ERROR)
	end
end

return M
