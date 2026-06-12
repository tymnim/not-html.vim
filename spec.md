# not_html Language Specification

**Version**: 2.0.0
**Implementation language**: Lua (Neovim plugin)
**Target output**: HTML

## Overview

`not_html` is an HTML preprocessor that defines a concise, indentation-agnostic syntax for authoring HTML documents. The source is processed through a three-stage pipeline — lexer, parser, renderer — to produce formatted HTML output. A reverse pipeline — HTML parser, decompiler — converts HTML back to `not_html`, enabling transparent editing of `.html` files in `not_html` syntax within Neovim.

## Syntax

### Elements

Elements are declared with a tilde (`~`) prefix followed by a tag name.

```
~div
~html
~button
```

An element may optionally have **attributes** and/or a **body**.

### Full element form

```
~tagname(attributes) { children }
```

All parts except `~tagname` are optional, yielding these valid forms:

| Form | Meaning |
|---|---|
| `~tag` | Element with no attributes and no body |
| `~tag(attrs)` | Element with attributes, no body |
| `~tag { children }` | Element with body, no attributes |
| `~tag(attrs) { children }` | Element with attributes and body |
| `~tag()` | Element with empty attribute list, no body |
| `~tag() {}` | Element with empty attribute list and empty body |

### Attributes

Attributes are enclosed in parentheses `( )` and separated by commas.

#### Key-value attributes

A key and value are separated by a colon (`:`). Whitespace around the colon is permitted.

```
~html(lang: en)
~link(rel: stylesheet, href: styles.css)
```

Attribute values are unquoted. A value runs from after the colon up to the next comma `,` or closing paren `)`. This means values may contain spaces:

```
~div(class: some-class active)       → class="some-class active"
~html(version: 1 2 3)                → version="1 2 3"
```

#### Boolean attributes

An attribute name without a colon or value is treated as a boolean (valueless) attribute.

```
~script(defer)                        → <script defer></script>
~script(type: module, defer, src: x)  → <script type="module" defer src="x"></script>
```

#### Empty attribute list

An empty pair of parentheses is valid and produces no attributes:

```
~div()                                → <div></div>
```

### Body / Children

A body is enclosed in curly braces `{ }` and may contain any mix of nested elements and text.

```
~div {
  ~h1 { Welcome }
  Some text here
  ~button { Click Me }
}
```

### Text

Any content not preceded by `~` is treated as plain text. Consecutive non-element words within a body are joined into a single text node.

```
~p { Hello World }       → Text("Hello World")
```

Text can also appear at the top level:

```
hello                    → Text("hello")
```

### Inline text after void elements

Text that follows a void element (outside braces) becomes a sibling text node, not a child:

```
~br lorem ipsum          → <br/> followed by text "lorem ipsum"
```

### Escape sequences

