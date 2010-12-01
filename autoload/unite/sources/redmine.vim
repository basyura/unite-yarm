" redmine source for unite.vim
" Version:     0.1.1
" Last Change: 27 Nov 2010
" Author:      basyura <basyrua at gmail.com>
" Licence:     The MIT License {{{
"     Permission is hereby granted, free of charge, to any person obtaining a copy
"     of this software and associated documentation files (the "Software"), to deal
"     in the Software without restriction, including without limitation the rights
"     to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
"     copies of the Software, and to permit persons to whom the Software is
"     furnished to do so, subject to the following conditions:
"
"     The above copyright notice and this permission notice shall be included in
"     all copies or substantial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
"     IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
"     FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
"     AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
"     LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
"     OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
"     THE SOFTWARE.
" }}}
"
" variables
"
if !exists('g:unite_yarm_server_url')
  let g:unite_yarm_server_url = 'http://localhost:3000'
endif
"
if !exists('g:unite_yarm_per_page')
  let g:unite_yarm_per_page = 25
endif
" hi - source を読み込み直すと消えちゃう
highlight yarm_ok guifg=white guibg=blue
"
" source
"
function! unite#sources#redmine#define()
  return s:unite_source
endfunction
" cache
let s:candidates_cache  = []
"
let s:unite_source      = {}
let s:unite_source.name = 'redmine'
let s:unite_source.default_action = {'common' : 'open'}
let s:unite_source.action_table   = {}
" create list
function! s:unite_source.gather_candidates(args, context)
  " parse args
  let option = s:parse_args(a:args)
  " clear cache. option に判定メソッドを持たせたい
  if len(option) != 0
    let s:candidates_cache = []
  endif
  " return cache if exist
  if !empty(s:candidates_cache)
    return s:candidates_cache
  endif
  " cache issues
  call s:info('now caching issues ...')
  let s:candidates_cache = 
        \ map(s:get_issues(option) , '{
        \ "word"          : v:val.unite_word,
        \ "source"        : "redmine",
        \ "source__issue" : v:val,
        \ }')
  return s:candidates_cache
endfunction
"
" action table
"
let s:action_table = {}
let s:unite_source.action_table.common = s:action_table
" 
" action - open
"
let s:action_table.open = {'description' : 'open issue'}
function! s:action_table.open.func(candidate)
  call s:load_issue(a:candidate.source__issue , 0)
endfunction
"
" action - browser
"
let s:action_table.browser = {'description' : 'open issue with browser'}
function! s:action_table.browser.func(candidate)
  call s:open_browser(a:candidate.source__issue.id)
endfunction
"
" action - reget
"
let s:action_table.reget = {'description' : 'reget issue'}
function! s:action_table.reget.func(candidate)
  let id = a:candidate.source__issue.id
  call s:info('reget issue #' . id . ' ...')
  call s:load_issue(s:reget_issue(id) , 1)
endfunction
"
" autocmd
"
augroup RedmineGroup
  autocmd! RedmineGroup
  autocmd FileType redmine call s:redmine_issue_settings()
augroup END  

function! s:redmine_issue_settings()
  nmap <silent> <buffer> <CR> :call <SID>redmine_issue_buffer_action()<CR>
endfunction

function! s:redmine_issue_buffer_action()
  let matched = matchlist(expand('<cWORD>') , 'https\?://\S\+')
  if len(matched) != 0
    echohl yarm_ok | execute "OpenBrowser " . matched[0] | echohl None
    return
  endif
  let hiid = synIDattr(synID(line('.'),col('.'),1),'name')
  " open issue
  if hiid == 'yarm_title'
    call s:open_browser(b:unite_yarm_issue.id)
    return
  endif
endfunction

