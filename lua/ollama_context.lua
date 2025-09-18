-- ~/.config/nvim/lua/ollama_context.lua

local api = vim.api
local M = {}

M.popup_buf = nil
M.popup_win = nil
M.history = {}
M.context_text = nil

-- utilitário: divide string em linhas
local function split_lines(str)
  local t = {}
  for line in str:gmatch("([^\n]*)\n?") do
    table.insert(t, line)
  end
  return t
end

local function insert_after(buf, line_idx, lines)
  api.nvim_buf_set_lines(buf, line_idx + 1, line_idx + 1, false, lines)
end

local function replace_line(buf, line_idx, lines)
  api.nvim_buf_set_lines(buf, line_idx, line_idx + 1, false, lines)
end

local function find_last_user_line(buf)
  local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
  for i = #lines, 1, -1 do
    if lines[i]:match("^## Nardi >>") then
      return i - 1, lines[i]
    end
  end
  return nil
end

-- Abre popup interativo com contexto
function M.ContextChat()
  local cur_buf = api.nvim_get_current_buf()
  local mode = vim.fn.mode()
  local start_line, end_line

  -- usa seleção visual se houver
  if mode == 'v' or mode == 'V' then
    start_line = vim.fn.line("v") - 1
    end_line = vim.fn.line(".")
  else
    start_line = 0
    end_line = -1
  end

  local lines = api.nvim_buf_get_lines(cur_buf, start_line, end_line, false)
  M.context_text = table.concat(lines, "\n")

  local buf = api.nvim_create_buf(false, true)
  M.popup_buf = buf

  local width = math.floor(vim.o.columns * 0.7)
  local height = math.floor(vim.o.lines * 0.7)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  M.popup_win = api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
  })

  -- coloca contexto no popup
  local initial_lines = split_lines(M.context_text)
  table.insert(initial_lines, "")
  table.insert(initial_lines, "## Nardi >> ")
  api.nvim_buf_set_lines(buf, 0, -1, false, initial_lines)

  -- move cursor para o final da linha de usuário
  api.nvim_win_set_cursor(M.popup_win, { #initial_lines, #"## Nardi >> "})
  vim.cmd("startinsert")

  -- Ctrl+S para enviar
  api.nvim_buf_set_keymap(buf, "i", "<C-s>", "<Cmd>lua require('ollama_context').SendFromPopup()<CR>", { noremap = true, silent = true })
  api.nvim_buf_set_keymap(buf, "n", "<C-s>", "<Cmd>lua require('ollama_context').SendFromPopup()<CR>", { noremap = true, silent = true })
end

-- envia prompt para IA
function M.SendFromPopup()
  if not M.popup_buf or not api.nvim_buf_is_valid(M.popup_buf) then
    vim.notify("Popup não está aberto. Use :Context", vim.log.levels.WARN)
    return
  end

  local buf = M.popup_buf
  local start_idx, _ = find_last_user_line(buf)
  if not start_idx then
    vim.notify("Nenhuma linha '## Nardi >>' encontrada.", vim.log.levels.WARN)
    return
  end

  local lines = api.nvim_buf_get_lines(buf, start_idx, -1, false)
  local user_text = table.concat(lines, "\n"):gsub("^## Nardi >>%s*", "")
  if user_text == "" then
    vim.notify("Digite algo após '## Nardi >>' antes de enviar.", vim.log.levels.WARN)
    return
  end

  -- adiciona histórico
  table.insert(M.history, { user = user_text, ai = nil, status_line = #api.nvim_buf_get_lines(buf,0,-1,false)-1 })
  local hist_idx = #M.history

  insert_after(buf, #api.nvim_buf_get_lines(buf,0,-1,false)-1, { "[mensagem enviada]" })
  vim.notify("mensagem enviada", vim.log.levels.INFO)

  -- monta payload com contexto + histórico
  local messages = {}
  table.insert(messages, { role = "system", content = "Context:\n" .. (M.context_text or "") })
  for _, pair in ipairs(M.history) do
    table.insert(messages, { role = "user", content = pair.user })
    if pair.ai then table.insert(messages, { role = "assistant", content = pair.ai }) end
  end

  local json_payload = vim.fn.json_encode({ model = "codellama:7b-instruct", messages = messages })
  local stderr_accum = {}

  local cmd = { "curl", "-s", "-X", "POST", "http://127.0.0.1:11434/v1/chat/completions",
                "-H", "Content-Type: application/json", "-d", json_payload }

  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data, _)
      if not data then return end
      local result = table.concat(data, "\n")
      local ok, decoded = pcall(vim.fn.json_decode, result)
      if not ok or not decoded or not decoded.choices or not decoded.choices[1] then
        vim.schedule(function()
          vim.notify("Erro ao decodificar JSON:\n" .. result, vim.log.levels.ERROR)
        end)
        return
      end

      local ai_content = decoded.choices[1].message.content or ""
      ai_content = "## IA >> " .. ai_content
      M.history[hist_idx].ai = ai_content

      vim.schedule(function()
        local status_line_idx = M.history[hist_idx].status_line
        replace_line(buf, status_line_idx, { "[mensagem recebida]" })
        local ai_lines = split_lines(ai_content)
        api.nvim_buf_set_lines(buf, status_line_idx + 1, status_line_idx + 1, false, ai_lines)
        api.nvim_buf_set_lines(buf, -1, -1, false, { "", "## Nardi >> " })
        if M.popup_win and api.nvim_win_is_valid(M.popup_win) then
          api.nvim_win_set_cursor(M.popup_win, { api.nvim_buf_line_count(buf), #"## Nardi >> " })
        end
        vim.cmd("startinsert")
        vim.notify("mensagem recebida", vim.log.levels.INFO)
      end)
    end,
    on_stderr = function(_, data, _)
      if not data then return end
      for _, d in ipairs(data) do
        if d and d ~= "" then table.insert(stderr_accum, d) end
      end
    end,
    on_exit = function(_, code, _)
      if code ~= 0 then
        local errtext = table.concat(stderr_accum, "\n")
        vim.schedule(function()
          vim.notify("Request terminou com código " .. tostring(code) .. "\n" .. errtext, vim.log.levels.ERROR)
        end)
      end
    end,
  })
end

return M

