#!/bin/bash

# Cores para o output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' 

echo -e "Executando suite de validação do Modo Debug...\n"
FAILS=0

function check() {
    local msg=$1
    local condition=$2
    if eval "$condition"; then
        echo -e "${GREEN}[ PASS ]${NC} $msg"
    else
        echo -e "${RED}[ FAIL ]${NC} $msg"
        FAILS=$((FAILS+1))
    fi
}

# 1. Validação do Popup (Correção do <A-w>)
check "Lógica de prevenção de duplicação do prefixo inserida em ui/popup.lua" "grep -q 'not last_line:match' lua/multi_context/ui/popup.lua"

# 2. Validação da Função de Log
check "Função universal M.log_debug criada em utils.lua" "grep -q 'M.log_debug =' lua/multi_context/utils.lua"

# 3. Validação do Rastreamento do Gemini
check "Rastreamento de STDOUT do Gemini injetado em api_handlers.lua" "grep -q 'GEMINI STDOUT' lua/multi_context/api_handlers.lua"
check "Rastreamento de extração de chunks do Gemini injetado em api_handlers.lua" "grep -q 'GEMINI EXTRAIDO' lua/multi_context/api_handlers.lua"
check "Rastreamento de STDERR do Curl injetado em api_handlers.lua" "grep -q 'CURL STDERR' lua/multi_context/api_handlers.lua"

# 4. Validação da Interface (Renderizador no init.lua)
check "Renderizador limpou a variável msg inexistente do código antigo" "! grep -q 'vim.notify(\"MultiContext: \" .. msg' lua/multi_context/init.lua"
check "Rastreamento do chunk recebido pela UI injetado em init.lua" "grep -q 'INIT RECEBEU' lua/multi_context/init.lua"
check "Uso seguro de vim.split para renderizar linhas no init.lua" "grep -q 'vim.split(accumulated, \"\\\\n\", {plain=true})' lua/multi_context/init.lua"

echo -e "\nResultado Final:"
if [ $FAILS -eq 0 ]; then
    echo -e "${GREEN}✓ Modo Debug e correção do Workspace validados com sucesso!${NC}"
    echo -e "Próximo passo: Abra o Neovim, teste o chat e cole a saída de: cat ~/.local/share/nvim/multicontext.log"
else
    echo -e "${RED}✗ Encontrados $FAILS erro(s) durante a validação. O script anterior pode ter falhado.${NC}"
fi
