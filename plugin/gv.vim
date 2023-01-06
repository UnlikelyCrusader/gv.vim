" The MIT License (MIT)
"
" Copyright (c) 2016 Junegunn Choi
"
" Permission is hereby granted, free of charge, to any person obtaining a copy
" of this software and associated documentation files (the "Software"), to deal
" in the Software without restriction, including without limitation the rights
" to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
" copies of the Software, and to permit persons to whom the Software is
" furnished to do so, subject to the following conditions:
"
" The above copyright notice and this permission notice shall be included in
" all copies or substantial portions of the Software.
"
" THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
" IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
" FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
" AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
" LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
" OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
" THE SOFTWARE.

function! s:warn(message)
  echohl WarningMsg | echom a:message | echohl None
endfunction

function! s:shrug()
  call s:warn('¯\_(ツ)_/¯')
endfunction

let s:begin = '^[^a-f0-9]*\zs[a-f0-9]\+'
let s:ansi_hi_ns = luaeval('vim.api.nvim_create_namespace("gvhi")')

function! gv#sha(...)
  return matchstr(get(a:000, 0, getline('.')), s:begin)
endfunction

function! s:move(flag)
  let [l, c] = searchpos(s:begin, a:flag)
  return l ? printf('%dG%d|', l, c) : ''
endfunction

function! s:browse(url)
  call netrw#BrowseX(b:git_origin.a:url, 0)
endfunction

function! s:tabnew()
  execute (tabpagenr()-1).'tabnew'
endfunction

function! s:gbrowse()
  let sha = gv#sha()
  if empty(sha)
    return s:shrug()
  endif
  execute 'GBrowse' sha
endfunction

function! s:type(visual)
  if a:visual
    let shas = filter(map(getline("'<", "'>"), 'gv#sha(v:val)'), '!empty(v:val)')
    if len(shas) < 2
      return [0, 0]
    endif
    return ['diff', FugitiveShellCommand(['diff', shas[-1], shas[0]])]
  endif

  if exists('b:git_origin')
    let syn = synIDattr(synID(line('.'), col('.'), 0), 'name')
    if syn == 'gvGitHub'
      return ['link', '/issues/'.expand('<cword>')[1:]]
    elseif syn == 'gvTag'
      let tag = matchstr(getline('.'), '(tag: \zs[^ ,)]\+')
      return ['link', '/releases/'.tag]
    endif
  endif

  let sha = gv#sha()
  if !empty(sha)
    return ['commit', FugitiveFind(sha)]
  endif
  return [0, 0]
endfunction

function! s:split(tab)
  if a:tab
    call s:tabnew()
  elseif getwinvar(winnr('$'), 'gv')
    $wincmd w
    enew
  else
    vertical botright new
  endif
  let w:gv = 1
endfunction

function! s:open(visual, ...)
  let [type, target] = s:type(a:visual)

  if empty(type)
    return s:shrug()
  elseif type == 'link'
    return s:browse(target)
  endif

  call s:split(a:0)
  call s:scratch()
  if type == 'commit'
    execute 'e' escape(target, ' ')
    nnoremap <silent> <buffer> gb :GBrowse<cr>
  elseif type == 'diff'
    call s:fill(target)
    setf diff
  endif
  nnoremap <silent> <buffer> q :close<cr>
  let bang = a:0 ? '!' : ''
  if exists('#User#GV'.bang)
    execute 'doautocmd <nomodeline> User GV'.bang
  endif
  wincmd p
  echo
endfunction

function! s:dot()
  let sha = gv#sha()
  return empty(sha) ? '' : ':Git  '.sha."\<s-left>\<left>"
endfunction

