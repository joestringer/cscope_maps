""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" CSCOPE settings for vim
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"
" This file contains some boilerplate settings for vim's cscope interface,
" plus some keyboard mappings that I've found useful.
"
" USAGE:
" -- vim 6:     Stick this file in your ~/.vim/plugin directory (or in a
"               'plugin' directory in some other directory that is in your
"               'runtimepath'.
"
" -- vim 5:     Stick this file somewhere and 'source cscope.vim' it from
"               your ~/.vimrc file (or cut and paste it into your .vimrc).
"
" NOTE:
" These key maps use multiple keystrokes (2 or 3 keys).  If you find that vim
" keeps timing you out before you can complete them, try changing your timeout
" settings, as explained below.
"
" Happy cscoping,
"
" Jason Duell       jduell@alumni.princeton.edu     2002/3/7
"
" HISTORY:
"
" Christian Ludwig  chrissicool@gmail.com           2014/3/2
"
"  - Use autocmd to automatically find cscope.out from buffer's initial
"    directory up to 1 level before root.
"  - Change directory to cscope.out dir for the current buffer. Otherwise
"    paths to tags are broken.
"  - Maintain all loaded cscope.out files.
"
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""


" This tests to see if vim was configured with the '--enable-cscope' option
" when it was compiled.  If it wasn't, time to recompile vim...
if !has("cscope")
    finish
endif

" guard against multiple loads
if (exists("g:loaded_cscope_maps"))
    finish
endif
let g:loaded_cscope_maps = 1

if (!exists("g:cscope_maps_debug"))
    let g:cscope_maps_debug = 0
endif

""""""""""""" Standard cscope/vim boilerplate

" use both cscope and ctag for 'ctrl-]', ':ta', and 'vim -t'
set cscopetag

" check cscope for definition of a symbol before checking ctags: set to 1
" if you want the reverse search order.
set csto=0

" show msg when any other cscope db added
set nocscopeverbose

" setup auto commands
if has("autocmd")
    augroup cscope_maps
        autocmd!

        " Find cscope.out base dir and change to it when entering a buffer.
        autocmd BufEnter * call s:Cscope_maps_find()
    augroup END
else
    " add any cscope database in current directory
    if filereadable("cscope.out")
        cs add cscope.out
    " else add the database pointed to by environment variable
    elseif $CSCOPE_DB != ""
        cs add $CSCOPE_DB
    endif
endif

" Find the corresponding cscope.out database file for the current buffer.
" Load the database if it was not loaded, yet.
" Loading strategy:
"  1. $CSCOPE_OUT (shell) environment variable
"  2. last successfully loaded database
"  3. iterate over all directories from the current buffer's up
function! s:Cscope_maps_find()
    call s:Cscope_maps_debug(1, "Find cscope.out.")

    " only consider normal buffers (skip especially CommandT's GoToFile buffer)
    if (&buftype != "")
        return
    endif

    if $CSCOPE_DB != ""
        let b:cscope_path = fnameescape(expand("$CSCOPE_DB", ":p:h"))
        call s:Cscope_maps_debug(2, "From environment: " . b:cscope_path)
    endif

    if exists("b:cscope_path") && filereadable(b:cscope_path . "/cscope.out")
        call s:Cscope_maps_debug(2, "Fast path: " . b:cscope_path)
        call s:Cscope_maps_setdb(b:cscope_path)
        return
    endif

    call s:Cscope_maps_debug(2, "Slow path...")

    let l:modifiers = ":p:h"
    let b:cscope_path = fnameescape(expand("%" . l:modifiers))

    while b:cscope_path != "/"
        call s:Cscope_maps_debug(3, "Trying: " . b:cscope_path)
        if filereadable(b:cscope_path . "/cscope.out")
            call s:Cscope_maps_setdb(b:cscope_path)
            return
        endif
        let l:modifiers = l:modifiers . ":h"
        let b:cscope_path = fnameescape(expand("%" . l:modifiers))
    endwhile

    unlet b:cscope_path
endfunction

" Set the cscope.out database file found in db_path.
" Maintain a list of all loaded databases. Do not load a database twice.
" Always cd into the directory the database is in for consistent tags.
function! s:Cscope_maps_setdb(db_path)
    let l:cscope_db = a:db_path . "/cscope.out"

    if exists("s:cscope_dbs")
        if exists("s:cscope_dbs[l:cscope_db]")
            call s:Cscope_maps_debug(4, "Existing DB: " . l:cscope_db)
            execute "cd! " . a:db_path
            return
        endif
    else
        call s:Cscope_maps_debug(4, "Adding first DB")
        let s:cscope_dbs = {}
    endif

    call s:Cscope_maps_debug(4, "Adding DB: " . l:cscope_db)
    let s:cscope_dbs[l:cscope_db] = 1
    execute "cd! " . a:db_path
    execute "cs add " . l:cscope_db
endfunction

function! s:Cscope_maps_debug(level, text)
    if (g:cscope_maps_debug >= a:level)
        echom "cscope_maps: " . a:text
    endif
endfunction

