#!/usr/bin/env bash
# =============================================================================
#  refactor_multicontext.sh
#  Execute na pasta raíz do projeto (onde está o init.vim):
#    bash refactor_multicontext.sh
# =============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LUA_DIR="$ROOT_DIR/lua/multi_context"

GREEN='\033[0;32m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}  ✓ $1${NC}"; }
info() { echo -e "${CYAN}  → $1${NC}"; }
die()  { echo -e "${RED}  ✗ $1${NC}"; exit 1; }

echo ""
echo "=================================================="
echo "  MultiContext – Refatoração Modular"
echo "=================================================="
echo "  Raíz : $ROOT_DIR"
echo "  Lua  : $LUA_DIR"
echo ""

# ── Validação ──────────────────────────────────────────────────────────────────
[ -d "$LUA_DIR" ] || die "lua/multi_context/ não encontrado em $ROOT_DIR"
command -v python3 &>/dev/null || die "python3 não encontrado"

# ── Backup ─────────────────────────────────────────────────────────────────────
BACKUP="$ROOT_DIR/.backup_refactor_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP"
cp -r "$LUA_DIR" "$BACKUP/"
ok "Backup completo em $BACKUP"

# ── Criar subdiretório ui/ ─────────────────────────────────────────────────────
mkdir -p "$LUA_DIR/ui"
ok "Diretório ui/ criado"

echo ""
info "Escrevendo módulos refatorados..."
echo ""

# ── Escrever todos os arquivos Lua via Python ──────────────────────────────────
python3 - "$LUA_DIR" << 'PYEOF'
import sys, os

D  = sys.argv[1]               # lua/multi_context/
UI = os.path.join(D, 'ui')
os.makedirs(UI, exist_ok=True)

files = {}

# =============================================================================
# config.lua — configuração + todo o I/O de JSON (absorve utils.load_*)
# =============================================================================
files[os.path.join(D, 'config.lua')] = r"""
-- config.lua
-- Responsabilidade única: opções do plugin e I/O de configuração JSON.
local M = {}

M.defaults = {
    user_name     = "Nardi",
    config_path   = vim.fn.stdpath("config") .. "/context_apis.json",
    api_keys_path = vim.fn.stdpath("config") .. "/api_keys.json",
    default_api   = nil,
    appearance    = {
        border = "rounded",
        width  = 0.7,
        height = 0.7,
        title  = " MultiContext - Chat ",
    },
}

M.options = {}

function M.setup(user_opts)
    M.options = vim.tbl_deep_extend("force", M.defaults, user_opts or {})
end

-- ── Leitura ───────────────────────────────────────────────────────────────────

M.load_api_config = function()
    local file = io.open(M.options.config_path, 'r')
    if not file then return nil end
    local content = file:read('*a')
    file:close()
    return vim.fn.json_decode(content)
end

M.load_api_keys = function()
    local file = io.open(M.options.api_keys_path, 'r')
    if not file then return {} end
    local content = file:read('*a')
    file:close()
    return vim.fn.json_decode(content) or {}
end

-- ── Escrita ───────────────────────────────────────────────────────────────────

M.save_api_config = function(cfg)
    local raw       = vim.fn.json_encode(cfg)
    local formatted = vim.fn.system(string.format("echo %s | jq .", vim.fn.shellescape(raw)))
    local f = io.open(M.options.config_path, 'w')
    if not f then return false end
    f:write(formatted)
    f:close()
    return true
end

M.set_selected_api = function(api_name)
    local cfg = M.load_api_config()
    if not cfg then return false end
    cfg.default_api = api_name
    return M.save_api_config(cfg)
end

-- ── Consultas ─────────────────────────────────────────────────────────────────

M.get_api_names = function()
    local cfg = M.load_api_config()
    if not cfg then return {} end
    local names = {}
    for _, a in ipairs(cfg.apis) do table.insert(names, a.name) end
    return names
end

M.get_current_api = function()
    local cfg = M.load_api_config()
    if not cfg then return "" end
    return cfg.default_api or ""
end

return M
"""

