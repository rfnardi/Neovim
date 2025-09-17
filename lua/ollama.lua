local M = {}

local function escape_json(str)
  str = str:gsub("\\", "\\\\")
  str = str:gsub('"', '\\"')
  str = str:gsub("\n", "\\n")
  return str
end

function M.OllamaVisual()
  local start_pos = vim.api.nvim_buf_get_mark(0, "<")
  local end_pos   = vim.api.nvim_buf_get_mark(0, ">")

  local start_line, start_col = start_pos[1], start_pos[2]
  local end_line,   end_col   = end_pos[1], end_pos[2]

  -- garante ordem correta
  if start_line > end_line or (start_line == end_line and start_col > end_col) then
    start_line, end_line = end_line, start_line
    start_col,  end_col  = end_col,  start_col
  end

  -- pega linhas da seleção
  local lines = vim.api.nvim_buf_get_lines(0, start_line-1, end_line, false)
  if #lines == 0 then return end

  -- ajusta end_col para não exceder última linha
  local last_line_len = #lines[#lines]
  if end_col >= last_line_len then
    end_col = last_line_len
  end

  local text = table.concat(lines, "\n")

  -- chama API Ollama
  local cmd = string.format([[
curl -s -X POST http://127.0.0.1:11434/v1/chat/completions \
-H "Content-Type: application/json" \
-d '{"model":"codellama:7b-instruct","messages":[{"role":"user","content":"%s"}]}'
]], escape_json(text))

  local handle = io.popen(cmd)
  if not handle then
    vim.notify("Erro ao chamar Ollama", vim.log.levels.ERROR)
    return
  end

  local result = handle:read("*a")
  handle:close()

  local ok, data = pcall(vim.fn.json_decode, result)
  if not ok or not data.choices or not data.choices[1] then
    vim.notify("Erro ao decodificar JSON:\n"..result, vim.log.levels.ERROR)
    return
  end

  local answer = data.choices[1].message.content or ""
  answer = answer:gsub("^%s+", ""):gsub("%s+$", "")

  -- substitui seleção
  vim.api.nvim_buf_set_text(
    0,
    start_line-1, start_col,
    end_line-1, end_col,
    vim.split(answer, "\n")
  )

  vim.notify("Resposta inserida com sucesso!", vim.log.levels.INFO)
end

vim.api.nvim_set_keymap(
  "v",
  "<A-g>",
  ":lua require('ollama').OllamaVisual()<CR>",
  { noremap=true, silent=true }
)

return M

