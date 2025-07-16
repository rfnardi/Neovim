"---------------------------------------------
" 				Plugins
"---------------------------------------------

call plug#begin()
Plug 'morhetz/gruvbox'                      " aparência/esquemas de cores
Plug 'terryma/vim-multiple-cursors'         " <C-n> procura palavras iguais e cria multiplos cursores
Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'preservim/nerdtree'
Plug 'tpope/vim-fugitive'                   " integração com o git 
" Plug 'pappasam/coc-jedi', { 'do': 'yarn install --frozen-lockfile && yarn build', 'branch': 'main' }
"
Plug 'dag/vim-fish'
Plug 'https://github.com/z3t0/arduvim'
Plug 'stevearc/vim-arduino'
Plug 'lervag/vimtex'
Plug 'plasticboy/vim-markdown'
Plug 'tpope/vim-surround'
Plug 'honza/vim-snippets'
Plug 'tpope/vim-commentary' 				" gcc comenta a linha , gc comenta seleção no modo visual, etc 
Plug 'eslint/eslint'
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
Plug 'rodrigore/coc-tailwind-intellisense', {'do': 'npm install'}
call plug#end()


" ao reinstalar o nvim, rodar o arquivo ./coc-extensoes.vim para habilitar o intelisense das
" linguagens do coc: :source ./coc-extensoes.vim


"---------------------------------------------
" 				Settings
"---------------------------------------------

" Sets fish as the shell:
:set shell=/bin/fish 

" seleção na lista do popupmenu com enter:
:inoremap <expr> <CR> pumvisible() ? "\<C-y>" : "\<C-g>u\<CR>"

colorscheme gruvbox
set background=dark

" augroup folding
"   au BufReadPre * setlocal foldmethod=indent
"   au BufWinEnter * if &fdm == 'indent' | setlocal foldmethod=manual | endif
" augroup END

" autocmd vimenter * NERDTree
" let g:NERDTreeGitStatusWithFlags = 1
"
let g:loaded_ruby_provider = 0 " não carrega o provedor de ruby (não uso isso)
let g:loaded_perl_provider = 0 " não carrega o provedor perl

set noswapfile
set hidden                  " permite abrir outro buffer mesmo sem salvar o arquivo atual

"set relativenumber
"set number                  " add line numbers

:set number relativenumber


set nocompatible 	        " disable compatibility to old-time vi
set showmatch 		        " show matching brackets
"set ignorecase 		        " case insensitive matching
set mouse=a                 " integração com o mouse para seleção     
set hlsearch                " highlight search results
set tabstop=2               " number of columns occupied by a tab character
set softtabstop=2           " see multiple spaces as tabstops so <BS> does the right thing
" set expandtab               " converts tabs to white space
set shiftwidth=2            " width for autoindento:
set autoindent              " indent a new line the same amount as the line just typed
set wildmode=longest,list   " get bash-like tab completions
set splitright              " abre uma split vertical sempre à direita do buffer atual

set exrc
set list
set listchars=tab:>\ ,trail:.		" mostra caracteres ocultos (tab, space, etc)

set statusline=%<%f\ %h%m%r%{FugitiveStatusline()}%=%-14.(%l,%c%V%)\ %P

set inccommand=split        " a busca com ' :%s/old ' cria um preview de todas as ocorrências de old no arquivo. tb funciona 
                                    " para a substituição ':%s/old/new '

filetype plugin indent on   " allows auto-indenting depending on file type
syntax on                   " syntax highlighting

"------------------------- vimtex configurations -----------------------

let g:tex_flavor = 'latex'
" syntax enable " to use vimtex properly (?)
" Viewer options: One may configure the viewer either by specifying a built-in
" viewer method:
let g:vimtex_view_method = 'zathura'

" Or with a generic interface:
let g:vimtex_view_general_viewer = 'okular'
let g:vimtex_view_general_options = '--unique file:@pdf\#src:@line@tex'

" VimTeX uses latexmk as the default compiler backend. If you use it, which is
" strongly recommended, you probably don't need to configure anything. If you
" want another compiler backend, you can change it as follows. The list of
" supported backends and further explanation is provided in the documentation,
" see ":help vimtex-compiler".
" let g:vimtex_compiler_method = 'latexrun'
let g:vimtex_compiler_method = 'latexmk'

" Most VimTeX mappings rely on localleader and this can be changed with the
" following line. The default is usually fine and is the symbol "\".
let maplocalleader = ","

" iniciando tikz picture com pacote tkz:
command Tkzinit normal i\tkzInit[xmin=0,xmax=10,ymin=0,ymax=6<esc>$o\tkzDrawX[noticks<esc>yypfXrY<esc>

" iniciando arquivo tex:
command Preambulo normal i\documentclass[a4paper,12pt<esc>$a{article}<esc>xo\usepackage[T1]<esc>x$a{fontenc<esc>yyp0f[lciwutf8<esc>f{lci{inputenc<esc>o\input{../../../preamb_files/preambulo_basics.tex<esc>yyp04f/lciwpreambulo_tikz_stuff<esc>yyp04f/lciwpreambulo_my_envrmts<esc><return>

"------------------------- vimtex configurations -----------------------




"---------------------------------------------
" 				Key-Mappings
"---------------------------------------------

".tmux.conf
nnoremap <A-t> :e ~/.tmux.conf<esc>

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

nnoremap <A-b> :Buffers<cr>
nnoremap <tab> i<tab>
nnoremap <A-s> :%s/
nnoremap <A-ç> :e ~/.config/nvim/init.vim <esc>
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

inoremap <A-q> \
inoremap <A-w> \|
