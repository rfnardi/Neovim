#!/bin/bash


cat << 'EOF' > CONTEXT.md
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
├── init.lua              # Módulo principal, motor ReAct, parser de ferramentas e comandos
├── config.lua            # Configurações (mesclagem profunda) e gestão de I/O (stdpath)
├── agents.lua            # Gerenciamento de agentes e manual de ferramentas dinâmico
├── api_client.lua        # Cliente HTTP, fila de APIs e fallback
├── api_handlers.lua      # Manipuladores de requisição e Garbage Collector de temp files
├── api_selector.lua      # UI de seleção de API
├── commands.lua          # Rotas de comandos do Neovim
├── conversation.lua      # Motor de reconstrução de histórico
├── context_builders.lua  # Extratores de contexto com proteção contra OOM (>100kb/Binários)
├── queue_editor.lua      # Editor visual de fila de tarefas
├── tools.lua             # Ferramentas do sistema (leitura, edição cirúrgica, bash, git grep)
├── utils.lua             # Utilitários e exportação isolada de Workspace (.mctx_chats)
├── ui/                   # Interface gráfica e Highlights customizados
└── tests/                # Suíte de testes automatizados (TDD/Plenary)
```

## Funcionalidades e Capacidades Implementadas

### 1. Sistema de Agentes e Identidade Persistente
- **Agentes**: Documentador, Arquiteto, Coder, Inspetor Sintático/Semântico, Engenheiro de Prompt, QA, etc.
- **Identidade (`@agente`)**: O plugin memoriza o agente ativo, mantendo a persona durante todo o ciclo de raciocínio das ferramentas até que seja resetado (`@reset`).

### 2. Loop Autônomo e Raciocínio (ReAct)
- Suporte ao modo manual (com aprovação de I/O) ou **Modo Autônomo Granular (`--auto`)**.
- A IA pode encadear múltiplas ferramentas (ler -> analisar -> editar -> testar bash) em background sem poluir o chat.
- Limite de segurança de 15 iterações (Circuit Breaker).

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
- **Otimização de Custos**: Implementação nativa de Prompt Caching (Anthropic, OpenAI e DeepSeek). A base de conhecimento do projeto e o manual de ferramentas são cacheados na memória dos servidores da API, reduzindo custos em até 90% e acelerando o *Time-to-First-Token*. O plugin exibe notificações visuais (UI) da economia em milhares de tokens no Neovim.

## Decisões Técnicas Críticas (Registro para Agentes)
1. **Parser de Ferramentas Funcional**: O código abandonou a extração de `<tool_call>` baseada em Regex puro. O novo parser iterativo lida com JSON acidental dentro do XML, limpa crases Markdown e fecha tags esquecidas.
2. **Estrutura de Histórico Estrita**: O envio de prompts agora separa rigorosamente os papéis (`user` -> `assistant`) em arrays JSON, abandonando a concatenação de texto bruto. Essa formatação foi crucial para garantir a compatibilidade do prefixo exato exigido pelo Prompt Caching.
3. **Deep Merge de Configurações**: O `config.lua` usa `vim.tbl_deep_extend` para mesclar opções do usuário sem sobrescrever as predefinições de UI.

## Estado Atual do Desenvolvimento

### ✅ Concluído (Fases 1 a 11)
- Loop autônomo ReAct e interface popup estável.
- Isolamento de chats por projeto (Workspace Git).
- Compressão de Contexto e `:ContextUndo`.
- Otimização de Prompt Caching integrada aos Handlers HTTP.
- **Suíte de Testes Automatizada** (100% de cobertura nos módulos de I/O, config, string e payload mocking).

### 🔄 Planejado / Próximos Passos
1. **Integração LSP (Foco Atual)**: Criar uma ferramenta para o agente ler diretamente os diagnósticos de erro da linha/buffer atual do Neovim (via `vim.diagnostic.get()`), permitindo autocorreção sintática em tempo real no loop autônomo.
2. **Sistema de Plugins Externos**: Permitir que usuários definam e baixem agentes predefinidos via repositórios do Github, estendendo o arquivo `agents.json`.

---
*Última atualização: 2026-04-13 - Fase 11 (Prompt Caching concluído).*
EOF
