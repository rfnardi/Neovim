call plug#begin()
Plug 'morhetz/gruvbox'                      " aparência/esquemas de cores
Plug 'terryma/vim-multiple-cursors'         " <C-n> procura palavras iguais e cria multiplos cursores
Plug 'neoclide/coc.nvim', {'master': 'v0.0.78'}
Plug 'preservim/nerdtree'
Plug 'honza/vim-snippets'
call plug#end()

colorscheme gruvbox
set background=dark

autocmd vimenter * NERDTree

set hidden                  " permite abrir outro arquivo mesmo sem salvar o arquivo atual
set relativenumber
set nocompatible 	        " disable compatibility to old-time vi
set showmatch 		        " show matching brackets
"set ignorecase 		        " case insensitive matching
set mouse=a                 " integração com o mouse para seleção     
set hlsearch                " highlight search results
set tabstop=4               " number of columns occupied by a tab character
set softtabstop=4           " see multiple spaces as tabstops so <BS> does the right thing
set expandtab               " converts tabs to white space
set shiftwidth=4            " width for autoindento:
set autoindent              " indent a new line the same amount as the line just typed
set number                  " add line numbers
set wildmode=longest,list   " get bash-like tab completions
filetype plugin indent on   " allows auto-indenting depending on file type
syntax on                   " syntax highlighting

set inccommand=split        " a busca com ' :%s/old ' cria um preview de todas as ocorrências de old no arquivo. tb funciona 
                                    " para a substituição ':%s/old/new '

let mapleader="\<space>"
nnoremap <leader>; A;<esc>  " vai pro final da linha e digita ';'
nnoremap <leader>s :%s/     