# =============================================================================
# context_builders.lua — coleta de dados para contexto (novo módulo)
# Funções puras: não tocam na UI nem na API.
# =============================================================================
files[os.path.join(D, 'context_builders.lua')] = r"""
-- context_builders.lua
-- Coleta dados do editor/sistema para montar o contexto enviado à IA.
-- Módulo puramente de coleta: sem efeitos colaterais em UI ou API.
local M   = {}
local api = vim.api

local function strip_ansi(s)
    return s:gsub("\27%[[%d;]*m", ""):gsub("\27%[[%d;]*[A-Za-z]", "")
end

M.get_git_diff = function()
    vim.fn.system("git rev-parse --show-toplevel")
    if vim.v.shell_error ~= 0 then return "=== Não é um repositório Git ===" end
    local diff = vim.fn.system("git -c color.ui=never -c color.diff=never diff HEAD")
    return "=== GIT DIFF ===\n" .. strip_ansi(diff)
end

M.get_tree_context = function()
    local dir   = vim.fn.expand('%:p:h')
    local tree  = strip_ansi(vim.fn.system("tree -f --noreport " .. vim.fn.shellescape(dir)))
    local ctx   = { "=== TREE E CONTEÚDO ===", tree }
    local found = vim.fn.split(
        vim.fn.system("find " .. vim.fn.shellescape(dir) .. " -maxdepth 2 -type f"), "\n"
    )
    for _, f in ipairs(found) do
        if not f:match("/%.git/") and f ~= "" then
            table.insert(ctx, "")
            table.insert(ctx, "== Arquivo: " .. f .. " ==")
            local ok, lines = pcall(vim.fn.readfile, f)
            if ok then
                for _, l in ipairs(lines) do table.insert(ctx, l) end
            end
        end
    end
    return table.concat(ctx, "\n")
end

M.get_all_buffers_content = function()
    local result = {}
    for _, bufnr in ipairs(api.nvim_list_bufs()) do
        if api.nvim_buf_is_loaded(bufnr) then
            local name  = api.nvim_buf_get_name(bufnr)
            local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
            if #lines > 0 and name ~= "" then
                table.insert(result, "=== Buffer: " .. name .. " ===")
                vim.list_extend(result, lines)
                table.insert(result, "")
            end
        end
    end
    return table.concat(result, "\n")
end

M.get_current_buffer = function()
    local buf = api.nvim_get_current_buf()
    return "=== BUFFER ATUAL ===\n"
        .. table.concat(api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
end

-- line1/line2: números de linha (1-indexed). Se omitidos, usa a seleção visual.
M.get_visual_selection = function(line1, line2)
    local buf = api.nvim_get_current_buf()
    local s   = tonumber(line1) or vim.fn.getpos("'<")[2]
    local e   = tonumber(line2) or vim.fn.getpos("'>")[2]
    if s > e then s, e = e, s end
    return "=== SELEÇÃO (linhas " .. s .. "-" .. e .. ") ===\n"
        .. table.concat(api.nvim_buf_get_lines(buf, s - 1, e, false), "\n")
end

return M
"""

# =============================================================================
# conversation.lua — estrutura de histórico de mensagens (novo módulo)
# =============================================================================
files[os.path.join(D, 'conversation.lua')] = r"""
-- conversation.lua
-- Lê o buffer de chat e reconstrói o histórico de mensagens para a API.
local M   = {}
local api = vim.api

-- Retorna o índice (0-based) da última linha que começa com o prompt do usuário.
M.find_last_user_line = function(buf)
    local name  = require('multi_context.config').options.user_name
    local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
    for i = #lines, 1, -1 do
        if lines[i]:match("^## " .. name .. " >>") then
            return i - 1, lines[i]
        end
    end
    return nil
end

-- Percorre o buffer e monta o array {role, content}[] completo.
M.build_history = function(buf)
    local config    = require('multi_context.config')
    local user_name = config.options.user_name
    local lines     = api.nvim_buf_get_lines(buf, 0, -1, false)

    local messages  = {}
    local role      = nil
    local acc       = {}
    local user_pat  = "^## " .. user_name .. " >>"

    local function flush()
        if role and #acc > 0 then
            local text = table.concat(acc, "\n"):match("^%s*(.-)%s*$")
            if text ~= "" then
                table.insert(messages, { role = role, content = text })
            end
        end
        acc = {}
    end

    for _, line in ipairs(lines) do
        if line:match(user_pat) then
            flush()
            role     = "user"
            local body = line:gsub(user_pat .. "%s*", "")
            if body ~= "" then table.insert(acc, body) end
        elseif line:match("^## IA >>") then
            flush()
            role = "assistant"
        elseif line:match("^## API atual:") then
            -- metadado de rodapé, ignora
        else
            if role then table.insert(acc, line) end
        end
    end
    flush()
    return messages
end

return M
"""

# =============================================================================
# api_client.lua — fila, fallback e orquestração de chamadas (novo módulo)
# Não conhece nada de UI.
# =============================================================================
files[os.path.join(D, 'api_client.lua')] = r"""
-- api_client.lua
-- Monta a fila de APIs, aplica fallback e delega a execução ao handler.
-- Não tem dependência de UI.
local M = {}

local function build_queue(cfg)
    local queue = {}
    -- API padrão sempre na frente
    for _, a in ipairs(cfg.apis) do
        if a.name == cfg.default_api then
            table.insert(queue, a)
            break
        end
    end
    -- Fallbacks na ordem do JSON
    if cfg.fallback_mode then
        for _, a in ipairs(cfg.apis) do
            if a['include_in_fall-back_mode'] and a.name ~= cfg.default_api then
                table.insert(queue, a)
            end
        end
    end
    return queue
end

-- M.execute(messages, on_chunk, on_done, on_error)
--
--   messages  : {role:string, content:string}[]
--   on_chunk  : function(text:string,  api_entry:table)
--   on_done   : function(api_entry:table)
--   on_error  : function(msg:string)
--
M.execute = function(messages, on_chunk, on_done, on_error)
    local config       = require('multi_context.config')
    local api_handlers = require('multi_context.api_handlers')

    local cfg = config.load_api_config()
    if not cfg then
        on_error("Configuração de APIs não encontrada.")
        return
    end

    local queue = build_queue(cfg)
    if #queue == 0 then
        on_error("Nenhuma API na fila. Configure com :ContextApis")
        return
    end

    local api_keys = config.load_api_keys()

    local function try(idx)
        if idx > #queue then
            on_error("Erro em todas as APIs da fila.")
            return
        end
        local entry   = queue[idx]
        local handler = api_handlers[entry.api_type or "openai"]
        if not handler then
            vim.notify(
                "Handler ausente para api_type: " .. (entry.api_type or "?"),
                vim.log.levels.WARN
            )
            try(idx + 1)
            return
        end
        handler.make_request(entry, messages, api_keys, nil, function(chunk, err, done)
            vim.schedule(function()
                if err   then try(idx + 1); return end
                if chunk then on_chunk(chunk, entry) end
                if done  then on_done(entry) end
            end)
        end)
    end

    try(1)
end

return M
"""

