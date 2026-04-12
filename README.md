
# MultiContext AI - Neovim Plugin

## 📖 Visão Geral
**MultiContext AI** é um plugin nativo para Neovim que integra assistentes de IA autônomos diretamente no editor. Ele permite que desenvolvedores interajam com múltiplos agentes especializados — **Documentador**, **Arquiteto**, **Engenheiro** e **QA** — via uma interface de chat, com acesso ao sistema de arquivos, terminal e controle de versões.

> **Objetivo:** acelerar o fluxo de trabalho de desenvolvimento, automatizando tarefas repetitivas (geração de código, documentação, testes) e fornecendo suporte contextual em tempo real.

---

## 🚀 Funcionalidades

| ✅ | Funcionalidade |
|---|----------------|
| **Agentes Especializados** | Documentador, Arquiteto, Engenheiro, QA |
| **Chat Inteligente** | Popup nativo com realce de sintaxe por papel |
| **Suporte a Múltiplos Contextos** | Arquivo, seleção, pasta, repositório Git |
| **Ferramentas Autônomas** | `list_files`, `read_file`, `edit_file`, `replace_lines`, `search_code`, `run_shell` |
| **Memória de Longo Prazo** | `CONTEXT.md` persiste decisões e progresso |
| **Segurança Integrada** | Validação de comandos críticos, limites de iteração, confirmações manuais |
| **Persistência de Conversa** | Histórico salvo entre sessões |
| **Extensibilidade** | Arquitetura modular, futuro suporte a plugins de agentes |
| **Assíncrono e Leve** | Operações de IA via HTTP não bloqueantes (libuv) |

---

## 📦 Instalação

### 1. Usando **vim-plug**
```vim
Plug 'seu-usuario/multi_context'
```

### 2. Usando **packer.nvim**
```lua
use { 'seu-usuario/multi_context', run = ':lua require("multi_context").setup()' }
```

### 3. Usando **lazy.nvim**
```lua
{
  'seu-usuario/multi_context',
  config = function()
    require('multi_context').setup()
  end,
}
```

> **Recomendação:** reinicie o Neovim após a instalação e execute `:PlugInstall` (ou o comando equivalente do seu gerenciador).

### Dependências externas
| Ferramenta | Motivo |
|------------|--------|
| `jq` | Formatação e manipulação de JSON (opcional) |
| `python3` | Algumas APIs de provedores podem precisar de scripts auxiliares |
| `curl` ou **luasocket** (incluído) | Comunicação HTTP com provedores de IA |
| `git` | Integração com repositórios Git para contexto de código |

Instale via seu gerenciador de pacotes, por exemplo:

```bash
# Debian/Ubuntu
sudo apt-get install jq python3 curl git

# macOS (Homebrew)
brew install jq python3 curl git
```

---

## ⚙️ Configuração

Crie (ou edite) `lua/multi_context/config.lua` ou configure diretamente no `init.lua`:

```lua
require('multi_context').setup({
  api_key = os.getenv('MULTICONTEXT_API_KEY'),   -- chave da API (DeepSeek, Claude, etc.)
  default_agent = 'engineer',                  -- agente padrão ao abrir o chat
  log_level = 'info',                          -- níveis: trace, debug, info, warn, error
  allowed_commands = {                         -- lista branca de comandos críticos
    'git', 'make', 'npm', 'yarn', 'cargo',
  },
  prohibited_patterns = {                      -- regexes de comandos bloqueados
    'rm%-rf', 'sudo', 'dd', 'mkfs', 'shutdown', 'reboot',
  },
})
```

### Variáveis de ambiente úteis
| Variável | Uso |
|----------|-----|
| `MULTICONTEXT_API_KEY` | Chave de API padrão (pode ser sobrescrita em `setup`) |
| `MULTICONTEXT_LOG_LEVEL` | Override do nível de log (`debug`, `info`, etc.) |
| `MULTICONTEXT_CONTEXT_PATH` | Diretório onde `CONTEXT.md` será criado (padrão: raiz do projeto) |

---

## 🎮 Uso Básico

| Atalho | Ação |
|--------|------|
| `<A-c>` | Abre o chat de contexto (usa linha ou seleção atual) |
| `<A-h>` | Alterna visibilidade do popup de chat |
| `<A-w>` | Exibe/oculta a visualização de workspace |
| `<A-f>` | Fuzzy finder de arquivos (integrado ao plugin) |
| `<A-b>` | Lista de buffers abertos |
| `<A-d>` | Abre a interface de banco de dados (`DBUI`) |

### Exemplo de fluxo rápido

1. **Inicie o chat**: pressione `<A-c>`.
2. **Selecione o agente** (ex.: `:Agent engineer` ou escreva `@engineer` no prompt).
3. **Peça ao agente**:  
   ```
   @engineer --auto implemente uma função Lua que leia todas as linhas de um buffer e retorne a contagem de linhas não vazias.
   ```
4. O agente usará `run_shell`/`edit_file` conforme necessário e retornará o código pronto.
5. **Persistência**: a conversa e as decisões são salvas automaticamente em `CONTEXT.md`.

---

## 🔐 Segurança

