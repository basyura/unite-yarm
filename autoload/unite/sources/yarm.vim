"
" variables
"
call unite#util#set_default('g:unite_yarm_server_url'  , 'http://localhost:3000')
call unite#util#set_default('g:unite_yarm_limit'       , 25)
call unite#util#set_default('g:unite_yarm_field_order' , [
      \ 'tracker', 
      \ 'status' , 
      \ 'priority',
      \ 'author',
      \ 'fixed_version',
      \ 'assigned_to',
      \ 'start_date', 
      \ 'due_date',
      \ 'done_ratio',
      \ 'estimated_hours',
      \ 'spent_hours',
      \ 'created_on',
      \ 'updated_on'
      \ ])
call unite#util#set_default('g:unite_yarm_field_padding_len'  , 15)
call unite#util#set_default('g:unite_yarm_word_fields'        , [])
call unite#util#set_default('g:unite_yarm_word_custom_fields' , [])
" hi - vimrc を読み込み直すと消えちゃう
highlight yarm_ok guifg=white guibg=blue
" フィールドと見なす行数
let s:field_row = 3
"
" source
"
function! unite#sources#yarm#define()
  return s:unite_source
endfunction
" cache
let s:candidates_cache  = []
"
let s:unite_source      = {}
let s:unite_source.name = 'yarm'
let s:unite_source.default_action = {'common' : 'open'}
let s:unite_source.action_table   = {}
" create list
function! s:unite_source.gather_candidates(args, context)
  " parse args
  let option = unite#yarm#parse_args(a:args)
  " clear cache. option に判定メソッドを持たせたい
  if len(option) == 0 && !empty(s:candidates_cache)
    return s:candidates_cache
  endif
  " cache issues
  call unite#yarm#info('now caching issues ...')
  let s:candidates_cache = 
        \ map(unite#yarm#get_issues(option) , '{
        \ "abbr"          : v:val.abbr,
        \ "word"          : v:val.word,
        \ "source"        : "yarm",
        \ "source__issue" : v:val,
        \ "source__type"  : "cache",
        \ }')

  return s:candidates_cache
endfunction
"
" add source with input 
"
function! s:unite_source.change_candidates(args, context)
  let word  = substitute(a:context.input, '\*', '', 'g')
  if word =~ '^#\d\+'
    let no = substitute(word, '#', '', 'g')
    return [{
          \ 'abbr'          : '[get] #' . no ,
          \ 'word'          : '#' . no ,
          \ 'source'        : 'yarm' ,
          \ "source__issue" : {'id' : no} ,
          \ "source__type"  : "get",
          \ }]
  else
    return []
  endif
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
  let issue = a:candidate.source__issue
  " cache manager 作るかなぁ
  if a:candidate.source__type == 'get'
    if !s:is_cached(issue.id)
      try
        let issue = unite#yarm#get_issue(issue.id)
        call add(s:candidates_cache , {
              \ "abbr"          : issue.abbr,
              \ "word"          : issue.word,
              \ "source"        : "yarm",
              \ "source__issue" : issue,
              \ "source__type"  : "cache",
              \ })
        call sort(s:candidates_cache , 's:compare_no')
      catch
        call unite#yarm#error('no issue : #' . issue.id)
        return
      endtry
    else
      let issue = unite#yarm#get_issue(issue.id)
    endif
  endif

  call s:load_issue(issue , 0)
endfunction

function! s:is_cached(id)
  for cache in s:candidates_cache
    if cache.source__issue.id == a:id
      return 1
    endif
  endfor
  return 0
endfunction
"
" compare_no
"
function! s:compare_no(i1, i2)
  return a:i2.source__issue.id - a:i1.source__issue.id
endfunction
"
" action - browser
"
let s:action_table.browser = {'description' : 'open issue with browser'}
function! s:action_table.browser.func(candidate)
  call unite#yarm#open_browser(a:candidate.source__issue.id)
endfunction
"
" action - reget
"
let s:action_table.reget = {'description' : 'reget issue'}
function! s:action_table.reget.func(candidate)
  let id = a:candidate.source__issue.id
  call unite#yarm#info('reget issue #' . id . ' ...')
  call s:load_issue(s:reget_issue(id) , 1)
endfunction
"
" autocmd
"
augroup unite-yarm-issue-setting
  autocmd!
  autocmd FileType yarm call s:yarm_issue_settings()
augroup END  
"
" yarm_issue_settings
"
function! s:yarm_issue_settings()
  nmap <silent> <buffer> <CR> :call <SID>yarm_issue_buffer_action()<CR>
endfunction
"
" yarm_issue_buffer_action
"
function! s:yarm_issue_buffer_action()
  let matched = matchlist(expand('<cWORD>') , 'https\?://\S\+')
  if len(matched) != 0
    echohl yarm_ok | execute "OpenBrowser " . matched[0] | echohl None
    return
  endif
  " get syntax id
  let hiid = synIDattr(synID(line('.'),col('.'),1),'name')
  " open issue
  if hiid =~ 'yarm_title\|yarm_tool_open'
    call unite#yarm#open_browser(b:unite_yarm_issue.id)
  " reload issue
  elseif hiid == 'yarm_tool_reload'
    echohl yarm_ok |let ret = input('reget ? (y/n) : ') |echohl None
    echo ''
    if ret == 'y'
      call s:load_issue(s:reget_issue(b:unite_yarm_issue.id) , 1)
    endif
  " update issue
  elseif hiid == 'yarm_tool_write'
    execute 'w'
  else
    execute "normal! \n"
  endif
