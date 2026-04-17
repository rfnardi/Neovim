-- lua/multi_context/react_loop.lua
local M = {}

M.state = {
    is_autonomous = false,
    auto_loop_count = 0,
    active_agent = nil,
    queued_tasks = nil,
    last_backup = nil,
    active_job_id = nil,
    user_aborted = false,
}

M.reset_turn = function()
    M.state.is_autonomous = false
    M.state.auto_loop_count = 0
    M.state.active_job_id = nil
    M.state.user_aborted = false
end

M.check_circuit_breaker = function()
    M.state.auto_loop_count = M.state.auto_loop_count + 1
    if M.state.auto_loop_count >= 15 then
        vim.notify("Limite de 15 loops atingido. Pausando por segurança.", vim.log.levels.WARN)
        return true
    end
    return false
end

M.abort_stream = function(is_user)
    if M.state.active_job_id then
        M.state.user_aborted = is_user or false
        pcall(vim.fn.jobstop, M.state.active_job_id)
        M.state.active_job_id = nil
    end
end

return M