function! s:syntax()
  setf GV
  syn clear
  syn match gvTree    /^[^a-f0-9]* / nextgroup=gvInfo
  syn match gvInfo    /[a-f0-9]\+ / contains=gvSha nextgroup=gvMetaMessage,gvMessage
  syn match gvSha     /[a-f0-9]\{6,}/ contained
  syn match gvMetaMessage /.* \ze(.\{-})$/ contained contains=gvAuthorMeta,gvGitHub,gvJira nextgroup=gvMeta
  syn match gvMessage /.*) $/ contained contains=gvAuthorOnly,gvGitHub,gvJira
  syn match gvAuthorMeta    /([^)]\+)[ ]\+([^)]\+)$/ contained contains=gvAuthor,gvMeta
  syn match gvAuthorOnly    /([^)]\+) $/ contained contains=gvAuthor
  syn match gvAuthor    /([^()]\+) / contained contains=gvAuthorName
  syn match gvAuthorName  /(\zs[^(),]\+\ze,/ contained
  syn match gvMeta    /([^)]\+)$/ contained contains=gvTag
  syn match gvTag     /(tag:[^)]\+)/ contained
  syn match gvGitHub  /\<#[0-9]\+\>/ contained
  syn match gvJira    /\<[A-Z]\+-[0-9]\+\>/ contained
  hi def link gvTree   Comment
  hi def link gvSha    Identifier
  hi def link gvTag    Conditional
  hi def link gvGitHub Label
  hi def link gvJira   Label
  hi def link gvMeta   Conditional
  hi def link gvAuthor String
  hi def link gvAuthorName Function

  syn match gvAdded     "^\W*\zsA\t.*"
  syn match gvDeleted   "^\W*\zsD\t.*"
  hi def link gvAdded    diffAdded
  hi def link gvDeleted  diffRemoved

  syn match diffAdded   "^+.*"
  syn match diffRemoved "^-.*"
  syn match diffLine    "^@.*"
  syn match diffFile    "^diff\>.*"
  syn match diffFile    "^+++ .*"
  syn match diffNewFile "^--- .*"
  hi def link diffFile    Type
  hi def link diffNewFile diffFile
  hi def link diffAdded   Identifier
  hi def link diffRemoved Special
  hi def link diffFile    Type
  hi def link diffLine    Statement
endfunction

