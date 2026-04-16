-- lua/multi_context/tests/react_loop_spec.lua
local react_loop = require('multi_context.react_loop')

describe("ReAct Loop Module:", function()
    before_each(function()
        react_loop.reset_turn()
    end)

    it("Deve resetar o estado corretamente", function()
        react_loop.state.is_autonomous = true
        react_loop.state.auto_loop_count = 5
        
        react_loop.reset_turn()
        
        assert.is_false(react_loop.state.is_autonomous)
        assert.are.same(0, react_loop.state.auto_loop_count)
    end)

    it("Deve interromper a execução quando atingir 15 loops (Circuit Breaker)", function()
        -- Simulando 14 iterações aprovadas
        for i = 1, 14 do
            local abort = react_loop.check_circuit_breaker()
            assert.is_false(abort)
        end
        
        -- A iteração 15 deve abortar
        local final_abort = react_loop.check_circuit_breaker()
        assert.is_true(final_abort)
        assert.are.same(15, react_loop.state.auto_loop_count)
    end)
end)
