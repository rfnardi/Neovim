local utils = require('multi_context.utils')
local popup = require('multi_context.popup')

local M = {}

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

M.ContextChatHandler = function(start_line, end_line)
    if start_line and end_line and tonumber(start_line) and tonumber(end_line) and tonumber(end_line) ~= tonumber(start_line) then
        -- seleção de múltiplas linhas
        M.ContextChatSelection(start_line, end_line)
    else
        -- modo normal ou range de uma linha
        M.ContextChatFull()
    end
end

return M
