local api = vim.api
local utils = require('multi_context.utils')
local popup = require('multi_context.popup')

local M = {}

M.ContextTree = function()
    local text = utils.read_tree_context() -- Cria funcao nova no utils
    if text == "" then
        return
    end
    popup.open_popup(text, text)
end

M.ContextChatFull = function()
	local text = utils.get_full_buffer()
	popup.open_popup(text, text)
end

M.ContextChatSelection = function(start_line, end_line)
	local text = utils.get_selection(start_line, end_line)
	popup.open_popup(text, text)
end

M.ContextChatFolder = function()
	local text = utils.read_folder_context()
	popup.open_popup(text, text)
end

M.ContextChatRepo = function()
    local text = utils.read_repo_context()
    if text == "" then
        return
    end
    popup.open_popup(text, text)
end


M.ContextChatGit = function()
	local diff_text, error_msg = utils.get_git_diff()
	if error_msg then
		vim.notify(error_msg, vim.log.levels.WARN)
		return
	end

	popup.open_popup(diff_text, diff_text)
end

M.ContextApis = function()
	-- Carregar o módulo api_selector de forma segura
	local status, api_selector = pcall(require, 'multi_context.api_selector')
	if not status then
		vim.notify("Erro ao carregar o seletor de APIs: " .. api_selector, vim.log.levels.ERROR)
		return
	end

	api_selector.open_api_selector()
end

M.ContextChatHandler = function(start_line, end_line)
	if start_line and end_line and tonumber(start_line) and tonumber(end_line) and tonumber(end_line) ~= tonumber(start_line) then
		-- seleção de múltiplas linhas
		M.ContextChatSelection(start_line, end_line)
	else
		-- modo normal ou range de uma linha
		M.ContextChatFull()
	end
end

M.TogglePopup = function()
  require('multi_context').TogglePopup()
end

return M
