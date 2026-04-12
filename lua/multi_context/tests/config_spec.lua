local config = require('multi_context.config')

describe("Config Module:", function()
    it("Deve carregar as opções default corretamente", function()
        -- Reseta a config
        config.options = vim.deepcopy(config.defaults)
        assert.are.same("Nardi", config.options.user_name)
    end)

    it("Deve mesclar opções do usuário usando setup() sem perder os defaults", function()
        config.options = vim.deepcopy(config.defaults)
        
        config.setup({
            user_name = "NovoUsuario",
            appearance = { width = 0.9 }
        })
        
        -- Alterou o que foi pedido
        assert.are.same("NovoUsuario", config.options.user_name)
        assert.are.same(0.9, config.options.appearance.width)
        
        -- Manteve o que NÃO foi pedido (Deep Merge)
        assert.are.same("rounded", config.options.appearance.border)
    end)
end)

describe("Config Module (Manipulacao de Arquivo JSON):", function()
    local config = require('multi_context.config')

    it("Deve ler e alterar APIs usando um JSON em disco", function()
        local tmp_json = os.tmpname()
        
        -- Simulando o arquivo JSON criado pelo usuario
        local mock_cfg = {
            default_api = "api_A",
            apis = {
                { name = "api_A" },
                { name = "api_B" }
            }
        }
        
        local f = io.open(tmp_json, "w")
        f:write(vim.fn.json_encode(mock_cfg))
        f:close()
        
        -- Força o plugin a olhar para o nosso arquivo falso
        config.options.config_path = tmp_json
        
        -- Testa extração de nomes
        local names = config.get_api_names()
        assert.are.same({"api_A", "api_B"}, names)
        
        -- Testa buscar a default atual
        assert.are.same("api_A", config.get_current_api())
        
        -- Testa trocar a API via código
        config.set_selected_api("api_B")
        assert.are.same("api_B", config.get_current_api())
        
        os.remove(tmp_json)
    end)
end)