function! s:redmine_put_issue()
  echohl yarm_ok
  if input('update ? (y/n) : ') != 'y'
    return s:info('update was canceled')
  endif
  echohl None
  " cached issue
  let issue = b:unite_yarm_issue
  " i want display progress
  call s:info('now updating #' . issue.id . ' ...')
  " reget lastest issue
  let pre   = s:get_issue(issue.id)
  " check latest
  if pre.updated_on != issue.updated_on
    redraw
    return s:error('issue #' . issue.id . ' is already updated')
  endif
  " backup
  call s:backup_issue(pre)
  " 2行目移行の改行だけの行移行を description とみなす
  :2
  let body_start = search('^$') + 1
  " 最後の改行が削られるので \n を付ける
  let body  = '<issue><description>' 
                \ . join(map(getline(body_start,'$') , "s:escape(v:val)") , "\n") . "\n"
                \ . '</description></issue>'
  " put issue
  let res   = http#post(issue.rest_url , body , {'Content-Type' : 'text/xml'} , 'PUT')
  " split HTTP/1.0 200 OK
  if split(res.header[0])[1] == '200'
    " :wq 保存して閉じる 
    " :w  チケットを取り直して再描画
    redraw
    call s:load_issue(s:reget_issue(issue.id) , 1)
    call s:info('#' . issue.id . ' - ' . res.header[0])
  else
    redraw
    call s:error('failed - ' . res.header[0])
  endif
endfunction

" - private functions -

"
" get issues with api
"
function! s:get_issues(option)
  let url = g:unite_yarm_server_url . '/issues.xml?' . 
                  \ 'per_page=' . g:unite_yarm_per_page
  if exists('g:unite_yarm_access_key')
    let url .= '&key=' . g:unite_yarm_access_key
  endif
  for key in keys(a:option)
    " うーむ
    if a:option[key] == ''
      continue
    endif
    let url .= '&' . key . '=' . a:option[key]
  endfor
  let issues = []
  let res = http#get(url)
  " check status code
  if split(res.header[0])[1] != '200'
    call s:error(res.header[0])
    return []
  endif
  " convert xml to dict
  for dom in xml#parse(res.content).childNodes('issue')
    call add(issues , s:to_issue(dom))
  endfor
  return issues
