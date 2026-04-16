-- lua/multi_context/react_loop.lua
local M = {}

M.state = {
    is_autonomous = false,
    auto_loop_count = 0,
    active_agent = nil,
    queued_tasks = nil,
    last_backup = nil,
}

M.reset_turn = function()
    M.state.is_autonomous = false
    M.state.auto_loop_count = 0
end

M.check_circuit_breaker = function()
    M.state.auto_loop_count = M.state.auto_loop_count + 1
    if M.state.auto_loop_count >= 15 then
        vim.notify("Limite de 15 loops atingido. Pausando por segurança.", vim.log.levels.WARN)
        return true -- Sinaliza que deve interromper o turno
    end
    return false -- Pode continuar rodando ferramentas
end

return M
