" ============================================================================
" Editor behaviour
" ============================================================================

" Enable basic syntax configurations
syntax on
filetype plugin indent on

set encoding=utf-8
set nocompatible

" Indentation
set tabstop=4
set shiftwidth=4
set softtabstop=4
set expandtab
set autoindent
set smartindent

" Line numbers and cursor
set number
set relativenumber
set cursorline
set mouse=a
set scrolloff=5

" Search
set ignorecase
set smartcase
set incsearch
set hlsearch

" Splits open where you expect them
set splitbelow
set splitright

" Persistent undo, so undo history survives closing the file
if has("persistent_undo")
  if !isdirectory($HOME . "/.vim/undodir")
    call mkdir($HOME . "/.vim/undodir", "p", 0700)
  endif
  set undofile
  set undodir=~/.vim/undodir
endif

" Don't litter the working tree with swap and backup files
set noswapfile
set nobackup
set nowritebackup

" ============================================================================
" Appearance — Flexoki Dark
"
" Defined inline rather than pulled in as a colorscheme plugin, so a bare vim
" on a fresh server looks right with nothing installed beyond this file.
" Matches the yazi flavor in yazi/.config/yazi/theme.toml.
" ============================================================================

" Enable True Color support for modern terminals
set termguicolors
set background=dark

" Define a clean base colorscheme template before applying overrides
colorscheme default

" --- FLEXOKI DARK PALETTE DEFINITION ---
" Base background and text
highlight Normal       guibg=#100F0F guifg=#CECDC3
highlight NonText      guibg=#100F0F guifg=#575653
highlight CursorLine   guibg=#1C1B1A

" Core Syntax Highlights (Analog Inks)
highlight Comment      guifg=#6F6E69 gui=italic
highlight Constant     guifg=#4385BE
highlight String       guifg=#879A39
highlight Character    guifg=#879A39
highlight Number       guifg=#D0A215
highlight Boolean      guifg=#DA702C

" Structure and Execution (Go & Python keywords)
highlight Identifier   guifg=#CECDC3 gui=NONE
highlight Function     guifg=#4385BE
highlight Statement    guifg=#D14D41 gui=NONE
highlight Conditional  guifg=#D14D41
highlight Repeat       guifg=#D14D41
highlight Label        guifg=#D14D41
highlight Operator     guifg=#3AA99F
highlight Keyword      guifg=#D14D41

" Types and Metadata
highlight PreProc      guifg=#8B7EC8
highlight Type         guifg=#3AA99F gui=NONE
highlight Special      guifg=#DA702C
highlight Todo         guibg=#D0A215 guifg=#100F0F gui=bold

" UI Elements
highlight LineNr       guibg=#100F0F guifg=#575653
highlight CursorLineNr guibg=#1C1B1A guifg=#CECDC3
highlight Visual       guibg=#343331

" Search highlighting, kept inside the same palette
highlight Search       guibg=#D0A215 guifg=#100F0F
highlight IncSearch    guibg=#DA702C guifg=#100F0F

" Force the statusline to always be visible
set laststatus=2

" Set the statusline divider character to a clean horizontal line
set fillchars=stl:─,stlnc:─

" --- TRUE TRANSPARENT STATUSLINE & BORDERS ---
" Reset default themes from overriding transparency rules
highlight clear StatusLine
highlight clear StatusLineNC
highlight clear StatusLineTerm
highlight clear StatusLineTermNC
highlight clear VertSplit

" Re-apply transparent properties without color-flipping attributes
highlight StatusLine       guibg=NONE ctermbg=NONE guifg=#878681 term=NONE cterm=NONE gui=NONE
highlight StatusLineNC     guibg=NONE ctermbg=NONE guifg=#575653 term=NONE cterm=NONE gui=NONE
highlight StatusLineTerm   guibg=NONE ctermbg=NONE guifg=#878681 term=NONE cterm=NONE gui=NONE
highlight StatusLineTermNC guibg=NONE ctermbg=NONE guifg=#575653 term=NONE cterm=NONE gui=NONE
highlight VertSplit        guibg=NONE ctermbg=NONE guifg=#575653 term=NONE cterm=NONE gui=NONE

" --- CUSTOM STATUSLINE LAYOUT ---
set statusline=%#StatusLine#\ %f\ %m%r%=%y\ %l/%L,%c\

" ============================================================================
" Filetype overrides
" ============================================================================

" Go uses tabs; config and web files use two spaces.
autocmd FileType go setlocal noexpandtab tabstop=4 shiftwidth=4
autocmd FileType yaml,json,html,css,scss,javascript,typescript,terraform
      \ setlocal tabstop=2 shiftwidth=2 softtabstop=2
autocmd FileType make setlocal noexpandtab

" ============================================================================
" Key mappings
" ============================================================================

let mapleader = " "

nnoremap <C-s> :w<CR>
nnoremap <leader><space> :nohlsearch<CR>
nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>

" Move between splits without the leading <C-w>
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" Keep the selection after indenting
vnoremap < <gv
vnoremap > >gv