# =============================================================================
# api_handlers.lua — adaptadores de protocolo (só protocolo, sem lógica de fila)
# =============================================================================
files[os.path.join(D, 'api_handlers.lua')] = r"""
-- api_handlers.lua
-- Adaptadores de protocolo HTTP para cada provider.
-- Recebe um payload pronto e devolve chunks via callback(text, err, done).
local M = {}

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function decode_json_string(s)
    s = s:gsub("\\n",  "\n")
    s = s:gsub("\\t",  "\t")
    s = s:gsub("\\r",  "\r")
    s = s:gsub('\\"',  '"')
    s = s:gsub("\\\\", "\\")
    return s
end

-- Extrai todos os valores de "text" de um chunk SSE parcial,
-- respeitando escapes JSON internos. Retorna (chunks[], buffer_restante).
local function extract_text_chunks(buffer)
    local results   = {}
    local remaining = buffer
    while true do
        local pos = remaining:find('"text"%s*:%s*"')
        if not pos then break end
        local str_start = remaining:find('"', pos + 1) + 1
        local str_end   = nil
        local i = str_start
        while i <= #remaining do
            local ch = remaining:sub(i, i)
            if     ch == '\\' then i = i + 2
            elseif ch == '"'  then str_end = i; break
            else                   i = i + 1
            end
        end
        if not str_end then break end
        table.insert(results, decode_json_string(remaining:sub(str_start, str_end - 1)))
        remaining = remaining:sub(str_end + 1)
    end
    return results, remaining
end

-- Constrói args -H para curl a partir dos headers do config,
-- substituindo {API_KEY} pela chave real.
local function header_args(api_config, api_key)
    local args = {}
    for k, v in pairs(api_config.headers or {}) do
        table.insert(args, "-H")
        table.insert(args, k .. ": " .. v:gsub("{API_KEY}", api_key))
    end
    return args
end

-- ── Gemini ────────────────────────────────────────────────────────────────────

M.gemini = {
    make_request = function(api_config, messages, api_keys, last_sig, callback)
        local api_key  = api_keys[api_config.name] or ""
        local contents = {}
        local sys_inst = nil

        for _, msg in ipairs(messages) do
            if msg.role == "system" then
                sys_inst = { parts = {{ text = msg.content }} }
            else
                local part = { text = msg.content }
                if msg.role == "model" and last_sig then
                    part.thoughtSignature = last_sig
                end
                table.insert(contents, {
                    role  = msg.role == "user" and "user" or "model",
                    parts = { part },
                })
            end
        end

        -- thinkingConfig apenas para modelos que o suportam (2.5+, *thinking*)
        local gen_cfg = {}
        local model   = api_config.model or ""
        if model:match("2%.5") or model:match("thinking") then
            gen_cfg.thinkingConfig = { thinkingLevel = "medium" }
        end

        local payload = {
            contents           = contents,
            system_instruction = sys_inst,
            generationConfig   = next(gen_cfg) ~= nil and gen_cfg or nil,
        }

        local url = api_config.url:gsub(":generateContent", ":streamGenerateContent")
        local cmd = {
            "curl", "-s", "-N", "-L", "-X", "POST",
            url .. "?key=" .. api_key,
            "-H", "Content-Type: application/json",
            "-d", vim.fn.json_encode(payload),
        }

        local partial = ""
        vim.fn.jobstart(cmd, {
            on_stdout = function(_, data)
                if not data then return end
                partial = partial .. table.concat(data, "")
                if partial:match('"error":') then
                    local msg = partial:match('"message":%s*"([^"]+)"') or "Erro de Cota/API"
                    callback(nil, msg, false)
                    return
                end
                local chunks
                chunks, partial = extract_text_chunks(partial)
                for _, c in ipairs(chunks) do callback(c, nil, false) end
            end,
            on_exit = function() callback(nil, nil, true) end,
        })
    end,
}

-- ── OpenAI-compatible (OpenAI, Moonshot/Kimi, DeepSeek, Groq, OpenRouter…) ────

M.openai = {
    make_request = function(api_config, messages, api_keys, _, callback)
        local api_key = api_keys[api_config.name] or ""
        local cmd     = { "curl", "-s", "-N", "-L", "-X", "POST", api_config.url }
        for _, h in ipairs(header_args(api_config, api_key)) do
            table.insert(cmd, h)
        end
        table.insert(cmd, "-d")
        table.insert(cmd, vim.fn.json_encode({
            model    = api_config.model,
            messages = messages,
            stream   = true,
        }))

        vim.fn.jobstart(cmd, {
            on_stdout = function(_, data)
                for _, line in ipairs(data or {}) do
                    if line:match("^data: ") and not line:match("%[DONE%]") then
                        local ok, dec = pcall(vim.fn.json_decode, line:sub(7))
                        if ok and dec.choices and dec.choices[1].delta then
                            callback(dec.choices[1].delta.content, nil, false)
                        end
                    end
                end
            end,
            on_exit = function() callback(nil, nil, true) end,
        })
    end,
}

-- ── Cloudflare Workers AI ─────────────────────────────────────────────────────

M.cloudflare = {
    make_request = function(api_config, messages, api_keys, _, callback)
        local api_key = api_keys[api_config.name] or ""
        local cmd = {
            "curl", "-s", "-L", "-X", "POST", api_config.url,
            "-H", "Content-Type: application/json",
            "-H", "Authorization: Bearer " .. api_key,
            "-d", vim.fn.json_encode({ messages = messages }),
        }
        local output = ""
        vim.fn.jobstart(cmd, {
            on_stdout = function(_, data)
                if data then output = output .. table.concat(data, "") end
            end,
            on_exit = function()
                local ok, dec = pcall(vim.fn.json_decode, output)
                if ok and dec and dec.result and dec.result.response then
                    callback(dec.result.response, nil, false)
                else
                    local err = ok and dec and dec.errors
                              and dec.errors[1] and dec.errors[1].message
                              or "Erro Cloudflare"
                    callback(nil, err, false)
                end
                callback(nil, nil, true)
            end,
        })
    end,
}

return M
"""

