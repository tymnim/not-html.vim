-- Run with: nvim -l test/test_lua.lua
package.path = "lua/?.lua;" .. package.path

local lexer = require("not_html.lexer")
local parser = require("not_html.parser")
local renderer = require("not_html.renderer")
local html_parser = require("not_html.html_parser")
local decompiler = require("not_html.decompiler")

local passed = 0
local failed = 0

local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
    print("  PASS  " .. name)
  else
    failed = failed + 1
    print("  FAIL  " .. name .. ": " .. tostring(err))
  end
end

local function eq(a, b, msg)
  if type(a) == "table" and type(b) == "table" then
    assert(#a == #b, (msg or "") .. " length mismatch: " .. #a .. " vs " .. #b)
    for i = 1, #a do
      eq(a[i], b[i], (msg or "") .. "[" .. i .. "]")
    end
  else
    assert(a == b, (msg or "") .. " expected " .. tostring(b) .. ", got " .. tostring(a))
  end
end

-- Lexer tests -----------------------------------------------------------------

print("\n--- Lexer ---")

test("simple tag", function()
  eq(lexer.lex("~div"), { "~", "div" })
end)

test("tag with attrs", function()
  eq(lexer.lex("~html(lang: en)"), { "~", "html", "(", "lang", ":", "en", ")" })
end)

test("tag with body", function()
  eq(lexer.lex("~div { hello world }"), { "~", "div", "{", "hello world", "}" })
end)

test("full example from spec", function()
  eq(
    lexer.lex("~html(lang: en) { some text}"),
    { "~", "html", "(", "lang", ":", "en", ")", "{", "some text", "}" }
  )
end)

test("escape colon", function()
  eq(
    lexer.lex("~div(style: height\\: 100px)"),
    { "~", "div", "(", "style", ":", "height: 100px", ")" }
  )
end)

test("escape tilde", function()
  eq(
    lexer.lex("~p { \\~not an element }"),
    { "~", "p", "{", "~not an element", "}" }
  )
end)

-- Parser tests ----------------------------------------------------------------

print("\n--- Parser ---")

test("simple tag", function()
  local els = assert(parser.parse({ "~", "div" }))
  assert(#els == 1)
  assert(els[1].tag == "div")
  assert(#els[1].children == 0)
end)

test("tag with attrs", function()
  local els = assert(parser.parse({ "~", "html", "(", "lang", ":", "en", ")" }))
  assert(els[1].attrs[1][1] == "lang")
  assert(els[1].attrs[1][2] == "en")
end)

test("tag with body", function()
  local els = assert(parser.parse({ "~", "div", "{", "hello", "}" }))
  assert(els[1].children[1].type == "text")
  assert(els[1].children[1].content == "hello")
end)

test("boolean attr", function()
  local els = assert(parser.parse({ "~", "script", "(", "defer", ")" }))
  assert(els[1].attrs[1][1] == "defer")
  assert(els[1].attrs[1][2] == "")
end)

test("nested elements", function()
  local els = assert(parser.parse({ "~", "div", "{", "~", "p", "{", "hi", "}", "}" }))
  assert(els[1].children[1].tag == "p")
  assert(els[1].children[1].children[1].content == "hi")
end)

-- Renderer tests --------------------------------------------------------------

print("\n--- Renderer ---")

test("void element", function()
  local html = renderer.render({ { type = "node", tag = "br", attrs = {}, children = {} } })
  assert(html == "<br/>", "got: " .. html)
end)

test("void with attrs", function()
  local html = renderer.render({
    { type = "node", tag = "img", attrs = { { "src", "cat.png" } }, children = {} },
  })
  assert(html == '<img src="cat.png"/>', "got: " .. html)
end)

test("element with text", function()
  local html = renderer.render({
    { type = "node", tag = "p", attrs = {}, children = { { type = "text", content = "hello" } } },
  })
  assert(html == "<p>\n  hello\n</p>", "got: " .. html)
end)

test("boolean attr rendering", function()
  local html = renderer.render({
    { type = "node", tag = "script", attrs = { { "defer", "" } }, children = {} },
  })
  assert(html == "<script defer></script>", "got: " .. html)
end)

-- HTML Parser tests -----------------------------------------------------------

print("\n--- HTML Parser ---")

test("simple div", function()
  local els = html_parser.parse("<div></div>")
  assert(#els == 1)
  assert(els[1].tag == "div")
end)

test("self-closing", function()
  local els = html_parser.parse("<br/>")
  assert(#els == 1)
  assert(els[1].tag == "br")
end)

test("void without slash", function()
  local els = html_parser.parse("<br>")
  assert(#els == 1)
  assert(els[1].tag == "br")
end)

test("with attrs", function()
  local els = html_parser.parse('<div class="container"></div>')
  assert(els[1].attrs[1][1] == "class")
  assert(els[1].attrs[1][2] == "container")
end)

test("nested", function()
  local els = html_parser.parse("<div><p>hello</p></div>")
  assert(els[1].children[1].tag == "p")
  assert(els[1].children[1].children[1].content == "hello")
end)

test("comment preserved", function()
  local els = html_parser.parse("<!-- comment --><div></div>")
  assert(#els == 2)
  assert(els[1].tag == "!")
  assert(els[1].children[1].content == "comment")
  assert(els[2].tag == "div")
end)

test("doctype preserved", function()
  local els = html_parser.parse("<!DOCTYPE html><html></html>")
  assert(#els == 2)
  assert(els[1].tag == "!doctype")
  assert(els[1].attrs[1][1] == "html")
  assert(els[2].tag == "html")
end)

-- Roundtrip tests -------------------------------------------------------------

print("\n--- Roundtrip ---")

test("simple roundtrip", function()
  local input = "~div { hello }"
  local tokens = lexer.lex(input)
  local elements = assert(parser.parse(tokens))
  local html = renderer.render(elements)
  local els2 = html_parser.parse(html)
  local html2 = renderer.render(els2)
  assert(html == html2, "html mismatch:\n" .. html .. "\nvs\n" .. html2)
end)

test("roundtrip with attrs", function()
  local input = "~img(src: cat.png, alt: A cute cat)"
  local tokens = lexer.lex(input)
  local elements = assert(parser.parse(tokens))
  local html = renderer.render(elements)
  local els2 = html_parser.parse(html)
  local html2 = renderer.render(els2)
  assert(html == html2, "html mismatch:\n" .. html .. "\nvs\n" .. html2)
end)

test("full spec example compile", function()
  local input = [[~html(lang: en) {
  ~head {
    ~title { My Document }
    ~link(rel: stylesheet, href: styles.css)
    ~meta(charset: utf-8)
  }
  ~body {
    ~header(class: site-header, id: header) {
      ~h1 { Welcome to this page! }
    }
    ~div(style: height\: 100px; background\: red) {
      ~button { Click Me! }
    }
  }
}]]

  local expected = [[<html lang="en">
  <head>
    <title>
      My Document
    </title>
    <link rel="stylesheet" href="styles.css"/>
    <meta charset="utf-8"/>
  </head>
  <body>
    <header class="site-header" id="header">
      <h1>
        Welcome to this page!
      </h1>
    </header>
    <div style="height: 100px; background: red">
      <button>
        Click Me!
      </button>
    </div>
  </body>
</html>]]

  local tokens = lexer.lex(input)
  local elements = assert(parser.parse(tokens))
  local html = renderer.render(elements)
  assert(html == expected, "mismatch:\n" .. html)
end)

test("full spec example decompile", function()
  local html = [[<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8"/>
    <title>My Page</title>
    <link rel="stylesheet" href="styles.css"/>
    <script type="module" defer src="app.js"></script>
  </head>
  <body>
    <header class="site-header" id="header">
      <h1>Welcome!</h1>
    </header>
    <main>
      <p>Hello <strong>World</strong></p>
      <br/>
      <button disabled>Click Me</button>
    </main>
  </body>
</html>]]

  local expected = [[~!doctype(html)
~html(lang: en) {
  ~head {
    ~meta(charset: utf-8)
    ~title { My Page }
    ~link(rel: stylesheet, href: styles.css)
    ~script(type: module, defer, src: app.js)
  }
  ~body {
    ~header(class: site-header, id: header) {
      ~h1 { Welcome! }
    }
    ~main {
      ~p {
        Hello
        ~strong { World }
      }
      ~br
      ~button(disabled) { Click Me }
    }
  }
}]]

  local elements = html_parser.parse(html)
  local result = decompiler.decompile(elements)
  assert(result == expected, "mismatch:\n" .. result)
end)

-- Summary ---------------------------------------------------------------------

print(string.format("\n%d passed, %d failed\n", passed, failed))
if failed > 0 then
  os.exit(1)
end