The backslash (`\`) escapes the next character, preventing it from being treated as a breaking/special character. This allows literal use of reserved characters in attribute names, values, and text.

**Breaking characters** (have syntactic meaning): `{ } ( ) ~ , : <space> <newline>`

Examples:

```
~div(style: height\: 100px; background\: red)
```

Produces `style="height: 100px; background: red"` — the escaped colons are treated as literal characters in the value.

```
~p { \~not an element }
```

Produces text `~not an element` — the escaped tilde is literal.

```
~html(defer\(\))
```

Produces boolean attribute `defer()` — the parentheses are escaped.

### DOCTYPE

The HTML `<!DOCTYPE html>` declaration is represented using the special `~!doctype` element with the doctype value as an attribute:

```
~!doctype(html)
```

This compiles to `<!DOCTYPE html>`. The match is case-insensitive when parsing HTML.

### Comments

HTML comments are represented using the `~!` tag with a body:

```
~! { This is a comment }
```

This compiles to `<!-- This is a comment -->`.

Multiline comments use the standard body syntax. Each line of text in the body becomes a separate line in the HTML comment:

```
~! {
  First line
  Second line
}
```

Compiles to:

```html
<!--
  First line
  Second line
-->
```

Breaking characters within comment text must be escaped (e.g., `\:` for a literal colon, `\,` for a literal comma).

### Blank lines

Blank lines (two or more consecutive newlines) in the source are preserved through the pipeline. They appear as empty lines in the compiled HTML output, maintaining the visual structure of the document.

### Newline preservation

Single newlines act as line separators. Text on different lines remains as separate text nodes rather than being joined. This ensures that the line structure of the source is preserved when compiling to HTML.

## Processing Pipeline

### Stage 1: Lexer

**Input**: Source string
**Output**: List of string tokens (lexemes)

The lexer splits the input on breaking characters (`{ } ( ) ~ , : <space> <newline>`) while respecting escape sequences. It then:

1. Strips empty/whitespace-only tokens.
2. Emits `\n` tokens for single newlines (line separators that keep text on separate lines as distinct tokens).
3. Emits `\n\n` tokens for two or more consecutive newlines (blank line markers).
4. Joins consecutive non-structural tokens on the same line into single text lexemes (e.g., `Hello` + `World` → `Hello World`).

Structural tokens that break text joining: `{ } ( ) ~ , : \n \n\n`

Example:

```
"~html(lang: en) {\n  some text\n}"
→ ["~", "html", "(", "lang", ":", "en", ")", "{", "\n", "some text", "\n", "}"]
```

### Stage 2: Parser

**Input**: List of lexemes
**Output**: A list of AST nodes or an error message

The parser produces an AST with three node types:

```
Element =
  | Node(tag_name, attributes: List({name, value}), children: List(Element))
  | Text(content: String)
  | Blank
```

#### Parsing rules

1. `~` signals the start of an element. The next lexeme is the tag name.
2. If `(` follows the tag name, parse attributes until `)`.
3. If `{` follows (after attributes or tag name), parse children recursively until `}`.
4. `\n` tokens are consumed as line separators (they are not added to the AST).
5. `\n\n` tokens become `Blank` nodes in the AST.
6. Any other lexeme is parsed as a `Text` node.
7. Boolean attributes are stored as `{name, ""}` (empty string value).

#### Error conditions

- **Unexpected end of input (EOF)**: Input ends where a token was expected.
- **Unexpected token**: A structural token (`(`, `{`, `}`, `)`, `~`) appears in an invalid position, such as inside an attribute value.

```
~html(defer())    → Error: unexpected ( in attribute context
~html(defer{})    → Error: unexpected { in attribute context
~html(name: ))    → Error: expected attribute value, got )
~html(name: ~)    → Error: expected attribute value, got ~
```

### Stage 3: Renderer

**Input**: `List(Element)`
**Output**: HTML string

The renderer converts the AST to an indented HTML string with these rules:

#### Indentation

Each nesting level adds 2 spaces of indentation.

#### Void elements

The following HTML void elements are self-closing when they have no children:

```
area, base, br, col, embed, hr, img, input, link, meta, source, track, wbr
```

They render as `<tag/>` or `<tag attr="val"/>`.

#### Non-void elements

Non-void elements always render with opening and closing tags, even when empty:

```
~div()  →  <div></div>
```

#### Attribute rendering

- Key-value attributes render as `key="value"`.
- Boolean attributes render as just the name (no `=`).
- Multiple attributes are space-separated in the opening tag.

#### Text nodes

Text nodes render as-is at the current indentation level.

#### DOCTYPE nodes

`!doctype` nodes render as `<!DOCTYPE value>`:

```
~!doctype(html)  →  <!DOCTYPE html>
```

#### Comment nodes

`!` nodes render as HTML comments. A single text child produces a single-line comment; multiple text children produce a multiline comment:

```
~! { todo }  →  <!-- todo -->
```

```
~! {
  line 1
  line 2
}
```
→
```html
<!--
  line 1
  line 2
-->
```

#### Blank nodes

`Blank` nodes render as empty strings, producing blank lines in the output when joined with other elements.

## Full Example

### Input

```
~!doctype(html)
~html(lang: en) {
  ~head {
    ~title { My Document }
    ~link(rel: stylesheet, href: styles.css)
    ~meta(charset: utf-8)
  }
  ~body {
    ~header(class: site-header, id: header) {
      ~! { Page heading }
      ~h1 { Welcome to this page! }
    }
    ~div(style: height\: 100px; background\: red) {
      ~button { Click Me! }
    }
  }
}
```

### Output

```html
<!DOCTYPE html>
<html lang="en">
  <head>
    <title>
      My Document
    </title>
    <link rel="stylesheet" href="styles.css"/>
    <meta charset="utf-8"/>
  </head>
  <body>
    <header class="site-header" id="header">
      <!-- Page heading -->
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
</html>
```

## Grammar (informal)

```
document     = (element | doctype | comment | text | blank)*
element      = "~" tagname attributes? body?
doctype      = "~" "!doctype" attributes
comment      = "~" "!" body
tagname      = identifier
attributes   = "(" attribute ("," attribute)* ")"
             | "(" ")"
attribute    = identifier ":" value
             | identifier
value        = (non-breaking-char | escaped-char)+
body         = "{" (element | doctype | comment | text | blank)* "}"
text         = (word (" " word)*)+
blank        = "\n" "\n"
identifier   = (non-breaking-char | escaped-char)+
escaped-char = "\" <any-char>
```

**Breaking characters**: `{ } ( ) ~ , : <space> <newline>`

Any breaking character preceded by `\` is treated as a literal character.

## Decompilation: HTML to not_html

This section specifies how standard HTML is converted into the not_html syntax (the inverse of rendering).

### General rules

1. Every HTML element becomes `~tagname`.
2. Opening/closing tag pairs collapse into a single `~tagname { ... }` or `~tagname` form — there is never an explicit closing construct.
3. Whitespace-only text nodes between elements are discarded.
4. Indentation in the output is purely cosmetic and has no semantic meaning; a canonical decompilation uses 2-space indent increments matching the forward renderer.

### Tag conversion

| HTML | not_html |
|---|---|
| `<div></div>` | `~div` |
| `<div>children</div>` | `~div { children }` |
| `<br/>` or `<br>` | `~br` |
| `<img src="x.png"/>` | `~img(src: x.png)` |

Void elements (`area`, `base`, `br`, `col`, `embed`, `hr`, `img`, `input`, `link`, `meta`, `source`, `track`, `wbr`) never produce a body, even if written as `<br></br>` in the source HTML.

### Attribute conversion

#### Key-value attributes

HTML `key="value"` becomes `key: value` (quotes are stripped).

```html
<div class="container" id="main">
```
```
~div(class: container, id: main)
```

#### Boolean attributes

HTML boolean attributes (no value, or value equals the attribute name) become bare names.

```html
<script defer src="app.js">
<input disabled="">
<option selected="selected">
```
```
~script(defer, src: app.js)
~input(disabled)
~option(selected)
```

#### Values containing breaking characters

If an attribute value contains characters that are syntactically meaningful in not_html, those characters must be escaped with `\`.

| Character in value | Escaping needed |
|---|---|
| `:` | `\:` |
| `,` | `\,` |
| `(` | `\(` |
| `)` | `\)` |
| `{` | `\{` |
| `}` | `\}` |
| `~` | `\~` |

```html
<div style="height: 100px; background: red">
```
```
~div(style: height\: 100px; background\: red)
```

Spaces within values do **not** need escaping — a value runs until the next `,` or `)`.

### Text conversion

HTML text content becomes inline text in the not_html body.

```html
<p>Hello World</p>
```
```
~p { Hello World }
```

If the text contains a literal `~`, it must be escaped:

```html
<p>Price ~5 dollars</p>
```
```
~p { Price \~5 dollars }
```

Similarly, literal `{` and `}` in text must be escaped:

```html
<code>fn() { return 1; }</code>
```
```
~code { fn() \{ return 1; \} }
```

### Nested elements

Nesting translates directly — each child element or text node appears inside the parent's `{ }` body.

```html
<ul>
  <li>One</li>
  <li>Two</li>