function! s:maps()
  nnoremap <silent> <buffer> q    :call <sid>shrug()<cr>
  nnoremap <silent> <buffer> <nowait> gq :$wincmd w <bar> close<cr>
  nnoremap <silent> <buffer> gb   :call <sid>gbrowse()<cr>
  nnoremap <silent> <buffer> <cr> :call <sid>open(0)<cr>
  nnoremap <silent> <buffer> o    :call <sid>open(0)<cr>
  nnoremap <silent> <buffer> O    :call <sid>open(0, 1)<cr>
  nnoremap <silent> <buffer> r    :call <sid>reload()<cr>
  nnoremap <silent> <buffer> >    :call <sid>increase_width()<cr>
  nnoremap <silent> <buffer> <    :call <sid>decrease_width()<cr>
  xnoremap <silent> <buffer> <cr> :<c-u>call <sid>open(1)<cr>
  xnoremap <silent> <buffer> o    :<c-u>call <sid>open(1)<cr>
  xnoremap <silent> <buffer> O    :<c-u>call <sid>open(1, 1)<cr>
  nnoremap          <buffer> <expr> .  <sid>dot()
  nnoremap <silent> <buffer> <expr> ]] <sid>move('')
  nnoremap <silent> <buffer> <expr> ][ <sid>move('')
  nnoremap <silent> <buffer> <expr> [[ <sid>move('b')
  nnoremap <silent> <buffer> <expr> [] <sid>move('b')
  xnoremap <silent> <buffer> <expr> ]] <sid>move('')
  xnoremap <silent> <buffer> <expr> ][ <sid>move('')
  xnoremap <silent> <buffer> <expr> [[ <sid>move('b')
  xnoremap <silent> <buffer> <expr> [] <sid>move('b')

  nmap              <buffer> <C-n> ]]o
  nmap              <buffer> <C-p> [[o
  xmap              <buffer> <C-n> ]]ogv
  xmap              <buffer> <C-p> [[ogv
endfunction

function! s:setup(bufname, git_origin)
  let winid = s:find_winid(a:bufname)
  if winid != -1
    call win_gotoid(winid)
    silent exe 'buffer' fnameescape(a:bufname)
  else
    call s:tabnew()
    silent exe 'file' fnameescape(a:bufname)
  endif

  call s:scratch()

  if exists('g:fugitive_github_domains')
    let domain = join(map(extend(['github.com'], g:fugitive_github_domains),
          \ 'escape(substitute(split(v:val, "://")[-1], "/*$", "", ""), ".")'), '\|')
  else
    let domain = '.*github.\+'
  endif
  " https://  github.com  /  junegunn/gv.vim  .git
  " git@      github.com  :  junegunn/gv.vim  .git
  let pat = '^\(https\?://\|git@\)\('.domain.'\)[:/]\([^@:/]\+/[^@:/]\{-}\)\%(.git\)\?$'
  let origin = matchlist(a:git_origin, pat)
  if !empty(origin)
    let scheme = origin[1] =~ '^http' ? origin[1] : 'https://'
    let b:git_origin = printf('%s%s/%s', scheme, origin[2], origin[3])
  endif
endfunction

function! s:find_winid(bufname)
  let bufid = bufnr('^'.fnameescape(a:bufname).'$')
  if bufid == -1
    return -1
  endif
  " check if current window contain the buffer
  if bufid == bufnr()
    return win_getid()
  endif
  let winidlist = win_findbuf(bufid)
  if empty(winidlist)
    return -1
  endif
  return winidlist[0]
endfunction

function! s:scratch()
  setlocal buftype=nofile bufhidden=wipe noswapfile nomodeline
endfunction

function! s:fill(cmd)
  setlocal modifiable
  let win_state = winsaveview()
  silent normal! gg"_dG
  silent execute 'read' escape('!'.a:cmd, '%')
  normal! gg"_dd
  call s:ansi_syntax()

  " let start = reltime()
  call v:lua.require('gv').ansi_highlight()
  " call s:ansi_highlight()
  " echom "elapsed time:".reltimestr(reltime(start))

  call winrestview(win_state)
  setlocal nomodifiable
endfunction

function! s:ansi_highlight()
  " experimental ansi_highlight for single line mainly for git log tree.
  for i in range(1, line('$'))
    let l = getline(i)
    let prev_hi = ''
    let prev_idx = ''
    let hi_list = []

    let s = 0
    while 1
      let [m, s, e] = matchstrpos(l, '\e\[[0-9;]*[mK]', s)
      if len(m) == 0
        break
      endif
      if s == 0
        let l = l[e:]
      else
        let l = l[:s-1] . l[e:]
      endif

      let cur_hi = s:ansi_hi_group(m)
      if prev_hi == cur_hi
        continue
      endif

      if len(prev_hi) > 0
        call add(hi_list, [prev_hi, prev_idx, s])
      endif

      let prev_hi = cur_hi
      let prev_idx = s
    endwhile
    call setline(i, l)

    for [prefix, s, e] in hi_list
      execute 'lua vim.highlight.range('.bufnr('%').','.s:ansi_hi_ns.',"gvAnsi'.prefix.'",{'.(i-1).','.s.'},{'.(i-1).','.e.'},{})'
    endfor
  endfor
endfunction

function! s:ansi_hi_group(ansi)
  return matchstr(a:ansi, '\d\zem')
endfunction

function! s:ansi_syntax()
  hi def link gvAnsi1 Keyword
  hi def link gvAnsi2 Include
  hi def link gvAnsi3 Type
  hi def link gvAnsi4 Variable
  hi def link gvAnsi5 Constant
  hi def link gvAnsi6 Define
  hi def link gvAnsi7 Operator
  hi def link gvAnsi8 Identifier
  hi def link gvAnsi9 Comment
  hi def link gvAnsi10 Comment
  hi def link gvAnsi11 Comment
  hi def link gvAnsi12 Comment
  hi def link gvAnsi13 Comment
  hi def link gvAnsi14 Comment
  hi def link gvAnsi15 Comment
endfunction

function! s:tracked(file)
  call system(FugitiveShellCommand(['ls-files', '--error-unmatch', a:file]))
  return !v:shell_error
endfunction

function! s:check_buffer(current)
  if empty(a:current)
    throw 'untracked buffer'
  elseif !s:tracked(a:current)
    throw a:current.' is untracked'
  endif
endfunction

function! s:log_opts(bang, visual, line1, line2, raw_option)
  if a:visual || a:bang
    call s:check_buffer(b:current_path)
    return a:visual ? [['--color=never', printf('-L%d,%d:%s', a:line1, a:line2, b:current_path)], []] : [['--color=never', '--follow'], ['--', b:current_path]]
  endif
  return a:raw_option ? [['--color', '--graph'], []] : [['--color', '--graph', '--branches', '--remotes', '--tags'], []]
endfunction

function! s:list(bufname, log_opts)
  let b:gv_comment_width = get(b:, 'gv_comment_width', 75)
  let comment_width = b:gv_comment_width <= 0? 1: b:gv_comment_width

  let default_opts = ['--format=format:%h %<('.comment_width.',trunc)%s (%aN, %ar) %d']

  let git_args = ['log'] + default_opts + a:log_opts
  let git_log_cmd = FugitiveShellCommand(git_args)

  call s:fill(git_log_cmd)
  setlocal nowrap tabstop=8 cursorline iskeyword+=#

  if !exists(':GBrowse')
    doautocmd <nomodeline> User Fugitive
  endif
  call s:maps()
  call s:syntax()

  if !get(t:, 'gv_vim_tab', 0)
    let t:gv_vim_tab = 1  " mark tab
    redraw
    echo 'o: open split / O: open tab / gb: Gbrowse / r: reload / <: dec width / >: inc width /  gq: quit'
  endif
endfunction

function! s:trim(arg)
  let arg = substitute(a:arg, '\s*$', '', '')
  return arg =~ "^'.*'$" ? substitute(arg[1:-2], "''", '', 'g')
     \ : arg =~ '^".*"$' ? substitute(substitute(arg[1:-2], '""', '', 'g'), '\\"', '"', 'g')
     \ : substitute(substitute(arg, '""\|''''', '', 'g'), '\\ ', ' ', 'g')
endfunction

function! gv#shellwords(arg)
  let words = []
  let contd = 0
  for token in split(a:arg, '\%(\%(''\%([^'']\|''''\)\+''\)\|\%("\%(\\"\|[^"]\)\+"\)\|\%(\%(\\ \|\S\)\+\)\)\s*\zs')
    let trimmed = s:trim(token)
    if contd
      let words[-1] .= trimmed
    else
      call add(words, trimmed)
    endif
    let contd = token !~ '\s\+$'
  endfor
  return words
endfunction

function! s:split_pathspec(args)
  let split = index(a:args, '--')
  if split < 0
    return [a:args, []]
  elseif split == 0
    return [[], a:args]
  endif
  return [a:args[0:split-1], a:args[split:]]
endfunction

function! s:gl(buf, visual)
  if !exists(':Gllog')
    return
  endif
  tab split
  silent execute a:visual ? "'<,'>" : "" 'Gllog'
  call setloclist(0, insert(getloclist(0), {'bufnr': a:buf}, 0))
  noautocmd b #
  lopen
  xnoremap <buffer> o :call <sid>gld()<cr>
  nnoremap <buffer> o <cr><c-w><c-w>
  nnoremap <buffer> O :call <sid>gld()<cr>
  nnoremap <buffer> gq :tabclose<cr>
  call matchadd('Conceal', '^fugitive://.\{-}\.git//')
  call matchadd('Conceal', '^fugitive://.\{-}\.git//\x\{7}\zs.\{-}||')
  setlocal concealcursor=nv conceallevel=3 nowrap
  let w:quickfix_title = 'o: open / o (in visual): diff / O: open (tab) / gq: quit'
endfunction

function! s:chdir(path)
  if exists('*chdir')
    call chdir(a:path)
  else
    execute 'lcd '.a:path
  endif
endfunction

function! s:onfugitiveupdated() abort
  let l:is_gv_vim_tab = get(t:, 'gv_vim_tab', 0)

  if !l:is_gv_vim_tab
    let t:gv_vim_tab = 0
    return
  endif

  let l:tabpageinfo = gettabinfo(tabpagenr())[0]
  let l:gv_winid = -1
  for l:winid in l:tabpageinfo['windows']
    let ft = getwinvar(l:winid, '&filetype')
    if ft == 'GV'
      let l:gv_winid = l:winid
      break
    endif
  endfor

  if l:gv_winid == -1
    return
  endif

  let l:current_winid = win_getid()
  let l:win_state = winsaveview()

  call win_gotoid(l:gv_winid)
  call s:reload()

  call win_gotoid(l:current_winid)
  call winrestview(l:win_state)
endfunction

augroup fugitivegv
  autocmd!
  autocmd User FugitiveChanged call s:onfugitiveupdated()
augroup END

function! s:gld() range
  let [to, from] = map([a:firstline, a:lastline], 'split(getline(v:val), "|")[0]')
  execute (tabpagenr()-1).'tabedit' escape(to, ' ')
  if from !=# to
    execute 'vsplit' escape(from, ' ')
    windo diffthis
  endif
endfunction

function! s:gv(bang, visual, line1, line2, args, raw_option) abort
  if !exists('g:loaded_fugitive')
    return s:warn('fugitive not found')
  endif

  if empty(FugitiveGitDir())
    return s:warn('not in git repo')
  endif

  let root = FugitiveFind(':/')

  if !exists('b:current_path')
    call s:chdir(root)
    let b:current_path = expand('%')
    call s:chdir('-')
  endif

  try
    if a:args =~ '?$'
      if len(a:args) > 1
        return s:warn('invalid arguments')
      endif
      call s:check_buffer(b:current_path)
      call s:gl(bufnr(''), a:visual)
    else
      let [opts1, paths1] = s:log_opts(a:bang, a:visual, a:line1, a:line2, a:raw_option)
      let [raw_opts2, paths2] = s:split_pathspec(gv#shellwords(a:args))

      let opts2 = s:inject_reflog(raw_opts2)

      let log_opts = opts1 + opts2 + paths1 + paths2
      let repo_short_name = fnamemodify(root, ':t')
      let bufname = repo_short_name.' '.join(opts1 + raw_opts2 + paths1 + paths2)
      " compact bufname for default graph
      let bufname = substitute(bufname, '--branches --remotes --tags', '--brt', '')

      call s:chdir(root)
      call s:setup(bufname, FugitiveRemoteUrl())
      call s:list(bufname, log_opts)
      call FugitiveDetect(@#)
    endif

    let b:gv_opts = {
          \ 'bang' : a:bang,
          \ 'visual' : a:visual,
          \ 'line1' : a:line1,
          \ 'line2' : a:line2,
          \ 'args' : a:args,
          \ 'raw_option' : a:raw_option,
          \ }
  catch
    return s:warn(v:exception)
  endtry
endfunction

function! s:reload() abort
  call s:gv(b:gv_opts.bang, b:gv_opts.visual, b:gv_opts.line1, b:gv_opts.line2, b:gv_opts.args, b:gv_opts.raw_option)
endfunction

function! s:increase_width()
  let b:gv_comment_width = get(b:, 'gv_comment_width', 75) + 15
  call s:reload()
endfunction

function! s:decrease_width()
  let b:gv_comment_width = get(b:, 'gv_comment_width', 75)
  if b:gv_comment_width - 15 < 0
    return
  endif

  let b:gv_comment_width -= 15
  call s:reload()
endfunction

function! s:inject_reflog(opts)
  if len(a:opts) <= 0 || a:opts[0] !=? 'reflog'
    return a:opts
  endif
  let reflogCount = system(FugitiveShellCommand(['reflog']) . ' | wc -l')
  let reflogCount = str2nr(reflogCount)

  return a:opts[1:] + map(range(reflogCount), {i, v -> 'HEAD@{' . string(v) . '}'})
endfunction

command! -bang -nargs=* -range=0 -complete=customlist,fugitive#CompleteObject GV call s:gv(<bang>0, <count>, <line1>, <line2>, <q-args>, 0)
command! -bang -nargs=* -range=0 -complete=customlist,fugitive#CompleteObject GVD call s:gv(<bang>0, <count>, <line1>, <line2>, '--date-order '.<q-args>, 0)
command! -bang -nargs=* -range=0 -complete=customlist,fugitive#CompleteObject GVB call s:gv(<bang>0, <count>, <line1>, <line2>, <q-args>, 1)
command! -bang -nargs=* -range=0 -complete=customlist,fugitive#CompleteObject GVS call s:gv(<bang>0, <count>, <line1>, <line2>, '--first-parent '.<q-args>, 1)
