#!/bin/fish
#DESC: coleta informações gerais do sistema e insere um prompt inicial

echo "Aqui está um panorama do meu projeto. Faça uma análise inicial e organize um plano de refatoração na estratégia TDD para incrementar a modularidade do sistema."

echo '====================================' 
echo "Árvore de arquivos:" 

tree -I '.git|node_modules|venv|__pycache__|.mctx_chats'

echo '====================================' 
echo ""

echo "Conteúdo dos Arquivos python do Projeto:"

for f in (find . -type f -not -path "*/\.git/*" -not -path "*/\.mctx_chats/*" -not -name "*.pyc" -name "*.py")
	echo "-------------------"$f"-------------------" 
	cat $f 
end

