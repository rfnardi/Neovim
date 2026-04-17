# MultiContext AI - Plugin Neovim

## Visão Geral
MultiContext AI é um plugin para Neovim que integra assistentes de IA com capacidades autônomas nativas (estilo Claude Code/Devin). O plugin permite interação com múltiplos agentes especializados através de uma interface de chat, com acesso direto ao sistema de arquivos, execução de terminal, loops autônomos de raciocínio (ReAct) e gerenciamento ativo de janela de contexto.

## Arquitetura Técnica

### Tecnologias Principais
- **Linguagem**: Lua (integração nativa com Neovim)
- **Framework de Testes**: `plenary.nvim` (busted)
- **Operações Assíncronas**: `vim.fn.jobstart` e `vim.fn.jobstop` (HTTP não-bloqueante e controle de stream)
- **Processamento de XML**: Parser funcional tolerante a falhas.

### Estrutura de Diretórios Atualizada
```text
lua/multi_context/
├── init.lua              # Orquestrador principal, monitoramento live de stream e hooks
├── config.lua            # Configurações e gestão de I/O (stdpath)
├── agents.lua            # Gerenciamento de agentes e manual de ferramentas dinâmico
├── api_client.lua        # Cliente HTTP, fila de APIs, fallback e injeção de job_id
├── api_handlers.lua      # Manipuladores de requisição nativos
├── prompt_parser.lua     # Parser de intenções do usuário (@agentes e flags)
├── tool_parser.lua       # Extrator funcional e sanitizador de tags XML/JSON
├── tool_runner.lua       # Roteador de segurança, executor de ferramentas e injetor de LSP
├── react_loop.lua        # Gerenciador de estado de sessão, Circuit Breaker e Abort de Jobs
├── api_selector.lua      # UI de seleção de API
├── commands.lua          # Rotas de comandos do Neovim
├── conversation.lua      # Motor de reconstrução de histórico
├── context_builders.lua  # Extratores de contexto com proteção contra OOM (>100kb/Binários)
├── queue_editor.lua      # Editor visual de fila de tarefas
├── tools.lua             # Ferramentas do sistema (leitura, edição, bash, git grep, LSP)
├── utils.lua             # Utilitários e exportação isolada de Workspace (.mctx_chats)
├── ui/
│   ├── scroller.lua      # Smart Auto-Scroll silencioso para leitura concorrente
│   ├── popup.lua         # Lógica da janela flutuante e atalhos de emergência (<C-x>)
│   └── highlights.lua    # Highlights sintáticos customizados
└── tests/                # Suíte de testes automatizados (TDD/Plenary)
```

## Funcionalidades e Capacidades Implementadas

### 1. Sistema de Agentes e Identidade Persistente
- Identidade mantida durante todo o ciclo de raciocínio das ferramentas até o comando `@reset`.

### 2. Loop Autônomo, ReAct e Job Control 🆕
- **Controle Total de Stream**: Mapeamento do atalho `<C-x>` para o usuário assassinar instantaneamente requisições alucinadas (`vim.fn.jobstop`).
- **Auto-Halt Inteligente**: Se a IA executa uma ferramenta de mutação (`edit_file`, `replace_lines`, `run_shell`), o plugin corta a geração de texto HTTP pela raiz no exato milissegundo do fechamento da tag `</tool_call>`, economizando tokens e prevenindo a execução de múltiplos scripts quebrados em lote.
- Limite de segurança de 15 iterações (Circuit Breaker isolado).

### 3. Integração LSP — Smart Push (Fase 2 Completa) ⚡
- Graças ao *Auto-Halt*, assim que a IA altera o código, a execução dela é congelada.
- O plugin captura o diagnóstico do LSP de forma transparente (truncado para 3KB de segurança) e injeta diretamente no resultado de `SUCESSO` da ferramenta.
- A IA acorda no loop seguinte já consciente dos erros de sintaxe (Auto-LSP), permitindo refatorações orgânicas sem a IA precisar chamar ativamente a ferramenta `get_diagnostics`.

### 4. Smart Auto-Scroll Silencioso (Leitura Concorrente) 🆕
- O usuário pode rolar a tela para ler o histórico enquanto a IA digita código novo.
- **Sem Sequestro de Cursor**: A rolagem pausa ao identificar uma intenção explícita de subida (`cursor < última linha`) e retoma apenas se o cursor voltar estritamente para a última linha do buffer (`G`).
- Otimização extrema: o Autocmd do cursor existe única e exclusivamente durante o tempo de vida do request.

### 5. Gestão de Contexto, Memória e Prompt Caching
- Leitura silenciosa do `CONTEXT.md` cacheada nos servidores via Prompt Caching (DeepSeek/Anthropic/OpenAI), gerando economia brutal de tokens de input.
- Compressão do buffer e salvamento em arquivo de fallback (`:ContextUndo`).
- Exportação organizada em `.mctx_chats/`.

## Decisões Técnicas Críticas (Registro para Agentes)
1. **Desacoplamento e SRP (Fase 13)**: `init.lua` foi esvaziado de lógicas de parsing. Funções puras (`tool_parser`, `prompt_parser`) permitem validação por testes unitários sem abrir a UI.
2. **Matemática do Cursor (Fase 14)**: Para evitar condições de corrida (Race Conditions) com os próprios eventos gerados pelo Neovim, o `scroller.lua` usa rastreamento estrito direcional: pausa se o cursor sobe (`<`), retoma se está na base exata (`==`).
3. **Monitoramento Live de Regex (Fase 15)**: A leitura do texto recebido em blocos (chunk) não tenta processar a tela inteira; o Auto-Halt captura eficientemente apenas tags fechadas no bloco final do acumulador de stream.

---

## Estado Atual do Desenvolvimento

### ✅ Concluído (Fases 1 a 15)
- Arquitetura nativa, assíncrona, não-bloqueante e protegida contra falhas (Circuit breaker, OOM protection, tmp-files GC).
- Suíte de testes TDD garantindo a estabilidade de rotinas puras.
- **Desacoplamento de UI e Lógica** (Fase 13).
- **Smart Auto-Scroll sem travamentos** (Fase 14).
- **LSP Smart Push e Job Control/Abort Stream `<C-x>`** (Fase 15).

### 🔄 Planejado / Próximos Passos
1. **Padronização DRY no `api_handlers.lua`**: Abstrair a rotina repetitiva de requests curl e arquivos temporários em um construtor HTTP genérico.
2. **Sistema de Plugins Externos**: Download de agentes predefinidos via repositórios do Github.

---
*Última atualização: 2026-04-17 - Fases 13, 14 e 15 concluídas (Refatoração de Módulos, Auto-Scroll e Smart Push/Job Control).*
