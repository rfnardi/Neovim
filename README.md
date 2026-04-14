# MultiContext AI - Neovim Plugin

## 📖 Visão Geral
**MultiContext AI** é um plugin nativo para Neovim que integra assistentes de IA **autônomos** diretamente no editor (inspirado no paradigma do *Claude Code* e *Devin*). Ele permite que desenvolvedores interajam com múltiplos agentes especializados — **Arquiteto**, **Coder**, **Engenheiro de Prompt** e **Inspetor** — via uma interface de chat nativa, concedendo a eles acesso direto ao sistema de arquivos, terminal, análise de código e leitura de diagnósticos LSP.

> **Objetivo:** Acelerar o fluxo de trabalho de desenvolvimento automatizando tarefas repetitivas e complexas. A IA não apenas "sugere" código, ela navega, lê, analisa erros do LSP, edita arquivos em background e testa, usando um motor de raciocínio ReAct.

---

## 🚀 Funcionalidades

| ✅ | Funcionalidade | Descrição |
|:---:|---|---|
| 🤖 | **Agentes Especializados** | Personas persistentes (`@arquiteto`, `@coder`) com instruções em JSON. |
| 🔄 | **Loop Autônomo (ReAct)** | Agentes encadeiam ações sozinhos (flag `--auto`) com limite de segurança de 15 iterações. |
| ⚡ | **Prompt Caching Nativo** | Cache de contexto para Anthropic, OpenAI e DeepSeek. Economiza até 90% dos tokens! |
| 🔍 | **Integração LSP** | A IA lê erros/warnings do Neovim em tempo real via `vim.diagnostic`. |
| 🧠 | **Memória de Longo Prazo** | O arquivo `CONTEXT.md` atualiza e persiste as decisões de arquitetura do projeto. |
| 🛠️ | **Ferramentas de Sistema** | `read_file`, `edit_file`, `replace_lines`, `search_code`, `run_shell`, `get_diagnostics` |
| 🗑️ | **Garbage Collection Ativa** | Ferramenta `rewrite_chat_buffer` destrói logs velhos e resume o chat para salvar memória. |
| 🛡️ | **Segurança Integrada** | Validação de comandos Bash críticos, confirmações manuais e isolamento de parser XML. |
| 📂 | **Isolamento de Workspaces** | Histórico salvo automaticamente em `.mctx_chats/` na raiz do repositório Git. |
| 🚀 | **Assíncrono e Leve** | Operações HTTP via `jobstart` não bloqueantes, sem travar a interface do Neovim. |

---

## 📦 Instalação

### Requisitos
- **Neovim 0.8+** (Necessário para a API de diagnósticos `vim.diagnostic` e janelas flutuantes).
- `curl` instalado no sistema (para as requisições HTTP).
- `git` e `tree` (para extração de contexto de repositório e busca nativa).

### 1. Usando **lazy.nvim** (Recomendado)
```lua
{
  'seu-usuario/multi_context.nvim',
  config = function()
    require('multi_context').setup({
      user_name = "SeuNome",
      appearance = { border = "rounded", width = 0.7, height = 0.7 }
    })
  end,
}
```

### 2. Usando **packer.nvim**
```lua
use { 'seu-usuario/multi_context.nvim', config = function() require("multi_context").setup() end }
```

### 3. Usando **vim-plug**
```vim
Plug 'seu-usuario/multi_context.nvim'
```

---

## ⚙️ Configuração

O MultiContext divide as configurações entre aparência (Lua) e credenciais de APIs (JSON).

**1. Configuração visual (`init.lua`):**
```lua
require('multi_context').setup({
  user_name = "Nardi",                           -- Seu nome no chat
  config_path = "~/.config/nvim/context_apis.json",  -- Caminho do JSON de APIs
  api_keys_path = "~/.config/nvim/api_keys.json",    -- Caminho seguro das chaves
})
```

**2. Gerenciamento de Chaves (`api_keys.json`):**
Mantenha este arquivo seguro. Ele vincula o nome da API à sua chave real.
```json
{
  "OpenAI": "sk-proj-...",
  "Claude": "sk-ant-...",
  "DeepSeek": "sk-..."
}
```

**3. Gerenciamento de Provedores (`context_apis.json`):**
Use o comando `:ContextApis` dentro do Neovim para abrir o menu flutuante e trocar de IA rapidamente.

---

## 🎮 Uso Básico e Comandos

O plugin expõe vários comandos para iniciar o chat já com o contexto injetado:

| Comando | Ação |
|---|---|
| `:ContextChatFull` | Abre o chat de IA vazio ou retoma o workspace atual. |
| `:'<,'>Context` | Envia a seleção visual de código para o chat. |
| `:ContextFolder` | Inicia com a leitura de todos os arquivos da pasta atual. |
| `:ContextRepo` | Inicia fazendo parsing de todo o projeto Git rastreado. |
| `:ContextGit` | Inicia com as alterações não commitadas (`git diff`). |
| `:ContextBuffers`| Inicia com o texto de todos os buffers abertos no momento. |
| `:ContextTree` | Inicia desenhando a árvore de diretórios no prompt. |
| `:ContextUndo` | Restaura o chat após uma compressão de histórico malsucedida da IA. |