# =============================================================================
# ui/highlights.lua — grupos de highlight e funções de aplicação (novo módulo)
# =============================================================================
files[os.path.join(UI, 'highlights.lua')] = r"""
-- ui/highlights.lua
-- Centraliza namespace, definição de grupos e aplicação de destaques visuais.
local M   = {}
local api = vim.api

M.ns_id = api.nvim_create_namespace("multi_context_highlights")

M.define_groups = function()
    vim.cmd("highlight ContextSelectorTitle    gui=bold guifg=#FFA500 guibg=NONE")
    vim.cmd("highlight ContextSelectorCurrent  gui=bold guifg=#B22222 guibg=NONE")
    vim.cmd("highlight ContextSelectorSelected gui=bold guifg=#FFFF00 guibg=NONE")
end

-- Destaca linhas "## IA >>" no buffer de chat (azul diagnóstico)
M.apply_chat = function(buf)
    api.nvim_buf_clear_namespace(buf, M.ns_id, 0, -1)
    local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
    for i, l in ipairs(lines) do
        if l:match("^## IA") then
            api.nvim_buf_set_extmark(buf, M.ns_id, i - 1, 0, {
                end_col  = #l,
                hl_group = "DiagnosticInfo",
            })
        end
    end
end

-- Destaca o seletor de APIs (cabeçalho, item selecionado, item atual)
M.apply_selector = function(buf, api_list)
    api.nvim_buf_clear_namespace(buf, M.ns_id, 0, -1)
    M.define_groups()

    -- Cabeçalho (linhas 0 e 1, 0-indexed)
    api.nvim_buf_add_highlight(buf, -1, "ContextSelectorTitle", 0, 0, -1)
    api.nvim_buf_add_highlight(buf, -1, "ContextSelectorTitle", 1, 0, -1)

    -- Itens: começam na linha 3 (0-indexed) — linha 0/1 = cabeçalho, 2 = vazia
    for i = 3, 3 + #api_list - 1 do
        local line = api.nvim_buf_get_lines(buf, i, i + 1, false)[1]
        if line then
            if line:match("^❯") then
                api.nvim_buf_add_highlight(buf, -1, "ContextSelectorCurrent", i, 0, -1)
            end
            if line:match("%(selecionada%)$") then
                api.nvim_buf_add_highlight(buf, -1, "ContextSelectorSelected", i, 0, -1)
            end
        end
    end

    -- Rodapé "API atual: …" (penúltima linha, 0-indexed = total - 2)
    local total = api.nvim_buf_line_count(buf)
    if total >= 2 then
        api.nvim_buf_add_highlight(buf, -1, "ContextSelectorTitle", total - 2, 0, -1)
    end
end

return M
"""

