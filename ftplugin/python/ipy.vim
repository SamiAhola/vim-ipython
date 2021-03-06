" Vim integration with IPython 0.11+
"
" A two-way integration between Vim and IPython.
"
" Using this plugin, you can send lines or whole files for IPython to execute,
" and also get back object introspection and word completions in Vim, like
" what you get with: object?<enter> object.<tab> in IPython
"
" -----------------
" Quickstart Guide:
" -----------------
" Start `ipython qtconsole`, `ipython console`, or  `ipython notebook` and
" open a notebook using you web browser.  Source this file, which provides new
" IPython command
"
"   :source ipy.vim
"   :IPython
"
" written by Paul Ivanov (http://pirsquared.org)
"
if !(has('python') || has('python3'))
    " exit if python is not available.
    " XXX: raise an error message here
    finish
endif

if has('python3') && get(g:, 'pymode_python', '') !=# 'python'
  command! -range -nargs=1 Python2or3 <line1>,<line2>python3 <args>
  Python2or3 PY3 = True
  function! IPythonPyeval(arg)
    return py3eval(a:arg)
  endfunction
else
  command! -range -nargs=1 Python2or3 <line1>,<line2>python <args>
  Python2or3 PY3 = False
  function! IPythonPyeval(arg)
    return pyeval(a:arg)
  endfunction
endif

" Allow custom mappings.
if !exists('g:ipy_perform_mappings')
    let g:ipy_perform_mappings = 1
endif

if !exists('g:ipython_dictionary_completion')
    let g:ipython_dictionary_completion = 0
endif
if !exists('g:ipython_greedy_matching')
    let g:ipython_greedy_matching = 0
endif

" Use -i with %run magic by default
if !exists('g:ipython_run_flags')
    let g:ipython_run_flags = '-i'
endif

" Automatically run :IPython in python files after running :IPython the first
" time
if !exists('g:ipy_autostart')
    let g:ipy_autostart = 1
endif

" Register IPython completefunc
" 'global'   -- for all of vim (default).
" 'local'    -- only for the current buffer.
" 'omni'     -- set omnifunc for current buffer.
" otherwise  -- don't register it at all.
"
" you can later set it using ':set completefunc=CompleteIPython', which will
" correspond to the 'global' behavior, or with ':setl ...' to get the 'local'
" behavior
if !exists('g:ipy_completefunc')
    let g:ipy_completefunc = 'local'
endif

Python2or3 << endpython
import vim
import sys
import itertools as it
import operator as op
vim_ipython_path = vim.eval("expand('<sfile>:h')")
sys.path.append(vim_ipython_path)
from vim_ipython import *

class Result(object):
    pass
endpython

fun! <SID>toggle_send_on_save()
    if exists("s:ssos") && s:ssos == 0
        let s:ssos = 1
        au BufWritePost *.py :Python2or3 run_this_file()
        echo "Autosend On"
    else
        let s:ssos = 0
        au! BufWritePost *.py
        echo "Autosend Off"
    endif
endfun

augroup vim-ipython
    autocmd!
    au FileType python IPython
    " Update the vim-ipython shell when the cursor is not moving.
    " You can change how quickly this happens after you stop moving the cursor by
    " setting 'updatetime' (in milliseconds). For example, to have this event
    " trigger after 1 second:
    "
    "       :set updatetime 1000
    "
    " NOTE: This will only be triggered once, after the first 'updatetime'
    " milliseconds, *not* every 'updatetime' milliseconds. see :help CursorHold
    " for more info.
    "
    " TODO: Make this easily configurable on the fly, so that an introspection
    " buffer we may have opened up doesn't get closed just because of an idle
    " event (i.e. user pressed \d and then left the buffer that popped up, but
    " expects it to stay there).
    au CursorHold *.*,vim-ipython :Python2or3 if update_subchannel_msgs(): echo("vim-ipython shell updated (on idle)",'Operator')

    " XXX: broken - cursor hold update for insert mode moves the cursor one
    " character to the left of the last character (update_subchannel_msgs must be
    " doing this)
    "au CursorHoldI *.* :Python2or3 if update_subchannel_msgs(): echo("vim-ipython shell updated (on idle)",'Operator')

    " Same as above, but on regaining window focus (mostly for GUIs)
    au FocusGained *.*,vim-ipython :Python2or3 if update_subchannel_msgs(): echo("vim-ipython shell updated (on input focus)",'Operator')

    " Update vim-ipython buffer when we move the cursor there. A message is only
    " displayed if vim-ipython buffer has been updated.
    au BufEnter vim-ipython :Python2or3 if update_subchannel_msgs(): echo("vim-ipython shell updated (on buffer enter)",'Operator')
