#!/bin/bash

echo "Instalando fechamento implícito de tags no parser do MultiContext..."

python3 - << 'EOF'
import os

init_path = os.path.expanduser("~/.config/nvim/lua/multi_context/init.lua")

try:
    with open(init_path, "r") as f:
        content = f.read()

    start_marker = "local is_self_closing = tag_str:match"
    end_marker = "local attrs_str, name"

    start_idx = content.find(start_marker)
    end_idx = content.find(end_marker, start_idx)

    if start_idx != -1 and end_idx != -1:
        before = content[:start_idx]
        after = content[end_idx:]
        
        new_block = r"""local is_self_closing = tag_str:match("/%s*>$")
        local close_start, close_end, inner
        if is_self_closing then
            inner = ""
            close_start = tag_end + 1
            close_end = tag_end
        else
            close_start, close_end = content_to_process:find("</tool_call%s*>", tag_end + 1)
            local next_open = content_to_process:find("<tool_call", tag_end + 1)
            
            -- MÁGICA: Se outra tag abrir antes dessa fechar, forçamos o fechamento implícito!
            if next_open and (not close_start or next_open < close_start) then
                close_start = next_open
                close_end = next_open - 1
                inner = content_to_process:sub(tag_end + 1, close_start - 1)
            elseif not close_start then 
                inner = content_to_process:sub(tag_end + 1)
                close_end = #content_to_process
            else 
                inner = content_to_process:sub(tag_end + 1, close_start - 1) 
            end
        end
        
        """
        
        with open(init_path, "w") as f:
            f.write(before + new_block + after)
        print("✅ Fechamento implícito de tags instalado com sucesso!")
    else:
        print("⚠️ Não foi possível encontrar a área de substituição.")

except Exception as e:
    print(f"❌ Erro ao modificar init.lua: {e}")
EOF

echo "Pronto! O plugin agora é à prova de encadeamento maluco."