# =============================================================================
# ui/popup.lua — janela flutuante do chat (só UI, sem lógica de envio)
# =============================================================================
files[os.path.join(UI, 'popup.lua')] = r"""
-- ui/popup.lua
-- Cria e gerencia a janela flutuante de chat.
-- Não sabe nada sobre histórico, API ou envio de mensagens.
local api = vim.api
local M   = {}

M.popup_buf = nil
M.popup_win = nil

-- Cria o popup ou foca no existente se já estiver aberto.
-- initial_content: string com contexto a pré-popular (ou "" para janela limpa).
function M.create_popup(initial_content)
    if M.popup_win and api.nvim_win_is_valid(M.popup_win) then
        api.nvim_set_current_win(M.popup_win)
        return M.popup_buf, M.popup_win
    end

    local config = require('multi_context.config')
    local hl     = require('multi_context.ui.highlights')

    local buf = api.nvim_create_buf(false, true)
    M.popup_buf = buf

    vim.bo[buf].buftype   = 'nofile'
    vim.bo[buf].filetype  = 'markdown'
    vim.bo[buf].bufhidden = 'hide'
    vim.bo[buf].swapfile  = false

    local km = { noremap = true, silent = true }
    api.nvim_buf_set_keymap(buf, "n", "<CR>",
        "<Cmd>lua require('multi_context').SendFromPopup()<CR>", km)
    api.nvim_buf_set_keymap(buf, "n", "<A-b>",
        "<Cmd>lua require('multi_context.utils').copy_code_block()<CR>", km)
    api.nvim_buf_set_keymap(buf, "i", "<A-b>",
        "<Esc><Cmd>lua require('multi_context.utils').copy_code_block()<CR>a", km)
    api.nvim_buf_set_keymap(buf, "n", "q", "<Cmd>q<CR>", km)

    local width  = math.ceil(vim.o.columns * 0.8)
    local height = math.ceil(vim.o.lines   * 0.8)
    local row    = math.ceil((vim.o.lines   - height) / 2)
    local col    = math.ceil((vim.o.columns - width)  / 2)

    local api_name = config.get_current_api()
    local title    = " " .. (api_name ~= "" and api_name or "MultiContext AI") .. " "

    local win = api.nvim_open_win(buf, true, {
        relative  = 'editor',
        width     = width,
        height    = height,
        row       = row,
        col       = col,
        style     = 'minimal',
        border    = 'rounded',
        title     = title,
        title_pos = 'center',
    })
    M.popup_win = win

    -- Popula conteúdo inicial e posiciona cursor
    local user_prefix = "## " .. config.options.user_name .. " >> "
    if initial_content and initial_content ~= "" then
        local init_lines = vim.split(initial_content, "\n", { plain = true })
        api.nvim_buf_set_lines(buf, 0, -1, false, init_lines)
        api.nvim_buf_set_lines(buf, -1, -1, false, { "", user_prefix })
    else
        api.nvim_buf_set_lines(buf, 0, -1, false, { user_prefix })
    end

    local last_ln  = api.nvim_buf_line_count(buf)
    local last_txt = api.nvim_buf_get_lines(buf, last_ln - 1, last_ln, false)[1] or ""
    api.nvim_win_set_cursor(win, { last_ln, #last_txt })

    hl.apply_chat(buf)
    M._setup_folds()

    return buf, win
end

function M._setup_folds()
    if not M.popup_win or not api.nvim_win_is_valid(M.popup_win) then return end
    vim.wo[M.popup_win].foldmethod = 'marker'
    vim.wo[M.popup_win].foldmarker = '## IA >>,## API atual:'
    vim.wo[M.popup_win].foldlevel  = 99
end

-- Atualiza o título da janela com a API atual (chamado após :ContextApis)
function M.update_title()
    if not M.popup_win or not api.nvim_win_is_valid(M.popup_win) then return end
    local api_name = require('multi_context.config').get_current_api()
    local title    = " " .. (api_name ~= "" and api_name or "MultiContext AI") .. " "
    api.nvim_win_set_config(M.popup_win, { title = title, title_pos = 'center' })
end

-- Alias para compatibilidade com código que ainda chama create_folds(buf)
M.create_folds = M._setup_folds

return M
"""

# =============================================================================
# utils.lua — utilitários genéricos de texto/buffer (enxuto)
# =============================================================================
files[os.path.join(D, 'utils.lua')] = r"""
-- utils.lua
-- Utilitários de texto e buffer sem domínio próprio.
-- Funções de domínio foram movidas para módulos específicos:
--   config.lua           → I/O de configuração JSON
--   context_builders.lua → coleta de contexto do editor
--   conversation.lua     → histórico de mensagens
--   ui/highlights.lua    → destaques visuais
local M   = {}
local api = vim.api

M.split_lines = function(s)
    local t = {}
    if not s or s == "" then return t end
    for l in s:gmatch("([^\n]*)\n?") do table.insert(t, l) end
    return t
end

-- Insere linhas no buffer. line_idx == -1 significa ao final.
M.insert_after = function(buf, line_idx, lines)
    local target = (line_idx == -1) and api.nvim_buf_line_count(buf) or line_idx
    api.nvim_buf_set_lines(buf, target, target, false, lines)
end

-- Copia o bloco de código delimitado por ``` mais próximo do cursor.
M.copy_code_block = function()
    local buf    = api.nvim_get_current_buf()
    local cursor = api.nvim_win_get_cursor(0)[1]
    local lines  = api.nvim_buf_get_lines(buf, 0, -1, false)
    local s, e   = nil, nil
    for i = cursor, 1, -1 do
        if lines[i] and lines[i]:match("^```") then s = i; break end
    end
    for i = cursor, #lines do
        if lines[i] and lines[i]:match("^```") and i ~= s then e = i; break end
    end
    if s and e then
        vim.fn.setreg('+', table.concat(api.nvim_buf_get_lines(buf, s, e - 1, false), "\n"))
        vim.notify("Código copiado!")
    else
        vim.notify("Nenhum bloco de código encontrado.", vim.log.levels.WARN)
    end
end

-- ── Wrappers de compatibilidade retroativa ────────────────────────────────────
-- Permitem que código externo ainda use os nomes antigos durante a transição.

M.apply_highlights        = function(b) require('multi_context.ui.highlights').apply_chat(b) end
M.get_git_diff            = function()  return require('multi_context.context_builders').get_git_diff() end
M.get_tree_context        = function()  return require('multi_context.context_builders').get_tree_context() end
M.get_all_buffers_content = function()  return require('multi_context.context_builders').get_all_buffers_content() end
M.find_last_user_line     = function(b) return require('multi_context.conversation').find_last_user_line(b) end
M.load_api_config         = function()  return require('multi_context.config').load_api_config() end
M.load_api_keys           = function()  return require('multi_context.config').load_api_keys() end
M.set_selected_api        = function(n) return require('multi_context.config').set_selected_api(n) end
M.get_api_names           = function()  return require('multi_context.config').get_api_names() end
M.get_current_api         = function()  return require('multi_context.config').get_current_api() end

return M
"""