- **Validação de comandos**: antes de executar, o plugin verifica se o comando corresponde a padrões proibidos (`rm -rf`, `sudo`, etc.).  
- **Lista branca**: comandos permitidos podem ser configurados via `allowed_commands`.  
- **Limite de iterações**: agentes autônomos são limitados a 15 iterações por tarefa para evitar loops infinitos.  
- **Confirmação manual**: para operações de risco (ex.: remoção de arquivos), o usuário recebe um prompt de confirmação.  
- **Logs de auditoria**: todos os comandos executados são registrados em `~/.local/share/multi_context/audit.log` (pode ser desativado via `log_audit = false`).

---

## 📂 Memória de Longo Prazo – `CONTEXT.md`

- **Localização:** criado na raiz do projeto (`<project_root>/CONTEXT.md`).  
- **Formato:** Markdown estruturado em seções (`## Decisões Técnicas`, `## Progresso`, `## Issues`).  
- **Atualização automática:** após cada tarefa concluída, o agente escreve um resumo no arquivo.  
- **Reset/Export:**  
  ```vim
  :MultiContextResetContext   " Apaga o CONTEXT.md atual
  :MultiContextExportContext <caminho>   " Exporta para outro arquivo
  ```

> **Importante:** versionar `CONTEXT.md` no repositório permite rastrear decisões ao longo do tempo.

---

## 🏗️ Arquitetura Interna

```
Usuário
   │
   ▼
UI Popup (ui/popup.lua) ──► conversation.lua
   │                           │
   ▼                           ▼
api_selector.lua          tools.lua (list_files, run_shell, …)
   │                           │
   ▼                           ▼
api_client.lua ──► Provedor de IA (DeepSeek, Claude, …)
   │
   ▼
Resposta ──► conversation.lua ──► UI Popup
```

- **Módulos principais**
  - `init.lua` – ponto de entrada, registra comandos.
  - `config.lua` – leitura e validação das configurações.
  - `agents.lua` – definição e carregamento dos agentes (arquivo `agents/agents.json`).
  - `api_client.lua` – camada HTTP assíncrona (libuv).
  - `tools.lua` – wrappers seguros para operações de sistema.
  - `queue_editor.lua` – gerenciamento de fila de tarefas autônomas.
- **Assíncronismo:** todas as chamadas de rede usam `vim.loop` (`uv`) para não bloquear a UI.
- **Limite de iteração:** implementado em `queue_editor.lua` (contagem de ciclos).

---

## 🧪 Testes & Qualidade

- **Framework:** `busted` (Lua) + `luassert`.
- **Executar testes:**  
  ```bash
  busted tests/
  ```
- **CI:** GitHub Actions configurado (`.github/workflows/ci.yml`) executa lint, testes e verifica cobertura com `luacov`.
- **Lint/Format:** `stylua` para formatação e `luacheck` para lint.

---

## 🤝 Contribuição

1. Fork o repositório.
2. Crie uma branch para sua feature (`git checkout -b feature/nome`).
3. Siga o padrão de código (`stylua`, `luacheck`).
4. Escreva testes para a nova funcionalidade.
5. Abra um Pull Request descrevendo a mudança.

- **Guia completo:** veja `CONTRIBUTING.md`.
- **Código de Conduta:** `CODE_OF_CONDUCT.md`.
- **Licença:** MIT (arquivo `LICENSE` incluído).

---

## 📅 Roadmap

| Versão | Marco | Data Estimada |
|--------|-------|----------------|
| **v0.2** | Sistema de plugins para agentes | Q3 2026 |
| **v0.3** | Cache inteligente de respostas | Q4 2026 |
| **v0.4** | Integração LSP avançada | Q1 2027 |
| **v1.0** | Dashboard de status, exportação de conversas, UI web opcional | Q2 2027 |

### Métricas de desempenho
- **Latência média de resposta IA:** < 300 ms (dependendo do provedor).  
- **Uso de memória:** < 30 MiB durante conversas típicas.  

---

## 🌐 Provedores de IA Suportados

| Provedor | Modelos Disponíveis | Limites de taxa* | Parâmetros configuráveis |
|----------|---------------------|------------------|---------------------------|
| **DeepSeek Chat** | `deepseek-chat` | 60 req/min | `temperature`, `max_tokens` |
| **DeepSeek Coder** | `deepseek-coder` | 30 req/min | `temperature`, `top_p` |
| **Claude 3 Haiku** | `claude-3-haiku-20240307` | 20 req/min | `temperature`, `max_tokens` |

\*Limites dependem da conta do usuário; verifique a documentação do provedor.

- **Alternância dinâmica:**  
  ```vim
  :MultiContextSetProvider deepseek_chat
  ```

---

## 🌍 Internacionalização

O plugin está preparado para suportar múltiplos idiomas via arquivos de tradução (`lua/multi_context/i18n/*.lua`). O README está em português, mas pode ser traduzido para:

- **English** (`README.en.md`)
- **Español** (`README.es.md`)

Contribua com novas traduções adicionando um arquivo correspondente e atualizando o índice no `README.md`.

---

## 📜 Licença

Este projeto está licenciado sob a **MIT License** – veja o arquivo `LICENSE` para detalhes.

---

*Última atualização: 2026-04-12*  

