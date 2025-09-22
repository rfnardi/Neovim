" Vim syntax file
" Language: chat
" Maintainer: Rafael Nardi
" Latest Revision: 2025-09-21

if exists("b:current_syntax")
  finish
endif

" Comandos de highlight
syntax match chatHeader "^===\|^=="
syntax match chatUserPrompt "^## Nardi >>"
syntax match chatAIResponse "^## IA (.*) >>"
syntax match chatMessageStatus "\[mensagem enviada\]\|\[mensagem recebida\]"
syntax match chatCurrentBuffer "## buffer atual ##"

" Títulos (linhas que começam com #)
syntax match chatTitle "^# .*"

" Negrito: **texto**
syntax region chatBold start="\*\*" end="\*\*" oneline
" Itálico: *texto* ou _texto_
syntax region chatItalic start="\*" end="\*" oneline
syntax region chatItalic start="_" end="_" oneline

" Blocos de código: ```linguagem ... ```
syntax region chatCodeBlock start="^```.*$" end="^```$" contains=chatCodeBlockStart,chatCodeBlockEnd
syntax match chatCodeBlockStart "^```.*$" contained
syntax match chatCodeBlockEnd "^```$" contained

" Links: [texto](url)
syntax region chatLink matchgroup=chatLinkBracket start="\[" end="\]" contained oneline nextgroup=chatLinkURL
syntax region chatLinkURL matchgroup=chatLinkParen start="(" end=")" contained

" Definindo os highlights
highlight def link chatHeader Title
highlight def link chatUserPrompt Identifier
highlight def link chatAIResponse Function
highlight def link chatMessageStatus Comment
highlight def link chatCurrentBuffer Special

highlight def link chatTitle Label

highlight def chatBold term=bold cterm=bold gui=bold
highlight def chatItalic term=italic cterm=italic gui=italic

highlight def link chatCodeBlockStart PreProc
highlight def link chatCodeBlockEnd PreProc
highlight def link chatCodeBlock String

highlight def link chatLinkBracket Underlined
highlight def link chatLinkParen Underlined
highlight def link chatLink Underlined

let b:current_syntax = "chat"
