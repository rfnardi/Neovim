"sets the key for api
let g:api_key = "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"

" Define a function to get the prompt from the command mode
function! GetPrompt()
  let prompt = execute('echo @')
  return prompt
endfunction

" Define a function to insert the generated text or code into the current buffer
function! InsertGeneratedText(text)
  " Get the current line and column
  let line = line('.')
  let column = col('.')

  " Insert the text at the current line and column
  call setline(line, getline(line)[:column-1] . a:text . getline(line)[column-1:])

  " Update the cursor position
  call cursor(line, column + strlen(a:text))
endfunction

" Define a command to send the prompt to the chatgpt API and insert the generated text or code
command! ChatGPT call InsertGeneratedText(system("curl -X POST -H 'Authorization: Bearer '" . g:api_key ." -d 'prompt='" . GetPrompt() .  "'https://api.chatgpt.com'"))