augroup END

" Setup plugin mappings for the most common ways to interact with ipython.
noremap  <Plug>(IPython-RunFile)            :update<CR>:Python2or3 run_this_file()<CR>
noremap  <Plug>(IPython-RunLine)            :Python2or3 run_this_line()<CR>
noremap  <Plug>(IPython-RunLines)           :Python2or3 run_these_lines()<CR>
noremap  <Plug>(IPython-OpenPyDoc)          :Python2or3 get_doc_buffer()<CR>
noremap  <Plug>(IPython-UpdateShell)        :Python2or3 if update_subchannel_msgs(force=True): echo("vim-ipython shell updated",'Operator')<CR>
noremap  <Plug>(IPython-ToggleReselect)     :Python2or3 toggle_reselect()<CR>
noremap  <Plug>(IPython-ToggleSendOnSave)   :call <SID>toggle_send_on_save()<CR>
noremap  <Plug>(IPython-PlotClearCurrent)   :Python2or3 run_command("plt.clf()")<CR>
noremap  <Plug>(IPython-PlotCloseAll)       :Python2or3 run_command("plt.close('all')")<CR>
noremap  <Plug>(IPython-RunLineAsTopLevel)  :Python2or3 dedent_run_this_line()<CR>
xnoremap <Plug>(IPython-RunLinesAsTopLevel) :Python2or3 dedent_run_these_lines()<CR>

function! s:DoMappings()
    let b:did_ipython = 1
    if g:ipy_perform_mappings != 0
       if &buftype == ''
        map  <buffer> <silent> <F5>           <Plug>(IPython-RunFile)
       endif
        map  <buffer> <silent> ,d             <Plug>(IPython-OpenPyDoc)
        map  <buffer> <silent> <M-r>          <Plug>(IPython-UpdateShell)
        map  <buffer> <silent> <S-F9>         <Plug>(IPython-ToggleReselect)
        map  <buffer>          <C-F5>         <Plug>(IPython-ToggleSendOnSave)
        "" Example of how to quickly clear the current plot with a keystroke
        "map  <buffer> <silent> <F12>          <Plug>(IPython-PlotClearCurrent)
        "" Example of how to quickly close all figures with a keystroke
        "map  <buffer> <silent> <F11>          <Plug>(IPython-PlotCloseAll)

        "pi custom
        map  <buffer> <silent> <C-Return>        <Plug>(IPython-RunFile)
        map  <buffer> <silent> <C-s>          <Plug>(IPython-RunLine)
        imap <buffer> <silent> <C-s>          <C-o><Plug>(IPython-RunLine)
        map  <buffer> <silent> <M-s>          <Plug>(IPython-RunLineAsTopLevel)
        xmap <buffer> <silent> <C-S>          <Plug>(IPython-RunLines)
        xmap <buffer> <silent> <M-s>          <Plug>(IPython-RunLinesAsTopLevel)

        " noremap  <buffer> <silent> <M-c>      I#<ESC>
        " xnoremap <buffer> <silent> <M-c>      I#<ESC>
        " noremap  <buffer> <silent> <M-C>      :s/^\([ \t]*\)#/\1/<CR>
        " xnoremap <buffer> <silent> <M-C>      :s/^\([ \t]*\)#/\1/<CR>

        nnoremap <buffer> <C-c> :<C-u>IPythonInterrupt<CR>
        inoremap <buffer> <Leader>K <Esc>:<C-u>call <SID>GetDocBuffer()<CR>
    endif

    augroup vim_ipython_autostart
        autocmd!
        autocmd BufEnter,BufNewFile *.py,--Python-- if g:ipy_autostart && !exists('b:did_ipython')
            \ | call s:DoMappings() | endif
        autocmd FileType python if g:ipy_autostart && !exists('b:did_ipython')
            \ | call s:DoMappings() | endif
    augroup END

    setlocal completefunc=CompleteIPython
