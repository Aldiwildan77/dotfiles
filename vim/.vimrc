" Enable syntax highlighting and filetype plugins
syntax on
filetype plugin indent on

set encoding=utf-8

" Set tab width and use spaces instead of tabs
set tabstop=4
set shiftwidth=4
set expandtab

set number
set mouse=a
set relativenumber

" Search settings
set ignorecase
set smartcase
set incsearch

" Enable persistent undo (requires a directory ~/.vim/undodir)
if has("persistent_undo")
    set undofile
    set undodir=~/.vim/undodir
endif

" Plugin management with vim-plug (install vim-plug if you haven't already)
if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin('~/.vim/plugged')

" List your plugins here
Plug 'tpope/vim-sensible'
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }

call plug#end()

" Custom key mappings
nnoremap <C-s> :w<CR>
