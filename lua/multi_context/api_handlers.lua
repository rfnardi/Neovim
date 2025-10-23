local M = {}

local function safe_json_encode(data)
	local ok, result = pcall(vim.fn.json_encode, data)
	if not ok then
		return nil, "Falha ao serializar JSON: " .. tostring(result)
	end
	return result, nil
end

M.openai = {
	make_request = function(api_config, messages, api_keys, callback)
		local json_payload, err = safe_json_encode({
			model = api_config.model,
			messages = messages
		})
		if not json_payload then
			callback(false, err)
			return
		end

		local headers = {}
		local api_key = api_keys[api_config.name] or "" -- Pega a chave uma vez

		for k, v in pairs(api_config.headers or {}) do
			local final_header_value = string.gsub(v, "{API_KEY}", api_key)
			table.insert(headers, "-H")
			table.insert(headers, k .. ": " .. final_header_value)
		end

		local cmd = vim.list_extend({"curl", "-s", "-X", "POST", api_config.url}, headers)
		table.insert(cmd, "-d")
		table.insert(cmd, json_payload)

		local stdout_accum = {}
		local stderr_accum = {}

		vim.fn.jobstart(cmd, {
			stdout_buffered = true,
			on_stdout = function(_, data, _)
				if data then
					for _, d in ipairs(data) do
						if d and d ~= "" then
							table.insert(stdout_accum, d)
						end
					end
				end
			end,
			on_stderr = function(_, data, _)
				if data then
					for _, d in ipairs(data) do
						if d and d ~= "" then
							table.insert(stderr_accum, d)
						end
					end
				end
			end,
			on_exit = function(_, code, _)
				if code == 0 then
					callback(true, table.concat(stdout_accum, "\n"))
				else
					callback(false, table.concat(stderr_accum, "\n"))
				end
			end
		})
	end,

	parse_response = function(response_text)
		local ok, decoded = pcall(vim.fn.json_decode, response_text)
		if not ok then
			return nil, "Erro ao decodificar JSON da resposta: " .. tostring(response_text)
		end

		if decoded.error then
			return nil, decoded.error.message or "Erro na API: " .. tostring(decoded.error)
		end

		if decoded.choices and decoded.choices[1] then
			local choice = decoded.choices[1]
			if choice.message and choice.message.content then
				return choice.message.content, nil
			end
		end

		if decoded.result then
			if type(decoded.result) == "string" then
				return decoded.result, nil
			elseif decoded.result.choices and decoded.result.choices[1] then
				local choice = decoded.result.choices[1]
				if choice.message and choice.message.content then
					return choice.message.content, nil
				end
			end
		end

		if decoded.content then
			return decoded.content, nil
		end

		return nil, "Estrutura de resposta não reconhecida: " .. vim.inspect(decoded)
	end
}

M.gemini = {
	make_request = function(api_config, messages, api_keys, callback)
		local gemini_messages = {}
		for _, msg in ipairs(messages) do
			table.insert(gemini_messages, {
				role = msg.role == "user" and "user" or "model",
				parts = {
					{
						text = msg.content
					}
				}
			})
		end

		local json_payload = vim.fn.json_encode({
			contents = gemini_messages
		})

		local headers = {}
		local api_key = api_keys[api_config.name] or ""
		for k, v in pairs(api_config.headers or {}) do
			local final_header_value = string.gsub(v, "{API_KEY}", api_key)
			table.insert(headers, "-H")
			table.insert(headers, k .. ": " .. final_header_value)
		end

		local cmd = vim.list_extend({"curl", "-s", "-X", "POST", api_config.url}, headers)
		table.insert(cmd, "-d")
		table.insert(cmd, json_payload)

		local stdout_accum = {}
		local stderr_accum = {}

		vim.fn.jobstart(cmd, {
			stdout_buffered = true,
			on_stdout = function(_, data, _)
				if data then
					for _, d in ipairs(data) do
						if d and d ~= "" then
							table.insert(stdout_accum, d)
						end
					end
				end
			end,
			on_stderr = function(_, data, _)
				if data then
					for _, d in ipairs(data) do
						if d and d ~= "" then
							table.insert(stderr_accum, d)
						end
					end
				end
			end,
			on_exit = function(_, code, _)
				if code == 0 then
					callback(true, table.concat(stdout_accum, "\n"))
				else
					callback(false, table.concat(stderr_accum, "\n"))
				end
			end
		})
	end,

	parse_response = function(response_text)
		local ok, decoded = pcall(vim.fn.json_decode, response_text)
		if not ok then
			return nil, "Erro ao decodificar JSON da resposta Gemini"
		end

		if decoded.error then
			return nil, decoded.error.message or "Erro na API Gemini"
		end

		if not decoded.candidates or not decoded.candidates[1] then
			return nil, "Resposta da Gemini sem candidatos"
		end

		local candidate = decoded.candidates[1]
		if not candidate.content or not candidate.content.parts or not candidate.content.parts[1] then
			return nil, "Estrutura de candidato inválida na resposta Gemini"
		end

		return candidate.content.parts[1].text or "", nil
	end
}

M.cloudflare = {
	make_request = function(api_config, messages, api_keys, callback)
		local json_payload = vim.fn.json_encode({
			messages = messages
		})

		local headers = {}
		local api_key = api_keys[api_config.name] or ""
		for k, v in pairs(api_config.headers or {}) do
			local final_header_value = string.gsub(v, "{API_KEY}", api_key)
			table.insert(headers, "-H")
			table.insert(headers, k .. ": " .. final_header_value)
		end

		local cmd = vim.list_extend({"curl", "-s", "-X", "POST", api_config.url}, headers)
		table.insert(cmd, "-d")
		table.insert(cmd, json_payload)

		local stdout_accum = {}
		local stderr_accum = {}

		vim.fn.jobstart(cmd, {
			stdout_buffered = true,
			on_stdout = function(_, data, _)
				if data then
					for _, d in ipairs(data) do
						if d and d ~= "" then
							table.insert(stdout_accum, d)
						end
					end
				end
			end,
			on_stderr = function(_, data, _)
				if data then
					for _, d in ipairs(data) do
						if d and d ~= "" then
							table.insert(stderr_accum, d)
						end
					end
				end
			end,
			on_exit = function(_, code, _)
				if code == 0 then
					callback(true, table.concat(stdout_accum, "\n"))
				else
					callback(false, table.concat(stderr_accum, "\n"))
				end
			end
		})
	end,

	parse_response = function(response_text)
		local ok, decoded = pcall(vim.fn.json_decode, response_text)
		if not ok or not decoded or not decoded.result then
			return nil, "Erro ao decodificar resposta Cloudflare"
		end
		return decoded.result.response or "", nil
	end
}

return M