### Exemplo de Fluxo Autônomo

1. Abra o chat com `:ContextChatFull`.
2. Chame o agente especialista e adicione a tag `--auto`:
   ```text
   ## Nardi >> @coder --auto verifique os erros do LSP neste arquivo e corrija a função de login.
   ```
3. A IA usará o `get_diagnostics` para ver os erros, o `replace_lines` para consertar o código, e devolverá a resposta final. Tudo isso acontecerá no background.

---

## 🔐 Segurança e Arquitetura do ReAct

Para evitar desastres de código e alucinações perigosas, o plugin possui múltiplas camadas de defesa:
- **Blindagem XML**: As tags enviadas pela IA (`<tool_call>`) são validadas através de um parser iterativo seguro (imune a *Dogfooding* e escapes markdown).
- **Lista Branca (Whitelist)**: Comandos do terminal são interceptados. Padrões destrutivos como `rm -rf`, `mkfs`, `chown` e `sudo` exigem confirmação manual rígida (`[Y/n]`) na UI, mesmo no modo `--auto`.
- **Circuit Breaker**: Agentes autônomos são interrompidos forçadamente na 15ª iteração para evitar loops infinitos e estouro de faturamento da API.
- **Proteção OOM**: Binários e arquivos maiores que 100KB são silenciados das ferramentas de leitura automaticamente para não estourar a memória RAM e o limite de tokens.

---

## 📂 Memória de Longo Prazo – `CONTEXT.md`

O plugin utiliza a raiz do seu projeto como "Cérebro" compartilhado pela equipe de agentes:
- **Localização:** Criado automaticamente na raiz do Git (`<project_root>/CONTEXT.md`).  
- **Auto-Atualização:** Ao final de *features* ou refatorações, o `@arquiteto` atualiza este arquivo para não esquecer as regras no futuro.
- **Prompt Caching:** Este arquivo é lido de forma invisível e enviado nos headers de sistema. Usando *Anthropic* ou *DeepSeek*, o conteúdo inteiro é cacheado no servidor, acelerando respostas em 200%.

---

## 🏗️ Arquitetura Interna

```text
Usuário
   │ (Chat / Workspace .mctx)
   ▼
init.lua (Motor ReAct & Parser XML) ──► conversation.lua (Gerencia o Buffer)
   │
   ▼
api_client.lua  ──►  api_handlers.lua (OpenAI, Gemini, Anthropic)
   │                       │ (Tratamento de Stream, JSON, Temp Files GC)
   ▼                       ▼
tools.lua ◄────────── Resposta (tool_call)
(list_files, read_file, get_diagnostics, run_shell...)
```

- **Assíncronismo:** Chamadas baseadas em `vim.fn.jobstart` (libuv) com *temp files* limpos em Garbage Collection na saída do buffer (`VimLeavePre`).
- **Configuração Profunda:** Extensão via `vim.tbl_deep_extend`.

---

## 🧪 Testes & Qualidade

- **Framework:** `plenary.nvim` (busted wrapper) + `luassert`.
- **Executar testes:**  
  ```bash
  make test  # Ou rode arquivos via PlenaryBustedFile
  ```
- Todas as funções de I/O, *parsers* e handlers de API contêm testes automatizados que realizam Mock da API do Neovim.

---

## 🌐 Provedores de IA Suportados Nativamente

| Provedor | Modelos recomendados | Prompt Caching | Suporte a Tool/ReAct |
|----------|----------------------|:---:|:---:|
| **Anthropic** | `claude-3-5-sonnet` | ✅ | ✅ |
| **OpenAI** | `gpt-4o`, `o1` | ✅ | ✅ |
| **DeepSeek** | `deepseek-coder` | ✅ | ✅ |
| **Google** | `gemini-3.1-pro` | ❌ | ✅ |
| **Cloudflare** | Modelos Worker AI | ❌ | ⚠️ (Básico) |

---

## 📅 Roadmap

| Versão | Marco | Status |
|--------|-------|:---:|
| **v0.1** | Interface de Popup, Parsing Básico e Histórico | ✅ |
| **v0.2** | Sistema de Agentes e Ferramentas I/O (File/Shell) | ✅ |
| **v0.3** | Motor Autônomo ReAct e Prompt Caching Nativo | ✅ |
| **v0.4** | Integração LSP (Autocorreção Inteligente) | ✅ |
| **v1.0** | Download e compartilhamento de Agentes Externos via GitHub | 🔄 Planejado |

---

## 🤝 Contribuição

1. Faça um Fork do repositório.
2. Crie uma branch para sua feature (`git checkout -b feature/minha-feature`).
3. Siga o padrão de código e certifique-se de não quebrar as regras de *parsing* XML no `init.lua`.
4. Escreva testes para a nova funcionalidade (`/tests`).
5. Abra um Pull Request!

---

## 🌍 Internacionalização

O plugin foi desenhado para escalabilidade global. O README padrão está em português para os desenvolvedores base, mas estão previstos arquivos de localização:
- **English** (`README.en.md`)
- **Español** (`README.es.md`)

## 📜 Licença

Este projeto está licenciado sob a **MIT License** – veja o arquivo `LICENSE` para detalhes.
