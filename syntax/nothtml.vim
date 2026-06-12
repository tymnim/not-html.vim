if exists("b:current_syntax")
  finish
endif

syn match nothtmlEscape /\\./ contained

syn match nothtmlElement /\~\w\+/ nextgroup=nothtmlAttrs skipwhite
syn match nothtmlTilde /\~/ contained containedin=nothtmlElement

" Comments: ~! { ... } or ~!{ ... }
syn region nothtmlComment start="\~!\s*{" end="}" contains=nothtmlCommentEscape
syn match nothtmlCommentEscape /\\./ contained

" DOCTYPE: ~!doctype(html)
syn match nothtmlDoctype /\~!doctype/ nextgroup=nothtmlAttrs skipwhite

" Attributes: (name: value, bool-attr)
syn region nothtmlAttrs matchgroup=nothtmlParen start="(" end=")" contained contains=nothtmlAttrName,nothtmlBoolAttr,nothtmlComma,nothtmlEscape
syn match nothtmlAttrName /[[:alnum:]_-]\+\ze\s*:/ contained nextgroup=nothtmlColon skipwhite
syn match nothtmlBoolAttr /[[:alnum:]_-]\+\ze\s*[,)]/ contained
syn match nothtmlColon /:/ contained nextgroup=nothtmlAttrValue skipwhite
syn match nothtmlAttrValue /[^,)\\]*\(\\.[^,)\\]*\)*/ contained contains=nothtmlEscape

syn match nothtmlBrace /[{}]/

hi def link nothtmlTilde Special
hi def link nothtmlElement Function
hi def link nothtmlDoctype PreProc
hi def link nothtmlComment Comment
hi def link nothtmlCommentEscape SpecialChar
hi def link nothtmlAttrName Identifier
hi def link nothtmlBoolAttr Constant
hi def link nothtmlAttrValue String
hi def link nothtmlColon Operator
hi def link nothtmlComma Delimiter
hi def link nothtmlParen Delimiter
hi def link nothtmlBrace Delimiter
hi def link nothtmlEscape SpecialChar

let b:current_syntax = "nothtml"