endfunction

function! s:GetDocBuffer()
    python get_doc_buffer()
    nnoremap <buffer> <silent> gi ZQ:undojoin<bar>startinsert!<CR>
    nnoremap <buffer> <silent> q ZQ:undojoin<bar>startinsert!<CR>
    nnoremap <buffer> <silent> ` <C-w>p:if winheight(0)<30<bar>res 30<bar>endif<bar>undojoin<bar>startinsert!<CR>
endfunction

command! -nargs=* IPython :call <SID>DoMappings()|:Python2or3 km_from_string("<args>")
command! -nargs=0 IPythonClipboard :Python2or3 km_from_string(vim.eval('@+'))
command! -nargs=0 IPythonXSelection :Python2or3 km_from_string(vim.eval('@*'))
command! -nargs=* IPythonNew :Python2or3 new_ipy("<args>")
command! -nargs=* IPythonInterrupt :Python2or3 interrupt_kernel_hack("<args>")
command! -nargs=0 IPythonTerminate :Python2or3 terminate_kernel_hack()

function! IPythonBalloonExpr()
Python2or3 << endpython
word = vim.eval('v:beval_text')
reply = get_doc(word)
vim.command("let l:doc = %s"% reply)
endpython
return l:doc
endfunction

if g:ipython_greedy_matching
    let s:split_pattern = "[^= \r\n*().@-]"
else
    let s:split_pattern = '\k\|\.'
endif

Python2or3 << endpython
def process_matches(matches, metadata, result):
    if PY3:
        completions = matches
    else:
        completions = [s.encode(vim_encoding) for s in matches]
        metadata = [s.encode(vim_encoding) for s in metadata]
    if vim.vars['ipython_dictionary_completion'] and not vim.vars['ipython_greedy_matching']:
        for char in '\'"':
            if any(c.endswith(char + ']') for c in completions):
                completions = [c for c in completions if c.endswith(char + ']')]
                break
    try:
        completions, metadata = zip(*sorted(zip(completions, metadata),
                                            key=lambda x: x[0].lstrip('%').lower()))
    except ValueError:
        pass
    for c, m in zip(completions, metadata):
        result.c, result.m = c, m
        if 'CALLSIG' in m:
            result.split = m.partition('CALLSIG')
            vim.command('call add(res, {"word": IPythonPyeval("r.c"), '
                                       '"menu": IPythonPyeval("r.split[0]"), '
                                       '"info": IPythonPyeval("r.split[-1]")})')
        else:
            vim.command('call add(res, {"word": IPythonPyeval("r.c"), '
                                       '"menu": IPythonPyeval("r.m")})')
endpython

fun! CompleteIPython(findstart, base)
    if a:findstart
        " return immediately for imports
        if getline('.')[:col('.')-1] =~#
            \ '\v^\s*(from\s+\w+(\.\w+)*\s+import\s+(\w+,\s+)*|import\s+)'
            let line = getline('.')
            let s:start = col('.') - 1
            while s:start && line[s:start - 1] =~ '[._[:alnum:]]'
                let s:start -= 1
            endwhile
            Python2or3 current_line = vim.current.line
            return s:start
        endif
        " locate the start of the word
        let line = split(getline('.')[:col('.')-1], '\zs')
        let s:start = col('.') - 1
        if s:start == 0 || (len(line) == s:start &&
            \ line[s:start-2] !~ s:split_pattern &&
            \ !(g:ipython_greedy_matching && s:start >= 2
            \   && line[s:start-3] =~ '\k') &&
            \ join(line[s:start-3:s:start-2], '') !=# '].')
            let s:start = -1
            return s:start
        endif
        let s:start = strchars(getline('.')[:col('.')-1]) - 1
        while s:start > 0 && (line[s:start-1] =~ s:split_pattern
            \ || (g:ipython_greedy_matching && line[s:start-1] == '.'
            \     && s:start >= 2 && line[s:start-2] =~ '\k')
            \ || join(line[s:start-2:s:start-1], '') ==# '].')
            if g:ipython_greedy_matching && line[s:start-1] == '[' &&
                \ (s:start == 1 || line[s:start-2] !~ '\k\|\]')
                break
            endif
            let s:start -= 1
        endwhile
        Python2or3 current_line = vim.current.line
        return s:start + len(join(line[: s:start], '')) -
            \ len(getline('.')[: s:start])
    else
        " find months matching with "a:base"
        let res = []
        if s:start == -1 | return [] | endif
        let start = s:start
        Python2or3 << endpython
base = vim.eval("a:base")
try:
    matches, metadata = ipy_complete(base, current_line, int(vim.eval('start')) + len(base))
except IOError:
    if vim.eval('exists("*jedi#completions")'):
        vim.command('setlocal omnifunc=jedi#completions')
    else:
        vim.command('setlocal omnifunc=')
    vim.command('return []')
r = Result()  # result object to let vim access namespace while in a function
process_matches(matches, metadata, r)
endpython
        return res
    endif
endfun

function! IPythonHistory(pattern, ...)
    let session = a:0 > 0 ? a:1 : (-1)
    let res = []
    Python2or3 << endpython
n = vim.vars.get('ipython_history_len', 100)
pattern = vim.eval('a:pattern')
if pattern:
    if not pattern.startswith('*') and not pattern.endswith('*'):
        pattern = '*{0}*'.format(pattern)
else:
    pattern = None
unique = vim.eval('get(g:, "ipython_history_unique", "")')
unique = bool(int(unique)) if unique else pattern is not None
if int(vim.eval('session')) >= 0:
    history = get_session_history(session=int(vim.eval('session')),
                                  pattern=pattern)
else:
    history = get_history(n, pattern=pattern, unique=unique)
seen = set()
for session, line, code in reversed(
        [next(iter(h)) for _, h in it.groupby(
         history, lambda i: (i[0], i[2]))]):
    if not unique or code.strip() not in seen:
        seen.add(code.strip())
        vim.command('call add(res, {'
        '"session": +IPythonPyeval("session"), '
        '"line": +IPythonPyeval("line"), '
        '"code": IPythonPyeval("code")})')
endpython
    return res
endfunction

function! IPythonCmdComplete(arglead, cmdline, cursorpos, ...)
  let res = []
Python2or3 << endpython
arglead = vim.eval('a:arglead')
if ' ' in arglead and not (arglead.strip().startswith('from ') or
                           arglead.strip().startswith('import ')):
    start = arglead.split()[-1]
else:
    start = arglead

try:
    matches, metadata = ipy_complete(start,
                                     vim.eval('a:cmdline'),
                                     int(vim.eval('a:cursorpos')))
except IOError:
    vim.command('return []')

if ' ' in arglead:
    arglead = arglead.rpartition(' ')[0]
    matches = ['%s %s' % (arglead, m) for m in matches]
if int(vim.eval('a:0')):
    r = Result()
    process_matches(matches, metadata, r)
endpython
  if a:0
    return res
  else
    return IPythonPyeval('matches')
  endif
endfunction

function! GreedyCompleteIPython(findstart, base)
  if a:findstart
    let line = getline('.')
    let start = col('.') - 1
    while start && line[start - 1] =~ '\S'
      let start -= 1
    endwhile
    return start
  else
    return IPythonCmdComplete(a:base, a:base, len(a:base), 1)
  endif
endfunction