# =============================================================================
# commands.lua — conecta comandos do usuário a context_builders + ui/popup
# =============================================================================
files[os.path.join(D, 'commands.lua')] = r"""
-- commands.lua
-- Handlers dos comandos expostos pelo plugin.
-- Conecta :Context*, :ContextGit, etc. aos context_builders e ao popup.
local M = {}

-- Abre o popup com um conteúdo inicial e entra em modo de inserção.
local function open_with(content)
    local buf, win = require('multi_context.ui.popup').create_popup(content)
    if buf and win then vim.cmd("startinsert!") end
end

M.ContextChatHandler = function(line1, line2)
    local ctx = require('multi_context.context_builders')
    -- Chamado com range explícito (comando -range ou vnoremap)
    if line1 and line2 and tonumber(line1) ~= tonumber(line2) then
        open_with(ctx.get_visual_selection(line1, line2))
        return
    end
    -- Chamado sem range: detecta modo visual ou usa buffer inteiro
    local mode = vim.api.nvim_get_mode().mode
    if mode == 'v' or mode == 'V' then
        open_with(ctx.get_visual_selection())
    else
        open_with(ctx.get_current_buffer())
    end
end

M.ContextChatFull = function() open_with("") end

M.ContextBuffers  = function()
    open_with(require('multi_context.context_builders').get_all_buffers_content())
end

M.ContextTree     = function()
    open_with(require('multi_context.context_builders').get_tree_context())
end

M.ContextChatGit  = function()
    open_with(require('multi_context.context_builders').get_git_diff())
end

M.ContextApis     = function()
    require('multi_context.api_selector').open_api_selector()
end

return M
"""

# =============================================================================
# api_selector.lua — seletor de API (usa config e ui/highlights)
# =============================================================================
files[os.path.join(D, 'api_selector.lua')] = r"""
-- api_selector.lua
-- Popup flutuante para selecionar a API padrão.
-- Usa config para leitura/escrita e ui/highlights para visuais.
local api = vim.api
local M   = {}

M.selector_buf      = nil
M.selector_win      = nil
M.api_list          = {}
M.current_selection = 1

M.open_api_selector = function()
    local config = require('multi_context.config')
    M.api_list   = config.get_api_names()
    if #M.api_list == 0 then
        vim.notify("Nenhuma API configurada.", vim.log.levels.WARN)
        return
    end

    local current = config.get_current_api()
    M.current_selection = 1
    for i, name in ipairs(M.api_list) do
        if name == current then M.current_selection = i; break end
    end

    M.selector_buf = api.nvim_create_buf(false, true)

    local width  = 60
    local height = math.min(#M.api_list + 5, 22)
    local row    = math.floor((vim.o.lines   - height) / 2)
    local col    = math.floor((vim.o.columns - width)  / 2)

    M.selector_win = api.nvim_open_win(M.selector_buf, true, {
        relative  = "editor",
        width     = width,
        height    = height,
        row       = row,
        col       = col,
        style     = "minimal",
        border    = "rounded",
        title     = " Selecionar API ",
        title_pos = "center",
    })

    vim.bo[M.selector_buf].buftype    = "nofile"
    vim.bo[M.selector_buf].modifiable = true

    M._render()
    M._keymaps()
end

M._render = function()
    if not M.selector_buf or not api.nvim_buf_is_valid(M.selector_buf) then return end

    local config  = require('multi_context.config')
    local hl      = require('multi_context.ui.highlights')
    local current = config.get_current_api()

    local lines = {
        "Selecione a API para usar nas requisições:",
        "  j/k navegar   Enter selecionar   q sair",
        "",
    }
    for i, name in ipairs(M.api_list) do
        local cursor = (i == M.current_selection) and "❯ " or "  "
        local tag    = (name == current)           and " (selecionada)" or ""
        table.insert(lines, cursor .. name .. tag)
    end
    table.insert(lines, "")
    table.insert(lines, "  API atual: " .. current)

    vim.bo[M.selector_buf].modifiable = true
    api.nvim_buf_set_lines(M.selector_buf, 0, -1, false, lines)
    hl.apply_selector(M.selector_buf, M.api_list)
end

M._keymaps = function()
    if not M.selector_buf or not api.nvim_buf_is_valid(M.selector_buf) then return end
    local function mk(k, fn)
        api.nvim_buf_set_keymap(M.selector_buf, "n", k, "",
            { callback = fn, noremap = true, silent = true })
    end
    mk("j",     function() M._move(1)  end)
    mk("k",     function() M._move(-1) end)
    mk("<CR>",  M._select)
    mk("q",     M._close)
    mk("<Esc>", M._close)
end

M._move = function(dir)
    local n = M.current_selection + dir
    if n >= 1 and n <= #M.api_list then
        M.current_selection = n
        M._render()
    end
end

M._select = function()
    local config = require('multi_context.config')
    local name   = M.api_list[M.current_selection]
    if config.set_selected_api(name) then
        vim.notify("API selecionada: " .. name, vim.log.levels.INFO)
        require('multi_context.ui.popup').update_title()
        M._close()
    else
        vim.notify("Erro ao selecionar: " .. name, vim.log.levels.ERROR)
    end
end

M._close = function()
    if M.selector_win and api.nvim_win_is_valid(M.selector_win) then
        api.nvim_win_close(M.selector_win, true)
    end
    M.selector_buf      = nil
    M.selector_win      = nil
    M.api_list          = {}
    M.current_selection = 1
end

return M
"""

