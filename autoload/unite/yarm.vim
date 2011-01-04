"
" yarm.vim
" Last Modified: 04 Jan 2011
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
"
" clear undo
"
function! unite#yarm#clear_undo()
  let old_undolevels = &undolevels
  setlocal undolevels=-1
  execute "normal a \<BS>\<Esc>"
  let &l:undolevels = old_undolevels
  unlet old_undolevels
endfunction
"
" parse option
"
function! unite#yarm#parse_args(args)
  let convert_def = {
        \ 'status'   : 'status_id'   ,
        \ 'project'  : 'project_id'  ,
        \ 'tracker'  : 'tracker_id'  ,
        \ 'assigned' : 'assigned_to'
        \ }
  let option = {}
  for arg in a:args
    let v = split(arg , '=')
    let v[0] = has_key(convert_def , v[0]) ? convert_def[v[0]] : v[0]
    let option[v[0]] = len(v) == 1 ? 1 : v[1]
  endfor
  return option
endfunction
"
" from xml.vim
"
function! unite#yarm#escape(str)
  let str = a:str
  let str = substitute(str, '&', '\&amp;', 'g')
  let str = substitute(str, '>', '\&gt;' , 'g')
  let str = substitute(str, '<', '\&lt;' , 'g')
  let str = substitute(str, '"', '\&#34;', 'g')
  return str
endfunction
"
" padding  ljust
"
function! unite#yarm#ljust(str, size, ...)
  let str = a:str
  let c   = a:0 > 0 ? a:000[0] : ' '
  while 1
    if strwidth(str) >= a:size
      return str
    endif
    let str .= c
  endwhile
  return str
endfunction
"
" padding rjust
"
function! unite#yarm#rjust(str, size, ...)
  let str = a:str
  let c   = a:0 > 0 ? a:000[0] : ' '
  while 1
    if strwidth(str) >= a:size
      return str
    endif
    let str = c . str
  endwhile
  return str
endfunction
"
" echo info log
"
function! unite#yarm#info(msg)
  echohl yarm_ok | echo a:msg | echohl None
  return 1
endfunction
"
" echo error log
"
function! unite#yarm#error(msg)
  echohl ErrorMsg | echo a:msg | echohl None
  return 0
endfunction
"
" backup issue
"
functio! unite#yarm#backup_issue(issue)
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
" open browser with issue's id
"
function! unite#yarm#open_browser(id)
  echohl yarm_ok 
  execute "OpenBrowser " . s:server_url() . '/issues/' . a:id
  echohl None
endfunction
"
" xml to issue
"
function! unite#yarm#to_issue(xml)
  let issue = {}
  for node in a:xml.childNodes()
    let issue[node.name] = empty(node.attr) ? node.value() : 
          \ has_key(node.attr , 'name') ? node.attr.name : ''
  endfor
  " custom_fields
  let issue.custom_fields = []
  let custom_fields = a:xml.childNode("custom_fields")
  if !empty(custom_fields)
    for field in custom_fields.childNodes('custom_field')
      call add(issue.custom_fields , {
            \ 'name'  : field.attr.name , 
            \ 'value' : field.value()
            \ })
    endfor
  endif
  " unite_word
  let issue.abbr = '#' . issue.id . ' ' . issue.subject
  let issue.word = issue.abbr
  " append extract condition for fields
  for v in g:unite_yarm_word_fields
    if has_key(issue , v)
      let issue.word .= ' ' . issue[v]
    endif
  endfor
  " append extract condition for custom fields
  for v in g:unite_yarm_word_custom_fields
    if len(issue.custom_fields) <= v
      continue
    endif
    let issue.word .= ' ' . issue.custom_fields[v].value
  endfor
  " url for CRUD
  let rest_url = s:server_url() . '/issues/' . issue.id . '.xml?format=xml'
  if exists('g:unite_yarm_access_key')
    let rest_url .= '&key=' . g:unite_yarm_access_key
  endif
  let issue.rest_url = rest_url

  return issue
endfunction
"
" get issues with api
"
function! unite#yarm#get_issues(option)
  let url = s:server_url() . '/issues.xml?' . 
                  \ 'limit=' . g:unite_yarm_per_page
  if exists('g:unite_yarm_access_key')
    let url .= '&key=' . g:unite_yarm_access_key
  endif
  for key in keys(a:option)
    if a:option[key] == ''
      continue
    endif
    let url .= '&' . key . '=' . a:option[key]
  endfor
  let res = http#get(url)
  " server is not active
  if len(res.header) == 0
    call unite#yarm#error('can not access ' . s:server_url())
    return []
  endif
  " check status code
  if split(res.header[0])[1] != '200'
    call unite#yarm#error(res.header[0])
    return []
  endif
  " convert xml to dict
  let issues = []
  for dom in xml#parse(res.content).childNodes('issue')
    call add(issues , unite#yarm#to_issue(dom))
  endfor
  return issues
endfunction
"
" get issue with api
"
function! unite#yarm#get_issue(id)
  let url = s:server_url() . '/issues/' . a:id . '.xml'
  if exists('g:unite_yarm_access_key')
    let url .= '?key=' . g:unite_yarm_access_key
  endif
  return unite#yarm#to_issue(xml#parseURL(url))
endfunction
"
" get sever url
"
" http://yarm.org  → http://yarm.org
" http://yarm.org/ → http://yarm.org
"
function! s:server_url()
  return substitute(g:unite_yarm_server_url , '/$' , '' , '')
endfunction