""""""""""""" My cscope/vim key mappings
"
" The following maps all invoke one of the following cscope search types:
"
"   's'   symbol: find all references to the token under cursor
"   'g'   global: find global definition(s) of the token under cursor
"   'c'   calls:  find all calls to the function name under cursor
"   't'   text:   find all instances of the text under cursor
"   'e'   egrep:  egrep search for the word under cursor
"   'f'   file:   open the filename under cursor
"   'i'   includes: find files that include the filename under cursor
"   'd'   called: find functions that function under cursor calls
"
" Below are three sets of the maps: one set that just jumps to your
" search result, one that splits the existing vim window horizontally and
" diplays your search result in the new window, and one that does the same
" thing, but does a vertical split instead (vim 6 only).
"
" I've used CTRL-\ and CTRL-@ as the starting keys for these maps, as it's
" unlikely that you need their default mappings (CTRL-\'s default use is
" as part of CTRL-\ CTRL-N typemap, which basically just does the same
" thing as hitting 'escape': CTRL-@ doesn't seem to have any default use).
" If you don't like using 'CTRL-@' or CTRL-\, , you can change some or all
" of these maps to use other keys.  One likely candidate is 'CTRL-_'
" (which also maps to CTRL-/, which is easier to type).  By default it is
" used to switch between Hebrew and English keyboard mode.
"
" All of the maps involving the <cfile> macro use '^<cfile>$': this is so
" that searches over '#include <time.h>" return only references to
" 'time.h', and not 'sys/time.h', etc. (by default cscope will return all
" files that contain 'time.h' as part of their name).


" To do the first type of search, hit 'CTRL-\', followed by one of the
" cscope search types above (s,g,c,t,e,f,i,d).  The result of your cscope
" search will be displayed in the current window.  You can use CTRL-T to
" go back to where you were before the search.
"

nmap <C-\>s :cs find s <C-R>=expand("<cword>")<CR><CR>
nmap <C-\>g :cs find g <C-R>=expand("<cword>")<CR><CR>
nmap <C-\>c :cs find c <C-R>=expand("<cword>")<CR><CR>
nmap <C-\>t :cs find t <C-R>=expand("<cword>")<CR><CR>
nmap <C-\>e :cs find e <C-R>=expand("<cword>")<CR><CR>
nmap <C-\>f :cs find f <C-R>=expand("<cfile>")<CR><CR>
nmap <C-\>i :cs find i ^<C-R>=expand("<cfile>")<CR>$<CR>
nmap <C-\>d :cs find d <C-R>=expand("<cword>")<CR><CR>


" Using 'CTRL-spacebar' (intepreted as CTRL-@ by vim) then a search type
" makes the vim window split horizontally, with search result displayed in
" the new window.
"
" (Note: earlier versions of vim may not have the :scs command, but it
" can be simulated roughly via:
"    nmap <C-@>s <C-W><C-S> :cs find s <C-R>=expand("<cword>")<CR><CR>

nmap <C-]>s :scs find s <C-R>=expand("<cword>")<CR><CR>
nmap <C-]>g :scs find g <C-R>=expand("<cword>")<CR><CR>
nmap <C-]>c :scs find c <C-R>=expand("<cword>")<CR><CR>
nmap <C-]>t :scs find t <C-R>=expand("<cword>")<CR><CR>
nmap <C-]>e :scs find e <C-R>=expand("<cword>")<CR><CR>
nmap <C-]>f :scs find f <C-R>=expand("<cfile>")<CR><CR>
nmap <C-]>i :scs find i ^<C-R>=expand("<cfile>")<CR>$<CR>
nmap <C-]>d :scs find d <C-R>=expand("<cword>")<CR><CR>


" Hitting CTRL-space *twice* before the search type does a vertical
" split instead of a horizontal one (vim 6 and up only)
"
" (Note: you may wish to put a 'set splitright' in your .vimrc
" if you prefer the new window on the right instead of the left

nmap <C-]><C-]>s :vert scs find s <C-R>=expand("<cword>")<CR><CR>
nmap <C-]><C-]>g :vert scs find g <C-R>=expand("<cword>")<CR><CR>
nmap <C-]><C-]>c :vert scs find c <C-R>=expand("<cword>")<CR><CR>
nmap <C-]><C-]>t :vert scs find t <C-R>=expand("<cword>")<CR><CR>
nmap <C-]><C-]>e :vert scs find e <C-R>=expand("<cword>")<CR><CR>
nmap <C-]><C-]>f :vert scs find f <C-R>=expand("<cfile>")<CR><CR>
nmap <C-]><C-]>i :vert scs find i ^<C-R>=expand("<cfile>")<CR>$<CR>
nmap <C-]><C-]>d :vert scs find d <C-R>=expand("<cword>")<CR><CR>


""""""""""""" key map timeouts
"
" By default Vim will only wait 1 second for each keystroke in a mapping.
" You may find that too short with the above typemaps.  If so, you should
" either turn off mapping timeouts via 'notimeout'.
"
"set notimeout
"
" Or, you can keep timeouts, by uncommenting the timeoutlen line below,
" with your own personal favorite value (in milliseconds):
"
"set timeoutlen=4000
"
" Either way, since mapping timeout settings by default also set the
" timeouts for multicharacter 'keys codes' (like <F1>), you should also
" set ttimeout and ttimeoutlen: otherwise, you will experience strange
" delays as vim waits for a keystroke after you hit ESC (it will be
" waiting to see if the ESC is actually part of a key code like <F1>).
"
"set ttimeout
"
" personally, I find a tenth of a second to work well for key code
" timeouts. If you experience problems and have a slow terminal or network
" connection, set it higher.  If you don't set ttimeoutlen, the value for
" timeoutlent (default: 1000 = 1 second, which is sluggish) is used.
"
"set ttimeoutlen=100

" vim: expandtab shiftwidth=4 softtabstop=4
