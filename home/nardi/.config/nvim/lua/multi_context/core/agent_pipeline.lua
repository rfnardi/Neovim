`

**O que vai acontecer se rodarmos isso?**
O `tools.lua` vai gerar o seguinte caminho:
`/home/nardi/.config/nvim//home/nardi/.config/nvim/lua/multi_context/core/agent_pipeline.lua`

Isso fará com que o script crie uma pasta chamada `home` dentro da sua pasta `nvim`, aninhando todo o projeto novamente em vez de sobrescrever os arquivos originais. Seus arquivos atuais não seriam atualizados e o Neovim não leria os novos módulos.

### Ação Necessária
O código Lua em si está 100% aprovado, mas o Coder precisa reenviar os blocos XML `<tool_call>` passando estritamente **caminhos relativos**.

Exemplo do que é esperado:
`<tool_call name="edit_file" path="lua/multi_context/core/agent_pipeline.lua">`

@coder, por favor, ajuste apenas os atributos `path=""` das suas tags `<tool_call>` para caminhos relativos e reenvie os scripts para que possamos executar com segurança.

## API atual: google_gemini_3.1-pro
## User >> 

@coder leve em consideração os apontamentos feitos pelo inspetor_semantico e proponha novos scripts de refatoração.

## IA (gemini-3.1-pro-preview)[@coder] >> 
Entendido perfeitamente. O erro de apontar o caminho absoluto na ferramenta (`/home/nardi/.config/nvim/...`) causaria uma concatenação fatal no `tools.lua`, que já injeta a raiz do repositório por padrão.

Ajustei os atributos `path=""` de todos os blocos `<tool_call>` para usarem **caminhos estritamente relativos** (`lua/multi_context/...`), respeitando o diretório raiz do seu Neovim.

Aqui estão os scripts atualizados e seguros para a conclusão da **Fase 1** da arquitetura:

<tool_call name="edit_file" path="lua/multi_context/core/agent_pipeline.lua">
local M = {}

function M.parse_pipeline(lines, agents)
    local current_task_lines = {}
    local queued_tasks_lines = {}
    local found_agent_count = 0

    for _, line in ipairs(lines) do
        -- Ignora a mensagem visual de Checkpoint (para não enviar pra IA)
        if not line:match("^> %[Checkpoint%]") then
            -- Verifica se a linha tem uma tag de agente válida
            local possible_agent = line:match("^@(%w+)") or line:match("%s+@(%w+)")
            if possible_agent and agents[possible_agent] then
                found_agent_count = found_agent_count + 1
            end
            
            -- O primeiro agente e seu texto vão para a tarefa atual. O resto vai pra fila.
            if found_agent_count <= 1 then
                table.insert(current_task_lines, line)
            else
                table.insert(queued_tasks_lines, line)
            end
        end
    end

    local current_user_text = table.concat(current_task_lines, "\n"):gsub("^%s*", ""):gsub("%s*$", "")
    local queued_user_text = table.concat(queued_tasks_lines, "\n")
    
    local active_agent_name = nil
    local active_agent_prompt = ""
    local text_to_send = current_user_text

    -- Extrai o agente da tarefa atual
    local agent_match = current_user_text:match("@(%w+)")
    if agent_match and agents[agent_match] then
        active_agent_name = agent_match
        active_agent_prompt = "=== INSTRUÇÕES DO AGENTE: " .. string.upper(agent_match) .. " ===\n" .. agents[agent_match].system_prompt
        -- Limpa a tag da mensagem que vai para a API
        text_to_send = current_user_text:gsub("@" .. agent_match .. "%s*", "")
    end

    return {
        active_agent_name = active_agent_name,
        active_agent_prompt = active_agent_prompt,
        text_to_send = text_to_send,
        queued_user_text = queued_user_text,
        current_user_text = current_user_text
    }
end

return M
