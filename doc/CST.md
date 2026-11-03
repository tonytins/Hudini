# CST Format

Caret-Separated Text (CST) is the plain-text format The Sims Online (TSO) uses for
its interface text. Maxis never published a specification, so this one is
reconstructed from TSO's files and from the parsers written for them.
[`CSTCatalog`](../Sources/Hudini/CSTCatalog.swift) implements it, and NSO relies on
it through Hudini.

CST files are not known to appear in any other game.

## How sure each rule is

No rule here has been checked against the original game while it runs. Each carries
one of these labels:

| Label | Meaning |
| --- | --- |
| **Confirmed** | Real files do this in every version checked, and FreeSO's loader or a `.uis` file depends on it. |
| **Observed** | Real files do this, but nothing shows how the game treats it. |
| **Unsettled** | The evidence does not decide it. Hudini's choice is stated, and it may change. |
| **Not seen** | No real file does this. The rule comes from an earlier parser or from design, and readers should accept it anyway. |

The evidence comes from three installs:

| | Beta 1.3.2.121 | Base game 1.145.1.0 | New & Improved 1.1097.1.0 |
| --- | ---: | ---: | ---: |
| Tables | 112 | 113 | 137 |
| Values | 2,561 | 2,795 | 3,588 |
| After a key on the same line | 1,383 | 1,454 | 2,150 |
| With no key on the same line | 1,178 | 1,341 | 1,438 |
| Directory under `gamedata` | `uitext.dir` | `uitext.dir` | `uitext/english.dir` |

## Example

Every rule below applies to this file, which is original to this project. A test
reads it from this page and checks the results listed after it.

<!-- The test named theSpecExampleReadsAsDocumented reads the next block. -->
```text
// A comment. So is a line starting with #, and a /* */ block.
1 ^A value after its key^
    2 ^An indented key^
3
^A key above its value^
4 ^A value that runs
across lines^
ok button ^A key with spaces^
kErrNoFood
^A name above its value^
A note for translators.

^A value with a note above it^
^A value on its own^ with a note after it
^Another value on its own^
```

| Lookup | Result |
| --- | --- |
| `1`, `2`, `3` | The first three values |
| `4` | `A value that runs`, a newline, then `across lines` |
| `ok button` | `A key with spaces` |
| `kErrNoFood` or `5` | `A name above its value` |
| `A note for translators.` or `6` | `A value with a note above it` |
| `7` | `A value on its own` |
| `8` | `Another value on its own` |

## Files

- **Names (Confirmed):** a table is a file named `_<id>_<name>.cst`, where `<id>` is
  a decimal number. Lookups use only the ID. The extension's case does not matter.
- **Other files (Observed):** the base game and beta also hold an unnumbered, empty
  `objectdata.dir/gamecompdrawacard.cst`. Readers should ignore files that do not
  follow the pattern.
- **Layout (Confirmed):** New & Improved uses `gamedata/uitext/<language>.dir`. Earlier
  versions have one language in `gamedata/uitext.dir`.
- **`.uis` references (Confirmed):** a `.uis` file names a table with `stringDir` and
  `stringTable`, and an entry with `stringIndex`. Every real `stringDir` is `UIText`.

## Encoding and line endings

- **Encoding (Confirmed):** a reader must accept UTF-8, with or without a byte order
  mark, and fall back to Windows-1252. Beta and the base game have three non-UTF-8
  tables, and New & Improved has one, the credits. Most files are plain ASCII.
- **Line endings (Observed):** real tables use CRLF, except one with no line break at
  all. Readers should accept LF, CR, CRLF, and U+2028, and convert them to LF before
  reading. Convert CRLF first, or each one becomes two line breaks.

## Entries

A value is the text between two carets. There is no way to escape a caret, so a value
cannot hold one (Confirmed: no real file has an odd number of carets).

A value's keys depend on what comes before its opening caret:

1. **Text on the same line (Confirmed):** that text, trimmed, is the key. It may be a
   number, a word, or several words. FreeSO looks up keys such as `ok button` whole.
2. **A number alone on the nearest line above (Not seen):** that number is the key.
   Earlier parsers accept this layout, and rule 3 shows why it is plausible.
3. **Any other text on the nearest line above (Confirmed):** the value is known by
   that line, trimmed, and also by its position. FreeSO looks up table 137 by names
   such as `kPErrLocationOutOfBounds`, written this way. Others are plainly notes, such
   as `tooltips`. Nothing in the file separates a name from a note.
4. **Nothing above (Confirmed):** the value is known by its position.

Blank lines and comments between a line and its value do not matter.

**Position** counts every value in the table, including those with keys, from 0. Keys
are text, so position 5 is the key `5`.

**Starting from 0 is Unsettled.** FreeSO counts from 0, and NSO's code comes from it,
so Hudini does too. But nothing in the game's files requires it, and two things point
the other way: no numbered table starts at 0, while 111 start at 1, and table 136's own
notes say "Strings 1-3". Only one `.uis` string in each version uses a position,
`EALabelText` in `credits.uis`, at 5. From 0 that is a copyright line, and from 1 it is
a line about Maxis, and either suits the name. The credits screen in the original game
would settle it.

