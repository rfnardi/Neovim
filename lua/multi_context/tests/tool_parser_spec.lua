-- lua/multi_context/tests/tool_parser_spec.lua
local tool_parser = require('multi_context.tool_parser')

describe("Tool Parser Module:", function()
    it("Deve sanitizar tags de fechamento corrompidas", function()
        local xml_sujo = "<tool_call name='run_shell'>echo 1</arg_value>tool_call>"
        local xml_limpo = tool_parser.sanitize_payload(xml_sujo)
        assert.truthy(xml_limpo:match("</tool_call>"))
        assert.falsy(xml_limpo:match("</arg_value>tool_call>"))
    end)

    it("Deve converter alucinações de tag direta em tool_call padrão", function()
        local xml_sujo = "<run_shell>ls -la</run_shell>"
        local xml_limpo = tool_parser.sanitize_payload(xml_sujo)
        assert.truthy(xml_limpo:match('<tool_call name="run_shell">'))
    end)

    it("Deve remover lixo interno (crases markdown e tags órfãs)", function()
        local inner_sujo = "```bash\n<content>echo 'oi'</content>\n```"
        local inner_limpo = tool_parser.clean_inner_content(inner_sujo, "run_shell")
        assert.are.same("echo 'oi'", inner_limpo)
    end)

    it("Deve extrair a próxima ferramenta corretamente", function()
        local payload = 'Texto antes <tool_call name="read_file" path="main.lua">local x = 1</tool_call> Texto depois'
        local parsed = tool_parser.parse_next_tool(payload, 1)
        
        assert.is_false(parsed.is_invalid)
        assert.are.same("Texto antes ", parsed.text_before)
        assert.are.same("read_file", parsed.name)
        assert.are.same("main.lua", parsed.path)
        assert.are.same("local x = 1", parsed.inner)
    end)
end)