</ul>
```
```
~ul {
  ~li { One }
  ~li { Two }
}
```

### Mixed content (elements and text)

When an element contains both text and child elements, each appears in order inside the body.

```html
<p>Click <a href="url">here</a> to continue</p>
```
```
~p { Click ~a(href: url) { here } to continue }
```

### DOCTYPE

`<!DOCTYPE html>` is preserved as `~!doctype(html)` using the attribute syntax:

```html
<!DOCTYPE html>
```
```
~!doctype(html)
```

The match is case-insensitive; `<!doctype html>` and `<!DOCTYPE html>` both decompile to `~!doctype(html)`.

### Comments

HTML comments are preserved using the `~!` tag. The comment content becomes the body:

```html
<!-- TODO: website -->
```
```
~! { TODO\: website }
```

Multiline comments split each line into a separate text child:

```html
<!--
  First line
  Second line
-->
```
```
~! {
  First line
  Second line
}
```

Breaking characters within comment text are escaped (e.g., `\:` for colons, `\,` for commas).

### Blank lines

Blank lines (two or more consecutive newlines) in the HTML source are preserved as `Blank` nodes, which render as empty lines in the `not_html` output.

### Inline vs. multiline rendering

When an element has exactly one text child, it is rendered inline:

```
~p { Hello World }
```

When an element has multiple children (text or elements), the body is rendered with each child on its own line:

```
~div {
  ~p { one }
  ~p { two }
}
```

### Full decompilation example

#### HTML input

```html
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8"/>
    <title>My Page</title>
    <link rel="stylesheet" href="styles.css"/>
    <script type="module" defer src="app.js"></script>
  </head>
  <body>
    <header class="site-header" id="header">
      <!-- Site heading -->
      <h1>Welcome!</h1>
    </header>
    <main>
      <p>Hello <strong>World</strong></p>
      <br/>
      <button disabled>Click Me</button>
    </main>
  </body>
</html>
```

#### not_html output

```
~!doctype(html)
~html(lang: en) {
  ~head {
    ~meta(charset: utf-8)
    ~title { My Page }
    ~link(rel: stylesheet, href: styles.css)
    ~script(type: module, defer, src: app.js)
  }
  ~body {
    ~header(class: site-header, id: header) {
      ~! { Site heading }
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
}
```