### Text outside values

Text between values that does not become a key is ignored (Confirmed). This includes
any lines above the nearest one, and text after a closing caret on the same line,
which describes the value before it. Tables use this for translators' notes.

### Comments

- **`//` (Confirmed):** a line whose first non-space characters are `//` is a comment.
  Real tables use these throughout.
- **`#` (Observed):** the same, though only two real lines start this way, both headers
  naming their file. Since text outside values is ignored anyway, little depends on it.
- **`/*` (Not seen):** starts a comment that runs to the end of the line holding `*/`.

Comments are removed before anything else, so a comment line inside a value is not part
of it. No real value has such a line, so this case is Not seen too.

### Values

- **Multiline (Confirmed):** a value runs until its closing caret, and keeps its line
  breaks and spacing exactly.
- **Empty (Observed):** `^^` is a valid, empty value that still takes a position. Tables
  such as 138 hold dozens of them.

### Malformed tables

No real table has these, so the handling is Hudini's design rather than a finding.

- **Unclosed values:** a closing caret that belongs to a line holding a whole entry
  means the previous value was never closed. Skip that value and report it, but still
  count its position. Without this, one stray caret misreads every later entry.
- **Reading never fails:** a table with one bad entry is still useful, so report the
  problem and keep the rest. Only an unreadable file or directory is an error.
- **Missing text:** report it as missing rather than returning a marker string, which
  a program cannot tell from real text.

## Repeated keys

**Unsettled.** Table 237 is the only real case, in all three versions: its key `2`
appears twice, and the numbering suggests a typo. Hudini keeps the first and reports the
second. FreeSO keeps the last.

A key from rule 1 or 2 always wins over a name from rule 3 without a report, whichever
comes first.

## Keys with two numbers

**Unsettled.** Fifteen entries in New & Improved's table 210 look like `24 012 ^...^`,
likely a position and a server reason code. Hudini keeps `24 012` as the whole key.

## References

Thirty-nine entries in New & Improved's table 208 hold a reference instead of text. They
start with the control character U+0002 (Confirmed: all 39 resolve):

```text
16 ^<U+0002><cst><cst_id>276</cst_id><string_id>1</string_id></cst>^
17 ^<U+0002><cst><cst_id>276</cst_id><string_id>2</string_id><string arg="1">%s</string></cst>^
```

`cst_id` is a table and `string_id` is a key. Hudini returns the target's text and stops
at one reference, so a cycle cannot hang it. It passes arguments in order and ignores
`arg` numbers. All real ones are `arg="1"`, so their order is untested (Unsettled).

## Placeholders

Placeholders are filled in order by code that uses the text, so readers should return
them untouched unless asked to fill them.

| Placeholder | Status | Meaning |
| --- | --- | --- |
| `%s` | Confirmed | Text |
| `%d`, `%i`, `%u` | Observed | A number |
| `%ld` | Observed | A number. Treated like `%d`. |
| `%.2d`, `%02d` | Observed | A number padded with zeros, such as a skill's `5.07` or a clock's `05:30` |
| `%3d` | Not seen | Hudini pads with spaces, as C does. |
| `%%` | Observed | One percent sign |

Some real text uses a lone `%` or `$` as a placeholder, as in `to sell % for $`, or
`<%>` in chat messages. Hudini leaves these for game code. A placeholder with no argument
left stays as written, so the mistake is visible.

## Where FreeSO differs

FreeSO's loader is the closest thing to a reference, but it is a reconstruction too.
These differences are deliberate.

| Case | FreeSO | This specification |
| --- | --- | --- |
| A note above a value | Becomes the only key, so the value has no position | The value has both |
| Text after a closing caret | Can become the next value's key | Ignored |
| `#` and `/*` comments | Treated as text outside values | Comments |
| An indented `//` line inside a value | Part of the value | A comment |
| A repeated key | Last wins | First wins, and it is reported |
| An unclosed value | Misreads the rest of the table | Skipped and reported |

## Checking a reader

A reader should be checked against more than hand-written samples. Hand-written files
tend to hold only the shapes their author already knows about, and real tables have
keyless values, indented keys, notes, CRLF, and Windows-1252, often at once. With an
install, check that every string a version's `.uis` files use is found. Hudini's test
`catalogReadsEveryLocalVersion` does this when `TSO_BETA_DIR`, `TSO_CLASSIC_DIR`, or
`TSO_GAME_DIR` is set. Without one, this page's example covers the same shapes.

## Acknowledgments

This builds on [CST.NET](https://github.com/tonytins/cstdotnet),
[cstrs](https://github.com/tonytins/cstrs), and
[SwiftCST](https://github.com/tonytins/swift-cst), written without access to real files,
and on [FreeSO](https://github.com/riperiperi/FreeSO)'s loader. Treating text outside
carets as ignorable first appears in cstrs, and keys above values and unclosed-value
handling come from SwiftCST.
