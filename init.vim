call plug#begin()
Plug 'morhetz/gruvbox'                      " aparência/esquemas de cores
Plug 'terryma/vim-multiple-cursors'         " <C-n> procura palavras iguais e cria multiplos cursores
Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'preservim/nerdtree'
Plug 'tpope/vim-fugitive'                   " integração com o git 
"Plug 'davidhalter/jedi-vim'
Plug 'lervag/vimtex'
Plug 'plasticboy/vim-markdown'
Plug 'tpope/vim-surround'
Plug 'honza/vim-snippets'
Plug 'tpope/vim-commentary'					" gcc comenta a linha , gc comenta seleção no modo visual, etc 
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
call plug#end()


" ao reinstalar o nvim, rodar estes comandos para habilitar o intelisense das
" linguagens do coc:
" 
":CocInstall coc-texlab
":CocInstall coc-html
":CocInstall coc-clangd
":CocInstall coc-cmake
":CocInstall coc-json
":CocInstall coc-python
":CocInstall coc-sh
":CocInstall coc-tsserver
":CocInstall coc-snippets

colorscheme gruvbox
set background=dark

" autocmd vimenter * NERDTree
" let g:NERDTreeGitStatusWithFlags = 1

:set noswapfile
set hidden                  " permite abrir outro buffer mesmo sem salvar o arquivo atual

"set relativenumber
"set number                  " add line numbers

:set number relativenumber

:augroup numbertoggle
:  autocmd!
:  autocmd BufEnter,FocusGained,InsertLeave * set relativenumber
:  autocmd BufLeave,FocusLost,InsertEnter   * set norelativenumber
:augroup END

":verbose imap <tab> # to make sure keymap for coc-nvim take effect

" GoTo code navigation:
" Ctrl + o goes back
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

let g:tex_flavor = 'latex'

set nocompatible 	        " disable compatibility to old-time vi
set showmatch 		        " show matching brackets
"set ignorecase 		        " case insensitive matching
set mouse=a                 " integração com o mouse para seleção     
set hlsearch                " highlight search results
set tabstop=4               " number of columns occupied by a tab character
set softtabstop=4           " see multiple spaces as tabstops so <BS> does the right thing
"set expandtab               " converts tabs to white space
set shiftwidth=4            " width for autoindento:
set autoindent              " indent a new line the same amount as the line just typed
set wildmode=longest,list   " get bash-like tab completions
set splitright              " abre uma split vertical sempre à direita do buffer atual


set statusline=%<%f\ %h%m%r%{FugitiveStatusline()}%=%-14.(%l,%c%V%)\ %P

filetype plugin indent on   " allows auto-indenting depending on file type
syntax on                   " syntax highlighting

set inccommand=split        " a busca com ' :%s/old ' cria um preview de todas as ocorrências de old no arquivo. tb funciona 
                                    " para a substituição ':%s/old/new '

"let mapleader="\<space>"
"
"insere um espaço e volta pro modo normal
nnoremap <space> a<space><esc>

"***************************************************
"wrapping seleção com chaves, parênteses e colchetes:
"circunda o texto selecionado no modo visual com ()
vnoremap <A-(> di()<esc>hp

"circunda o texto selecionado no modo visual com {}
vnoremap <A-{> di{}<esc>hp

"circunda o texto selecionado no modo visual com []
vnoremap <A-[> di[]<esc>hp

"completamento de brackets:
inoremap ( ()<esc>i
inoremap { {}<esc>i
inoremap [ []<esc>i
inoremap " ""<esc>i
inoremap ' ''<esc>i
"***************************************************

" insere uma linha vazia abaixo da atual e volta para o modo normal:
nnoremap <return> o<esc>

" yanks till the end of line:
nnoremap Y y$

" keeping it centered while moving around between matches:
nnoremap n nzzza
nnoremap N Nzzza
nnoremap J mzJ`z

"vai pro final da linha e digita ';'
nnoremap <A-;> A;<esc>

nnoremap <tab> i<tab>
nnoremap <A-s> :%s/
nnoremap <A-ç> :vs ~/.config/nvim/init.vim <esc>
nnoremap <A-[> :NERDTreeToggle <esc>

" grava as folds para serem carregadas na próxima vez com o arquivo for aberto 
nnoremap <A-m> :mkview<esc>

" carrega as folds gravadas com o :makeview 
nnoremap <A-l> :silent! loadview<esc>

" mudança entre janelas
nnoremap <A-,> <C-w>h
nnoremap <A-.> <C-w>l
nnoremap <C-l> <C-w>j
nnoremap <C-p> <C-w>k

" Ctrl + c : copia para o registrador +:
vnoremap <C-c> "+y

" movimentação entre buffers:
nnoremap <A-j> :bp<return>
nnoremap <A-k> :bn<return>

" sair do modo terminal:
tnoremap <A-e> <C-\><C-n>

" fuzzy finder:
nnoremap <A-f> :Files<CR>
