
function! unite#sources#outline#redmine#outline_info()
  return s:outline_info
endfunction

"unite outline

if !exists('g:unite_source_outline_info')
  let g:unite_source_outline_info = {}
endif

let s:outline_info = {
      \ 'heading': '^h[1-9]\.*' , 
      \}

function! s:outline_info.create_heading(which, heading_line, matched_line, context)
  let word  = matchstr(a:heading_line , '^h[1-9]\.\zs.*\ze')
  let level = matchstr(a:heading_line , '^h\zs[1-9]\ze\.')
  let heading = {
        \ 'word' : word ,
        \ 'level': str2nr(level),
        \ }
  return heading
endfunction

" vim: filetype=vim
