# MultiContext AI - Plugin Neovim

## Visão Geral
MultiContext AI é um plugin para Neovim que integra assistentes de IA com capacidades autônomas diretamente no editor. O plugin permite que desenvolvedores interajam com múltiplos agentes especializados (documentador, arquiteto, engenheiro, QA) através de uma interface de chat, com acesso direto ao sistema de arquivos e terminal.

## Arquitetura Técnica

### Tecnologias Principais
- **Linguagem**: Lua (para integração nativa com Neovim)
- **APIs de IA Suportadas**: DeepSeek Chat, DeepSeek Coder, Claude 3 Haiku
- **Interface**: Popup nativo do Neovim com bordas personalizáveis
- **Gerenciamento de Plugins**: vim-plug

### Estrutura de Diretórios
```
lua/multi_context/
├── init.lua              # Módulo principal e ponto de entrada
├── config.lua            # Configurações e gerenciamento de APIs
├── agents.lua            # Gerenciamento de agentes especializados
├── api_client.lua        # Cliente HTTP para APIs de IA
├── api_handlers.lua      # Manipuladores específicos de APIs
├── api_selector.lua      # Seleção de API
├── commands.lua          # Comandos do usuário
├── conversation.lua      # Gerenciamento de conversação
├── context_builders.lua  # Construtores de contexto
├── queue_editor.lua      # Editor de fila de tarefas
├── tools.lua             # Ferramentas do sistema (arquivos, terminal)
├── utils.lua             # Utilitários
├── ui/
│   ├── popup.lua         # Interface de popup
│   └── highlights.lua    # Realce de sintaxe
└── agents/
    └── agents.json       # Definições dos agentes especializados
```

## Funcionalidades Implementadas

### 1. Sistema de Agentes Especializados
- **Documentador**: Cria e mantém documentação técnica
- **Arquiteto**: Projeta sistemas e toma decisões técnicas
- **Engenheiro**: Implementa código e corrige bugs
- **QA**: Testa software e valida qualidade

### 2. Interface de Chat Inteligente
- Popup com realce de sintaxe para diferentes papéis
- Suporte a múltiplos contextos (arquivo, seleção, pasta, repositório)
- Histórico de conversação persistente
- Folds automáticos para organização

### 3. Ferramentas Autônomas
- **list_files**: Lista arquivos do projeto
- **read_file**: Lê conteúdo de arquivos
- **edit_file**: Sobrescreve arquivos completos
- **replace_lines**: Substitui blocos de código específicos
- **search_code**: Busca texto no repositório
- **run_shell**: Executa comandos no terminal

### 4. Sistema de Memória (CONTEXT.md)
- Memória de longo prazo do projeto
- Atualização automática após conclusão de tarefas
- Resumo de decisões técnicas e progresso

### 5. Recursos de Segurança
- Validação de comandos perigosos (rm -rf, sudo, etc.)
- Limite de loops autônomos (15 iterações)
- Confirmação manual para operações críticas
- Sistema de checkpoint para filas de tarefas

## Configuração

### Arquivos de Configuração
1. **init.vim**: Configuração principal do plugin e atalhos
2. **context_apis.json**: Definição das APIs de IA disponíveis
3. **api_keys.json**: Chaves de API (não versionado)
4. **agents.json**: Definições dos agentes especializados

### Atalhos Principais
- `<A-c>`: Abre chat de contexto (seleção ou linha atual)
- `<A-h>`: Alterna popup de chat
- `<A-w>`: Alterna visualização de workspace
- `<A-f>`: Fuzzy finder de arquivos
- `<A-b>`: Lista de buffers
- `<A-d>`: Interface de banco de dados (DBUI)

## Estado Atual do Desenvolvimento

### ✅ Concluído
- [x] Sistema básico de chat com APIs de IA
- [x] Implementação de múltiplos agentes especializados
- [x] Ferramentas de sistema (arquivos, terminal)
- [x] Interface de popup com realce de sintaxe
- [x] Sistema de memória CONTEXT.md
- [x] Mecanismos de segurança
- [x] Comandos para diferentes contextos (arquivo, pasta, git)
- [x] Integração com workspace (.mctx files)

### 🔄 Em Desenvolvimento/Planejado
- [ ] Sistema de plugins para agentes
- [ ] Cache inteligente de respostas
- [ ] Integração com mais APIs de IA
- [ ] Sistema de templates para agentes
- [ ] Dashboard de status do projeto
- [ ] Exportação de conversações em formatos diversos
- [ ] Suporte a múltiplos workspaces simultâneos

## Decisões Técnicas

### 1. Arquitetura Modular
O plugin foi projetado com módulos independentes para facilitar manutenção e extensão. Cada responsabilidade está isolada em seu próprio arquivo Lua.

### 2. Sistema de Agentes
A abordagem de agentes especializados permite que diferentes aspectos do desenvolvimento sejam tratados por "especialistas" virtuais, melhorando a qualidade das interações.

### 3. Segurança First
Implementação robusta de segurança com validação de comandos, limites de execução e confirmações manuais para operações perigosas.

### 4. Integração Nativa
Uso extensivo das APIs nativas do Neovim (nvim_buf_*, nvim_win_*) para melhor performance e integração.

## Próximos Passos

### Prioridade Alta
1. **Refatoração do Código**: Consolidar módulos redundantes e melhorar coesão
2. **Testes Unitários**: Implementar suite de testes para funcionalidades críticas
3. **Documentação Completa**: Criar documentação detalhada para usuários e desenvolvedores

### Prioridade Média
1. **Sistema de Plugins**: Permitir que usuários criem seus próprios agentes
2. **Cache de Contexto**: Implementar cache para respostas frequentes
3. **Integração com LSP**: Melhor integração com Language Server Protocol

### Prioridade Baixa
1. **Interface Web**: Versão web do chat para colaboração remota
2. **Analytics**: Coleta anônima de métricas de uso
3. **Marketplace**: Repositório de agentes e templates da comunidade

## Notas de Desenvolvimento

### Dependências Externas
- **vim-plug**: Gerenciador de plugins
- **jq**: Para formatação de JSON (opcional)
- **Python 3**: Para alguns provedores (configurável)

### Compatibilidade
- Neovim 0.8+
- Sistemas Unix-like (Linux, macOS)
- Testado principalmente no Fish shell, mas compatível com Bash/Zsh

### Performance
O plugin foi otimizado para operações assíncronas e uso mínimo de recursos. As operações de IA são feitas via HTTP assíncrono para não bloquear o editor.

---

*Última atualização: $(date +%Y-%m-%d) - Início do projeto*

