-- lua/multi_context/tests/scroller_spec.lua
local scroller = require('multi_context.ui.scroller')

describe("Scroller Module (Smart Auto-Scroll):", function()
    it("Deve ativar streaming e seguir por padrao", function()
        scroller.start_streaming(1, nil)
        assert.is_true(scroller.state.is_streaming)
        assert.is_true(scroller.state.is_following)
    end)

    it("Deve desligar streaming ao solicitar", function()
        scroller.stop_streaming(1)
        assert.is_false(scroller.state.is_streaming)
    end)
end)
