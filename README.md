# Efene for Sublime Text

Syntax highlighting for [efene](https://github.com/efene/efene) (`.fn` and
`.hfn` files) in Sublime Text 3 and 4.

It highlights:

- top level functions (`fn name`), they're listed in Goto Symbol (Ctrl+R / Cmd+R)
- keywords (`case`, `else`, `match`, `when`, `try`, `receive`, `for`...) and word
  operators (`and`, `or`, `not`, `is`...)
- calls, including module calls (`lists.map(...)`), nested modules
  (`shapes.geo.point.new(...)`), dynamic ones (`Mod.Fun(...)`) and quoted
  modules (`` `Elixir.Postgrex`.query(...) ``)
- function references (`fn lists.map:2`)
- attributes (`@public`, `@import(...)`), `@doc(...)` strings as documentation
- tags (`#i`, `#r.record.field`, `#c`, `#ct`, `^b`...)
- strings, binary strings (`'...'`), escapes and `io:format` directives (`~p`)
- quoted atoms (`` `an atom` ``), atoms, variables, numbers, booleans
- map keys (`{name: Value}`)

Efene has no comments, so there's no comment toggling.

## Install

Clone this repository into your Sublime Text `Packages` directory (Preferences >
Browse Packages...) as `Efene`:

```
cd "<Packages directory>"
git clone https://github.com/bulatshafigullin/sublime-efene.git Efene
```

The `.fn` files open with the Efene syntax.

## Tests

`syntax_test_efene.fn` is a Sublime Text syntax test, run it in Sublime with
Tools > Build while the file is open, or without Sublime:

```
ruby tools/syntax_test.rb Efene.sublime-syntax syntax_test_efene.fn
```

`tools/syntax_test.rb` implements the parts of the `.sublime-syntax` format this
syntax uses with Ruby's regex engine (Onigmo, a fork of the Oniguruma engine
Sublime Text 3 uses).