endfunction
"
" yarm_put_issue
"
function! s:yarm_put_issue()
  echohl yarm_ok
  if input('update ? (y/n) : ') != 'y'
    return unite#yarm#info('update was canceled')
  endif
  echohl None
  " cached issue
  let issue = b:unite_yarm_issue
  " i want display progress
  call unite#yarm#info('now updating #' . issue.id . ' ...')
  " reget lastest issue
  let pre   = unite#yarm#get_issue(issue.id)
  " check latest
  if pre.updated_on != issue.updated_on
    redraw
    return unite#yarm#error('issue #' . issue.id . ' is already updated')
  endif
  " backup
  call unite#yarm#backup_issue(pre)
  " put issue
  let res   = http#post(issue.rest_url , s:create_put_xml() , 
                          \ {'Content-Type' : 'text/xml'} , 'PUT')
  " split HTTP/1.0 200 OK
  let status = split(res.header[0])[1]
  if status == '200' || status == '100'
    " :wq 保存して閉じる 
    " :w  チケットを取り直して再描画
    redraw
    call s:load_issue(s:reget_issue(issue.id) , 1)
    call unite#yarm#info('#' . issue.id . ' - ' . res.header[0])
  else
    redraw
    call unite#yarm#error('failed - ' . res.header[0])
    for error in xml#parse(res.content).childNodes('error')
      call unite#yarm#error('error : ' . error.value())
    endfor
  endif
endfunction
" - private functions -
"
" load issue to buffer
"
" issue   : 編集対象のチケット情報
" forcely : 強制的に内容を書き換えるか
"
function! s:load_issue(issue, forcely)
  let bufname = 'yarm_' . a:issue.id 
  let bufno   = bufnr(bufname . "$")
  " 強制上書きまたは隠れバッファ(ls!で表示されるもの)の場合
  " 一度消してから開きなおし
  if a:forcely || !buflisted(bufname)
    if bufno != -1
      execute 'bwipeout! ' . bufno
    endif
  " 存在する場合は表示
  else
    execute 'buffer ' . bufno
    return
  endif

  exec 'edit! ' . bufname
  silent %delete _
  setlocal bufhidden=hide
  setlocal noswapfile
"  setlocal fileencoding=utf-8 
"  setlocal fileformat=unix
  setfiletype yarm
  " append issue's fields
  let fields = []
  call add(fields , '<< ' . a:issue.project . ' - #' . a:issue.id . ' ' . a:issue.subject . ' >>')
  call add(fields , '')
  call add(fields , unite#yarm#rjust('[R][O][W]' , strwidth(fields[0])))
  for v in g:unite_yarm_field_order
    call add(fields , unite#yarm#ljust(v , g:unite_yarm_field_padding_len) . ' : ' 
                        \ . (has_key(a:issue , v) ? a:issue[v] : ''))
  endfor
  " append fields
  call append(0 , fields)
  " append custom fields
  for custom in a:issue.custom_fields
    call append(line('$') - 1 , 
          \ unite#yarm#ljust(custom.name , g:unite_yarm_field_padding_len) . ' : ' . custom.value)
  endfor
  " add description
  for line in split(a:issue.description,"\n")
    call append(line('$') , substitute(line , '' , '' , 'g'))
  endfor
  " clear undo
  call unite#yarm#clear_undo()
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
    if !exists('b:unite_yarm_bufwrite_cmd')
      autocmd BufWriteCmd <buffer> call <SID>yarm_put_issue()
      let b:unite_yarm_bufwrite_cmd = 1
    endif
  endif

  " move cursor to top
  :1
  stopinsert
endfunction
"
" create_pu_xml
" 2行目以降にある改行だけの行以降を description とみなす
"
function! s:create_put_xml()
  let issue = xml#createElement('issue')
  let desc  = xml#createElement('description')
  call add(issue.child , desc)
  execute ":" . s:field_row
  let body_start = search('^$' , 'W')
  if body_start != 0
    " 最後の改行が削られるので \n を付ける
    let body = join(getline(body_start + 1 , '$') , '') . ''
    let body = iconv(body , &enc , 'utf-8')
    call desc.value(body)
  endif
  call s:add_updated_node(issue , 'start_date')
  call s:add_updated_node(issue , 'due_date')
  call s:add_updated_node(issue , 'done_ratio')
  "call s:add_updated_node(issue , 'estimated_hours')
  "call s:add_updated_node(issue , 'spent_hours')

  return issue.toString()
endfunction
"
"
"
function! s:add_updated_node(issue, field_name)
  execute ":" . s:field_row
  let value = s:get_field(a:field_name)
  if value != b:unite_yarm_issue[a:field_name]
    let node = xml#createElement(a:field_name)
    call node.value(value)
    call add(a:issue.child , node)
  endif
endfunction
"
"
"
function! s:get_field(name)
  let start = search('^' . a:name . ' .* : .*' , 'W')
  if start == 0
    return 0
  endif
  return matchstr(getline(start) , '^' . a:name . ' .* : \zs.*\ze')
endfunction
"
" reget issue
"
function! s:reget_issue(id)
  let issue = unite#yarm#get_issue(a:id)
  for cache in s:candidates_cache
    " update cache
    if cache.source__issue.id == a:id
      let cache.abbr          = issue.abbr
      let cache.word          = issue.word
      let cache.source__issue = issue
      break
    endif
  endfor
  return issue
endfunction
