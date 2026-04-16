# MultiContext AI - Plugin Neovim

## Visão Geral
MultiContext AI é um plugin para Neovim que integra assistentes de IA com capacidades autônomas nativas (estilo Claude Code/Devin). O plugin permite interação com múltiplos agentes especializados através de uma interface de chat, com acesso direto ao sistema de arquivos, execução de terminal, loops autônomos de raciocínio (ReAct) e gerenciamento ativo de janela de contexto.

## Arquitetura Técnica

### Tecnologias Principais
- **Linguagem**: Lua (integração nativa com Neovim)
- **Framework de Testes**: `plenary.nvim` (busted)
- **Operações Assíncronas**: `vim.fn.jobstart` (HTTP não-bloqueante)
- **Processamento de XML**: Parser funcional tolerante a falhas (substituiu Regex frágil)

### Estrutura de Diretórios Atualizada
```text
lua/multi_context/
├── init.lua              # Orquestrador principal de UI e integrações
├── config.lua            # Configurações (mesclagem profunda) e gestão de I/O (stdpath)
├── agents.lua            # Gerenciamento de agentes e manual de ferramentas dinâmico
├── api_client.lua        # Cliente HTTP, fila de APIs e fallback
├── api_handlers.lua      # Manipuladores de requisição e Garbage Collector de temp files
├── prompt_parser.lua     # Parser de intenções do usuário (@agentes e flags)
├── tool_parser.lua       # Extrator funcional e sanitizador de tags XML/JSON
├── tool_runner.lua       # Roteador de segurança e executor de ferramentas
├── react_loop.lua        # Gerenciador de estado de sessão e Circuit Breaker
├── api_selector.lua      # UI de seleção de API
├── commands.lua          # Rotas de comandos do Neovim
├── conversation.lua      # Motor de reconstrução de histórico
├── context_builders.lua  # Extratores de contexto com proteção contra OOM (>100kb/Binários)
├── queue_editor.lua      # Editor visual de fila de tarefas
├── tools.lua             # Ferramentas do sistema (leitura, edição, bash, git grep, LSP)
├── utils.lua             # Utilitários e exportação isolada de Workspace (.mctx_chats)
├── ui/
│   ├── scroller.lua      # Smart Auto-Scroll silencioso para leitura concorrente
│   ├── popup.lua         # Lógica da janela flutuante e titlebars dinâmicas
│   └── highlights.lua    # Highlights sintáticos customizados
└── tests/                # Suíte de testes automatizados (TDD/Plenary)
```

## Funcionalidades e Capacidades Implementadas

### 1. Sistema de Agentes e Identidade Persistente
- **Agentes**: Documentador, Arquiteto, Coder, Inspetor Sintático/Semântico, Engenheiro de Prompt, QA, etc.
- **Identidade (`@agente`)**: O plugin memoriza o agente ativo, mantendo a persona durante todo o ciclo de raciocínio das ferramentas até que seja resetado (`@reset`).

### 2. Loop Autônomo e Raciocínio (ReAct)
- Suporte ao modo manual (com aprovação de I/O) ou **Modo Autônomo Granular (`--auto`)**.
- A IA pode encadear múltiplas ferramentas (ler -> analisar -> editar -> testar bash) em background sem poluir o chat.
- Limite de segurança de 15 iterações (Circuit Breaker isolado).

### 3. Gestão de Contexto e Compressão (Engenharia de Prompt)
- O agente *Engenheiro de Prompt* possui a ferramenta exclusiva `rewrite_chat_buffer`.
- **Garbage Collection de Tokens**: Capacidade de limpar o buffer atual, jogando fora stack traces mortos e resumindo o progresso.
- **Segurança**: Antes de qualquer compressão destrutiva, um backup é feito em memória (`:ContextUndo`).

### 4. Integração com Sistema e Workspace
- Exportação de chats (`.mctx`) organizados automaticamente na raiz do repositório Git atual (`.mctx_chats/`).
- Proteção OOM: Ignora automaticamente leitura de binários e arquivos > 100KB.
- Limpeza automática (`VimLeavePre`) de payloads temporários gigantes gerados pelo `curl`.

### 5. Memória de Longo Prazo e Prompt Caching ⚡
- Leitura silenciosa deste arquivo (`CONTEXT.md`) injetada no `system_prompt` para manter a equipe de IA ciente do escopo global.
- **Otimização de Custos**: Implementação nativa de Prompt Caching. A base de conhecimento do projeto e o manual de ferramentas são cacheados reduzindo custos em até 90%. O plugin exibe notificações visuais (UI) da economia.

### 6. Integração LSP — Diagnósticos em Tempo Real 🆕
- Ferramenta `get_diagnostics` disponível no loop autônomo via `vim.diagnostic.get()`.
- Permite autocorreção sintática em tempo real. Truncamento agressivo: 50 diagnósticos / 3KB máximo.
- Sincronização com LSP via `vim.wait` condicional.

### 7. Smart Auto-Scroll Silencioso (Leitura Concorrente) 🆕
- O usuário pode rolar a tela para ler o histórico enquanto a IA digita código novo.
- **Sem Sequestro de Cursor**: O rastreador pausa o *auto-scroll* se o usuário mover o cursor para cima e retoma automaticamente se ele voltar ao fim do buffer.
- Monitoramento ativado estritamente durante o streaming HTTP (alta performance).

## Decisões Técnicas Críticas (Registro para Agentes)
1. **Desacoplamento de UI e Lógica (Fase 13)**: O monolito `init.lua` foi quebrado em funções puras (`tool_parser`, `prompt_parser`) e gerentes de estado (`react_loop`), permitindo testes unitários automatizados de 100% da lógica textual sem renderizar o editor.
2. **Ciclo de Vida do Scroller**: O `ui/scroller.lua` usa `CursorMoved` apenas enquanto `is_streaming == true`. Assim que a IA finaliza a resposta, o Autocmd é destruído preventivamente para economizar ciclos de CPU do Neovim. O feedback da pausa do scroll não polui o título da janela (UX limpa).
3. **Parser de Ferramentas Funcional**: O código lida iterativamente com JSON acidental dentro do XML, limpa crases Markdown e fecha tags esquecidas através do `tool_parser.lua`.
4. **Deep Merge de Configurações**: Uso de `vim.tbl_deep_extend` em `config.lua`.

---

## Estado Atual do Desenvolvimento

### ✅ Concluído (Fases 1 a 14)
- Loop autônomo ReAct, interface popup estável e isolamento de chats por projeto (Workspace Git).
- Otimização de Prompt Caching integrada aos Handlers HTTP.
- Compressão de Contexto e resgate via `:ContextUndo`.
- **Suíte de Testes Automatizada** cobrindo I/O, config, string, payload mocking, parser de regras XML e estados de Auto-Scroll.
- Integração LSP — get_diagnostics (Fase 12).
- **Refatoração Arquitetural de Módulos** (Fase 13): Desacoplamento do `init.lua`.
- **Smart Auto-Scroll Silencioso** (Fase 14): Leitura concorrente implementada.

### 🔄 Planejado / Próximos Passos
1. **Padronização DRY no `api_handlers.lua`**: Abstrair a rotina repetitiva de requests curl e arquivos temporários em um construtor HTTP genérico.
2. **Integração LSP — Fase 2 (Smart Push)**: Diagnósticos injetados automaticamente no contexto após edições no modo autônomo.
3. **Sistema de Plugins Externos**: Download de agentes predefinidos via repositórios do Github.

---
*Última atualização: 2026-04-16 - Fases 13 e 14 concluídas (Refatoração de Módulos e Smart Auto-Scroll).*