# =============================================================================
# queue_editor.lua — editor de fila (usa config.save_api_config)
# =============================================================================
files[os.path.join(D, 'queue_editor.lua')] = r"""
-- queue_editor.lua
-- Buffer interativo para reordenar a fila de APIs (dd/p para mover, :w para salvar).
local api = vim.api
local M   = {}

M.open_editor = function()
    local config = require('multi_context.config')
    local cfg    = config.load_api_config()
    if not cfg then
        vim.notify("Configuração não encontrada.", vim.log.levels.ERROR)
        return
    end

    local names = {}
    for _, a in ipairs(cfg.apis) do table.insert(names, a.name) end

    local buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_lines(buf, 0, -1, false, names)

    -- buftype 'acwrite' permite :w sem arquivo físico (evita E32)
    vim.bo[buf].buftype = 'acwrite'
    api.nvim_buf_set_name(buf, "MultiContext_Queue_Editor")

    local height = math.min(#names + 2, 20)
    local win    = api.nvim_open_win(buf, true, {
        relative  = 'editor',
        width     = 52,
        height    = height,
        row       = 5,
        col       = 10,
        border    = 'rounded',
        title     = ' Ordenar Fila  (dd/p mover · :w salvar) ',
        title_pos = 'center',
    })

    api.nvim_create_autocmd("BufWriteCmd", {
        buffer   = buf,
        callback = function()
            local lines     = api.nvim_buf_get_lines(buf, 0, -1, false)
            local reordered = {}
            for _, name in ipairs(lines) do
                for _, a in ipairs(cfg.apis) do
                    if a.name == name then table.insert(reordered, a); break end
                end
            end
            cfg.apis = reordered
            if config.save_api_config(cfg) then
                vim.notify("Fila salva!", vim.log.levels.INFO)
                vim.bo[buf].modified = false
                api.nvim_win_close(win, true)
            else
                vim.notify("Erro ao salvar.", vim.log.levels.ERROR)
            end
        end,
    })

    api.nvim_buf_set_keymap(buf, "n", "q", ":q!<CR>", { noremap = true, silent = true })
end

return M
"""