endfunction
"
" get issue with api
"
function! s:get_issue(id)
  let url = g:unite_yarm_server_url . '/issues/' . a:id . '.xml'
  if exists('g:unite_yarm_access_key')
    let url .= '?key=' . g:unite_yarm_access_key
  endif
  return s:to_issue(xml#parseURL(url))
endfunction
"
" load issue to buffer
"
" issue   : 編集対象のチケット情報
" forcely : 強制的に内容を書き換えるか
"
function! s:load_issue(issue, forcely)
  let bufname = 'redmine_' . a:issue.id 
  let bufno   = bufnr(bufname . "$")
  " 強制上書きまたは隠れバッファ(ls!で表示されるもの)の場合
  if a:forcely || !buflisted(bufname)
    if bufno != -1
      execute 'bwipeout! ' . bufno
    endif
  " 存在する場合は表示、存在しない場合は一度消してから開きなおし
  else
    execute 'buffer ' . bufno
    return
  endif

  exec 'edit! ' . bufname
  silent %delete _
  setlocal bufhidden=hide
  setlocal noswapfile
  setlocal fileencoding=utf-8 
  setlocal fileformat=unix
  setfiletype redmine
  " append issue's fields
  call append(0 , [
      \ '<< ' . a:issue.project . ' - #' . a:issue.id . ' ' . a:issue.subject . ' >>' ,
      \ '' ,
      \ 'tracker         : ' . a:issue.tracker ,
      \ 'status          : ' . a:issue.status ,
      \ 'priority        : ' . a:issue.priority ,
      \ 'author          : ' . a:issue.author ,
      \ 'start_date      : ' . a:issue.start_date ,
      \ 'due_date        : ' . a:issue.due_date ,
      \ 'estimated_hours : ' . a:issue.estimated_hours ,
      \ 'done_ratio      : ' . a:issue.done_ratio ,
      \ 'created_on      : ' . a:issue.created_on ,
      \ 'updated_on      : ' . a:issue.updated_on ,
      \ ])
  for custom in a:issue.custom_fileds
    call append(line('$') - 1 , s:padding_right(custom.name , 15) . ' : ' . custom.value)
  endfor
  " add description
  for line in split(a:issue.description,"\n")
    call append(line('$') , substitute(line , '' , '' , 'g'))
  endfor
  " clear undo
  call s:clear_undo()
  " check access key.
  if !exists('g:unite_yarm_access_key')
    setlocal buftype=nofile
    setlocal nomodifiable
  else
    setlocal buftype=acwrite
    setlocal nomodified
    " cache issue for update
    let b:unite_yarm_issue = a:issue
    " add put command
    augroup RedmineBufCmdGroup
      autocmd! RedmineBufCmdGroup
      autocmd BufWriteCmd <buffer> call <SID>redmine_put_issue()
    augroup END
  endif

  " move cursor to top
  :1
  stopinsert
endfunction
"
" open browser with issue's id
"
function! s:open_browser(id)
  echohl yarm_ok 
  execute "OpenBrowser " . g:unite_yarm_server_url . '/issues/' . a:id
  echohl None
endfunction
"
" reget issue
"
function! s:reget_issue(id)
  let issue = s:get_issue(a:id)
  for cache in s:candidates_cache
    " update cache
    if cache.source__issue.id == a:id
      let cache.word          = issue.unite_word
      let cache.source__issue = issue
      break
    endif
  endfor
  return issue
endfunction
"
" backup issue
"
functio! s:backup_issue(issue)
  if !exists('g:unite_yarm_backup_dir')
    return
  endif

  let body = split(a:issue.description , "\n")
  let path = g:unite_yarm_backup_dir . '/' . a:issue.id
        \ . '.' . strftime('%Y%m%d%H%M%S')
        \ . '.txt'
  call writefile(body , path)

endfunction
"
" xml to issue
"
function! s:to_issue(xml)
  let issue = {
        \ 'id'              : a:xml.find('id').value() ,
        \ 'project'         : a:xml.find('project').attr['name'] ,
        \ 'tracker'         : a:xml.find('tracker').attr['name'] ,
        \ 'status'          : a:xml.find('status').attr['name'] ,
        \ 'priority'        : a:xml.find('priority').attr['name'] ,
        \ 'author'          : a:xml.find('author').attr['name'] ,
        \ 'subject'         : a:xml.find('subject').value() ,
        \ 'description'     : a:xml.find('description').value() ,
        \ 'start_date'      : a:xml.find('start_date').value() ,
        \ 'due_date'        : a:xml.find('due_date').value() ,
        \ 'estimated_hours' : a:xml.find('estimated_hours').value() ,
        \ 'done_ratio'      : a:xml.find('done_ratio').value() ,
        \ 'created_on'      : a:xml.find('created_on').value() ,
        \ 'updated_on'      : a:xml.find('updated_on').value() ,
        \}
  " custom_fileds
  let issue.custom_fileds = []
  let custom_fields = a:xml.childNode("custom_fields")
  if !empty(custom_fields)
    for field in custom_fields.childNodes('custom_field')
      call add(issue.custom_fileds , {
            \ 'name'  : field.attr['name'] , 
            \ 'value' : field.value()
            \ })
    endfor
  endif
  " unite_word
  let issue.unite_word = '#' . issue.id . ' ' . issue.subject
  " url for CRUD
  let rest_url = g:unite_yarm_server_url . '/issues/' . issue.id . '.xml?format=xml'
  if exists('g:unite_yarm_access_key')
    let rest_url .= '&key=' . g:unite_yarm_access_key
  endif
  let issue.rest_url = rest_url

  return issue
endfunction
"
" from xml.vim
"
function! s:escape(str)
  let str = a:str
  let str = substitute(str, '&', '\&amp;', 'g')
  let str = substitute(str, '>', '\&gt;' , 'g')
  let str = substitute(str, '<', '\&lt;' , 'g')
  let str = substitute(str, '"', '\&#34;', 'g')
  return str
endfunction
"
" clear undo
"
function! s:clear_undo()
  let old_undolevels = &undolevels
  setlocal undolevels=-1
  execute "normal a \<BS>\<Esc>"
  let &l:undolevels = old_undolevels
  unlet old_undolevels
endfunction
"
" padding
"
function! s:padding_right(str, size)
  let str = a:str
  while 1
    if strwidth(str) >= a:size
      return str
    endif
    let str .= ' '
  endwhile
endfunction
"
" parse option
"
function! s:parse_args(args)
  " default option うーむ
  let option = {}
  for arg in a:args
    let v = split(arg , '=')
    let option[v[0]] = len(v) == 1 ? 1 : v[1]
  endfor
  return option
endfunction
"
" echo info log
"
function! s:info(msg)
  echohl yarm_ok | echo a:msg | echohl None
  return 1
endfunction
"
" echo error log
"
function! s:error(msg)
  echohl ErrorMsg | echo a:msg | echohl None
  return 0
endfunction
