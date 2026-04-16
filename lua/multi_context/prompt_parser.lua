-- lua/multi_context/prompt_parser.lua
local M = {}

M.parse_user_input = function(raw_text, agents_table)
    local parsed = {
        text_to_send = raw_text,
        agent_name = nil,
        is_autonomous = false
    }

    local agent_match = parsed.text_to_send:match("@([%w_]+)")
    if agent_match then
        if agent_match == "reset" then
            parsed.agent_name = "reset"
            parsed.text_to_send = parsed.text_to_send:gsub("@reset%s*", "")
        elseif agents_table[agent_match] then
            parsed.agent_name = agent_match
            parsed.text_to_send = parsed.text_to_send:gsub("@" .. agent_match .. "%s*", "")
        end
    end

    if parsed.text_to_send:match("%-%-auto") then
        parsed.is_autonomous = true
        parsed.text_to_send = parsed.text_to_send:gsub("%-%-auto%s*", "")
    end

		-- NOVO: Limpa espaços em branco residuais nas bordas após remover as tags
    parsed.text_to_send = parsed.text_to_send:gsub("^%s*", ""):gsub("%s*$", "")

    return parsed
end

M.build_system_prompt = function(base_prompt, memory_context, active_agent_name, agents_table)
    local system_prompt = base_prompt

    if memory_context then
        system_prompt = system_prompt .. "\n\n=== ESTADO ATUAL DO PROJETO (MEMÓRIA) ===\n" .. memory_context
    end

    if active_agent_name and active_agent_name ~= "reset" and agents_table[active_agent_name] then
        local agent_data = agents_table[active_agent_name]
        local active_agent_prompt = "\n\n=== INSTRUÇÕES DO AGENTE: " .. string.upper(active_agent_name) .. " ===\n" .. agent_data.system_prompt
        
        if agent_data.use_tools then
            active_agent_prompt = active_agent_prompt .. "\n\n" .. require('multi_context.agents').get_tools_manual()
        end
        
        system_prompt = system_prompt .. active_agent_prompt
    end

    return system_prompt
end

return M