# =============================================================================
# init.lua — ponto de entrada limpo: setup, API pública e comandos Vim
# =============================================================================
files[os.path.join(D, 'init.lua')] = r"""
-- init.lua
-- Ponto de entrada do plugin.
-- Responsabilidades: setup(), API pública e registro de comandos Vim.
-- Sem lógica de negócio — tudo delega aos módulos específicos.
local M = {}

local config       = require('multi_context.config')
local commands     = require('multi_context.commands')
local ui_popup     = require('multi_context.ui.popup')
local utils        = require('multi_context.utils')
local api_client   = require('multi_context.api_client')
local conversation = require('multi_context.conversation')

-- ── Setup ─────────────────────────────────────────────────────────────────────

M.setup = function(opts)
    config.setup(opts)
end

-- ── API pública ───────────────────────────────────────────────────────────────

M.Context            = commands.ContextChatHandler
M.ContextChatFull    = commands.ContextChatFull
M.ContextChatHandler = commands.ContextChatHandler
M.ContextBuffers     = commands.ContextBuffers
M.ContextChatFolder  = commands.ContextTree
M.ContextFolder      = commands.ContextTree
M.ContextChatGit     = commands.ContextChatGit
M.ContextGit         = commands.ContextChatGit
M.ContextTree        = commands.ContextTree
M.ContextRepo        = commands.ContextTree
M.ContextChatRepo    = commands.ContextTree
M.ContextApis        = commands.ContextApis
M.ContextQueue       = function() require('multi_context.queue_editor').open_editor() end

M.TogglePopup = function()
    if ui_popup.popup_win and vim.api.nvim_win_is_valid(ui_popup.popup_win) then
        vim.api.nvim_win_close(ui_popup.popup_win, true)
    else
        commands.ContextChatHandler()
    end
end

-- Abre o contexto do projeto como workspace (atalho <A-w>)
M.ToggleWorkspaceView = function()
    commands.ContextTree()
end

-- ── SendFromPopup ─────────────────────────────────────────────────────────────

M.SendFromPopup = function()
    local buf = ui_popup.popup_buf
    if not buf or not vim.api.nvim_buf_is_valid(buf) then return end

    local user_prefix = "## " .. config.options.user_name .. " >> "
    local hl          = require('multi_context.ui.highlights')

    -- Monta histórico completo da sessão
    local messages = conversation.build_history(buf)

    -- Valida: última mensagem deve ser do usuário e não vazia
    if #messages == 0
        or messages[#messages].role    ~= "user"
        or messages[#messages].content == "" then
        return
    end

    -- Reserva bloco de resposta no buffer
    vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "", "## IA >> ", "" })
    local resp_start  = vim.api.nvim_buf_line_count(buf) - 1
    local accumulated = ""

    api_client.execute(
        messages,

        -- on_chunk: acumula e renderiza em tempo real
        function(chunk, _)
            accumulated = accumulated .. chunk
            vim.api.nvim_buf_set_lines(
                buf, resp_start, -1, false, utils.split_lines(accumulated)
            )
        end,

        -- on_done: insere rodapé e posiciona cursor no próximo prompt
        function(entry)
            utils.insert_after(buf, -1, {
                "",
                "## API atual: " .. entry.name,
                user_prefix,
            })
            hl.apply_chat(buf)
            local last = vim.api.nvim_buf_line_count(buf)
            if ui_popup.popup_win and vim.api.nvim_win_is_valid(ui_popup.popup_win) then
                vim.api.nvim_win_set_cursor(ui_popup.popup_win, { last, #user_prefix })
                vim.cmd("startinsert!")
            end
        end,

        -- on_error
        function(msg)
            vim.notify("MultiContext: " .. msg, vim.log.levels.ERROR)
        end
    )
end

-- ── Comandos Vim ──────────────────────────────────────────────────────────────

vim.cmd([[
  command! Context        lua require('multi_context').Context()
  command! ContextBuffers lua require('multi_context').ContextBuffers()
  command! ContextTree    lua require('multi_context').ContextTree()
  command! ContextRepo    lua require('multi_context').ContextRepo()
  command! ContextApis    lua require('multi_context').ContextApis()
  command! ContextQueue   lua require('multi_context').ContextQueue()
]])

return M
"""

# ── Escrita dos arquivos ──────────────────────────────────────────────────────
written = []
for path, content in files.items():
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content.lstrip('\n'))
    written.append(path)

print(f"\n  {len(written)} arquivos escritos:")
for p in sorted(written):
    rel = p.replace(os.path.dirname(D) + '/', '')
    print(f"    ✓ {rel}")

PYEOF

echo ""

# ── Verificação da estrutura final ─────────────────────────────────────────────
info "Verificando estrutura..."

EXPECTED=(
    "config.lua"
    "context_builders.lua"
    "conversation.lua"
    "api_client.lua"
    "api_handlers.lua"
    "utils.lua"
    "commands.lua"
    "api_selector.lua"
    "queue_editor.lua"
    "init.lua"
    "ui/highlights.lua"
    "ui/popup.lua"
)

ALL_OK=true
for f in "${EXPECTED[@]}"; do
    if [ -f "$LUA_DIR/$f" ]; then
        ok "$f"
    else
        echo -e "${RED}  ✗ FALTANDO: $f${NC}"
        ALL_OK=false
    fi
done

echo ""

if $ALL_OK; then
    echo "=================================================="
    echo -e "${GREEN}  Refatoração concluída com sucesso!${NC}"
    echo "=================================================="
else
    echo -e "${RED}  Alguns arquivos não foram criados. Verifique os erros acima.${NC}"
fi

echo ""
echo "  Estrutura resultante:"
echo ""
echo "  lua/multi_context/"
echo "  ├── init.lua             ← entrada: setup + API pública + comandos Vim"
echo "  ├── config.lua           ← opções + I/O de JSON"
echo "  ├── context_builders.lua ← coleta: git, tree, buffers, seleção"
echo "  ├── conversation.lua     ← histórico de mensagens do chat"
echo "  ├── api_client.lua       ← fila + fallback + orquestração"
echo "  ├── api_handlers.lua     ← adaptadores HTTP (Gemini / OpenAI / Cloudflare)"
echo "  ├── commands.lua         ← handlers dos comandos :Context*"
echo "  ├── api_selector.lua     ← popup de seleção de API"
echo "  ├── queue_editor.lua     ← editor de fila de APIs"
echo "  ├── utils.lua            ← utilitários genéricos + wrappers de compat."
echo "  └── ui/"
echo "      ├── popup.lua        ← janela flutuante do chat"
echo "      └── highlights.lua   ← grupos e aplicação de destaques visuais"
echo ""
echo "  Backup dos arquivos originais em: $BACKUP"
echo "  Próximo passo: reabra o Neovim e teste com :ContextApis"
echo ""
