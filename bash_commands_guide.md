# Bash Commands Reference Guide — Based on the BVCS Script

This guide covers every command/construct used in your `bvcs.sh` script, explained fully with all major variations — not just the flags you happened to use.

---

## 1. `test` / `[ ]` — Condition Checks

Your script uses `[ ]` constantly (`[ -d ".bvcs" ]`, `[ -f "$file" ]`, etc). `[ ... ]` is literally the `test` command in disguise — `[ -f "$file" ]` and `test -f "$file"` are identical. The closing `]` is just a required "argument" to the `[` command.

### File-type tests (used: `-f`, `-d`, `-s`)

| Flag | Meaning | Used in script for |
|---|---|---|
| `-f file` | True if file exists **and is a regular file** | `[ -f "$file" ]` in `add_files` — checks the file being staged actually exists as a normal file (not a directory) |
| `-d file` | True if file exists **and is a directory** | `[ ! -d ".bvcs" ]` — checks whether the repo folder exists |
| `-s file` | True if file exists **and has size > 0** (not empty) | `[ -s ".bvcs/staging" ]` — checks staging file isn't empty before allowing a commit |
| `-e file` | True if file exists (any type — regular, dir, symlink, etc.) | Not used, but useful as a generic existence check |
| `-L file` | True if file is a symbolic link | — |
| `-r file` | True if file is readable | — |
| `-w file` | True if file is writable | — |
| `-x file` | True if file is executable | — |
| `-z string` | True if string length is **zero** (empty string) | `[ -z "$2" ]` in `do_commit` — checks the commit message is not empty; also `[ -z "${files[$rel_w_file]}" ]` — checks associative array key is unset |
| `-n string` | True if string length is **nonzero** | Opposite of `-z`, not used here but common |

**Negation:** `!` flips any test. `[ ! -d ".bvcs" ]` means "directory does NOT exist."

### String comparisons (used: `==`, `!=`)

| Operator | Meaning |
|---|---|
| `"$a" == "$b"` | String equality (Bash extension; POSIX uses single `=`) |
| `"$a" != "$b"` | String inequality |
| `-z "$a"` | Empty string |
| `-n "$a"` | Non-empty string |

Used everywhere: `[ "${1}" == "init" ]`, `[ "$response" == "y" ]`, etc.

### Numeric comparisons (used: `-eq`, `-lt`, `-gt`)

| Operator | Meaning |
|---|---|
| `-eq` | Equal to |
| `-ne` | Not equal to |
| `-lt` | Less than |
| `-le` | Less than or equal |
| `-gt` | Greater than |
| `-ge` | Greater than or equal |

Used in `do_commit`: `[ $# -eq 0 ] || [ $# -lt 2 ]` (checks argument count), and in `show_status`: `[ $st -gt 0 ]` (checks if there are staged files to display).

⚠️ Note: `-eq`/`-lt`/`-gt` are for **numbers only**. Using them on strings breaks. Use `==`/`!=` for strings, `-eq` etc. for integers.

### Combining conditions

- `[ A ] && [ B ]` — AND (short-circuit)
- `[ A ] || [ B ]` — OR (short-circuit)
- `[[ A && B ]]` — Bash's extended test, allows `&&`/`||` *inside* one bracket (not used here, but common alternative)

Your script uses the `[ A ] || [ B ]` chained-OR style in `do_commit`:
```bash
if [ $# -eq 0 ] || [ $# -lt 2 ] || [ "$1" != "-m" ] || [ -z "$2" ]; then
```
This reads as: "fail if no args, OR fewer than 2 args, OR first arg isn't `-m`, OR message is empty."

---

## 2. `mkdir` — Make Directories

| Flag | Meaning |
|---|---|
| `-p` | **Parents** — create intermediate directories as needed, and don't error if the directory already exists |
| `-v` | Verbose — print a message for each directory created |
| `-m MODE` | Set permissions (like `mkdir -m 755 dir`) |

Script usage:
```bash
mkdir .bvcs
mkdir -p ".bvcs/objects/$filled/files"
```
Plain `mkdir .bvcs` (no `-p`) is used in `init_repo` because at that point we already know `.bvcs` doesn't exist. `-p` is used elsewhere (`do_commit`, `add_files`'s `mkdir -p "$(dirname "$dest")"`) because the nested path (e.g. `objects/0001/files/subdir/`) may need multiple levels created at once, and we don't want an error if part of the path already exists.

---

## 3. `touch` — Create Empty Files / Update Timestamps

| Usage | Meaning |
|---|---|
| `touch file` | Create `file` if it doesn't exist (empty); if it exists, just update its modification time |
| `touch -a file` | Update only access time |
| `touch -m file` | Update only modification time |
| `touch -d "date string" file` | Set a specific timestamp |
| `touch -t YYYYMMDDhhmm file` | Set a specific timestamp (compact form) |

Script usage: `touch staging`, `touch log`, `touch HEAD` — simply creates the three empty bookkeeping files needed by a fresh repo.

---

## 4. `grep` — Pattern Search

Script usage:
```bash
grep -qxF "$norm" .bvcs/staging
```

| Flag | Meaning |
|---|---|
| `-q` | **Quiet** — suppress output, only return exit code (0 = found, 1 = not found). Perfect for use inside `if`. |
| `-x` | **Exact line match** — the pattern must match the *entire* line, not just a substring. Without this, staging `"a.txt"` would also match a line containing `"a.txt.bak"`. |
| `-F` | **Fixed string** — treat the pattern as a literal string, not a regex. Prevents special characters (like `.`, `*`, `[`) in filenames from being interpreted as regex metacharacters. |
| `-i` | Case-insensitive matching |
| `-v` | Invert match — show lines that **don't** match |
| `-n` | Show line numbers with matches |
| `-r` / `-R` | Recursive search through directories |
| `-l` | Only print filenames that contain a match (not the matching lines) |
| `-c` | Print a count of matching lines instead of the lines themselves |
| `-w` | Match whole words only |
| `-E` | Extended regex (so you don't need to backslash-escape `+`, `?`, `|`, `()`) |
| `-o` | Print only the matched part of the line, not the whole line |
| `-A N` / `-B N` / `-C N` | Show N lines of context After / Before / around a match |

Why `-qxF` together makes sense here: `-F` avoids regex surprises from filenames, `-x` avoids partial/substring matches, `-q` avoids printing anything since we only care about the exit code for the `if`.

---

## 5. `mapfile` (a.k.a. `readarray`) — Read Lines into an Array

Script usage:
```bash
mapfile -t staged < .bvcs/staging
mapfile -t headfiles < <(find ".bvcs/objects/$ID/files" -type f | sort)
```

| Flag | Meaning |
|---|---|
| `-t` | **Trim** the trailing newline from each line as it's stored in the array (without this, each array element would end with `\n`) |
| `-n COUNT` | Read at most COUNT lines |
| `-O N` | Start populating the array at index N instead of 0 |
| `-d DELIM` | Use DELIM instead of newline as the line separator |
| `-s N` | Skip the first N lines of input |

`mapfile -t arr < <(command)` is **process substitution** — it runs `command`, and treats its output as if it were a file being read. This lets you populate an array from a pipeline's output.

Alternative old-school way (without `mapfile`):
```bash
while IFS= read -r line; do arr+=("$line"); done < file
```

---

## 6. `find` — Locate Files

Script usage:
```bash
find ".bvcs/objects/$ID/files" -type f
find . -type f ! -path './.bvcs/*'
```

| Flag | Meaning |
|---|---|
| `-type f` | Match regular files only |
| `-type d` | Match directories only |
| `-type l` | Match symbolic links |
| `-name PATTERN` | Match by filename (glob pattern, case-sensitive) |
| `-iname PATTERN` | Same as `-name` but case-insensitive |
| `-path PATTERN` | Match against the whole path, not just filename |
| `! -path PATTERN` | **Negation** — exclude paths matching PATTERN. In the script, `! -path './.bvcs/*'` excludes the `.bvcs` bookkeeping directory itself from the "untracked files" scan. |
| `-maxdepth N` | Limit recursion depth |
| `-mindepth N` | Don't return results above depth N |
| `-mtime N` | Match by modification time (N days ago) |
| `-size N` | Match by file size |
| `-exec CMD {} \;` | Run CMD on each result |
| `-print0` | Null-separate output (pairs with `xargs -0`, safe for filenames with spaces) |

The `!` before `-path` is `find`'s own negation operator (different from shell `!`), so `! -path X` reads as "NOT matching path X."

---

## 7. Parameter Expansion for Stripping Paths (`#`, `##`, `%`, `%%`)

This is what you saw as `${file#./}` etc. — it's **not** a command, it's Bash's built-in string-trimming syntax.

| Syntax | Strips | Direction | Greedy? |
|---|---|---|---|
| `${var#pattern}` | Shortest match from the **front** | left | no |
| `${var##pattern}` | Longest match from the **front** | left | yes |
| `${var%pattern}` | Shortest match from the **end** | right | no |
| `${var%%pattern}` | Longest match from the **end** | right | yes |

Script examples:
```bash
norm="${file#./}"
```
Strips a leading `./` if present. `file="./a.txt"` → `norm="a.txt"`. `file="a.txt"` (no `./`) → unchanged, since the pattern doesn't match.

```bash
relpath="${fullpath#$prefix}"
```
`prefix` here is a variable holding `.bvcs/objects/$ID/files/`. This strips that whole prefix off the front of `fullpath`, effectively converting an absolute-ish internal path back into the relative path the user would recognize (e.g. `.bvcs/objects/0002/files/src/main.c` → `src/main.c`).

**Mnemonic:** `#` is on the same key as the number sign / pound — think "pound off the front, from the left where `#` starts." `%` trims from the back. Doubling the symbol (`##`, `%%`) means "be greedy — take as much as possible."

Other common uses not in this script:
```bash
file="archive.tar.gz"
echo "${file%.gz}"      # archive.tar   (strip shortest match from end)
echo "${file%%.*}"      # archive       (strip longest match from end, i.e. all extensions)
echo "${file#*.}"       # tar.gz        (strip shortest match from front, up to first dot)
echo "${file##*.}"      # gz            (strip longest match from front — common "get extension" trick)
```

---

## 8. `diff` — Compare Files

Script usage:
```bash
diff -q "$fullpath" "$relpath"
diff -u --label ".bvcs/objects/$head/files/$filename" --label "$filename" A B
```

| Flag | Meaning |
|---|---|
| `-q` | **Brief** — just report whether files differ ("Files X and Y differ"), no line-by-line detail. Used purely to test equality quietly. |
| `-u` | **Unified diff** format — the familiar `+`/`-` style with `@@` hunk headers, used by git and most patch tools |
| `-c` | Context diff format (older style, less common now) |
| `-y` | Side-by-side diff |
| `-r` | Recursive — diff entire directories |
| `-N` | Treat missing files as empty (useful with `-r` when a file exists in only one dir) |
| `-i` | Ignore case differences |
| `-w` | Ignore all whitespace |
| `-b` | Ignore changes in amount of whitespace |
| `--label NAME` | Override the filename shown in the diff header (used **twice**, once per file) — this is why the script's diff output shows clean labels like the tracked path and the working-copy path instead of the literal internal `.bvcs/objects/...` path |
| `--color` | Colorize output (GNU diff) |

Why `-q` first, then `-u` conditionally: the script does a quick `diff -q` first just to check "did anything change at all" (into `is_diff`), and only if something changed does it re-run with full `-u` output — avoids printing "no changes" noise for every unchanged file.

---

## 9. `cp` — Copy Files

Script usage:
```bash
cp -r .bvcs/objects/$prev/files/. .bvcs/objects/$filled/files/
cp "$file" "$dest"
cp ".bvcs/objects/$head/files/$filename" "$filename"
```

| Flag | Meaning |
|---|---|
| `-r` / `-R` | **Recursive** — required to copy directories (and their contents) rather than just single files |
| `-v` | Verbose — print each file as it's copied |
| `-i` | Interactive — prompt before overwriting |
| `-f` | Force — overwrite without prompting, even removing the destination first if needed |
| `-p` | Preserve mode, ownership, and timestamps |
| `-u` | Update — only copy if source is newer than destination or destination is missing |
| `-a` | Archive — shorthand for `-rdp` plus preserving links; the "copy everything exactly" flag |
| `-n` | No-clobber — never overwrite an existing file |

**The `.` trick:** `cp -r source/. dest/` copies the *contents* of `source/` into `dest/`, without creating a nested `source` folder inside `dest`. Compare:
- `cp -r source dest/` → creates `dest/source/...`
- `cp -r source/. dest/` → creates `dest/...` directly (this is what the script wants, so each commit's snapshot folder gets the previous commit's files copied flat into it before staged changes overwrite specific files)

---

## 10. `rm` — Remove Files (not used in this script, but worth covering since you asked)

Your script never actually calls `rm` — snapshots just accumulate under `.bvcs/objects/`. But since you asked, here's the full picture:

| Flag | Meaning |
|---|---|
| `-r` / `-R` | Recursive — remove directories and their contents |
| `-f` | Force — no prompts, no error if file doesn't exist |
| `-i` | Interactive — prompt before every removal |
| `-v` | Verbose |
| `-d` | Remove empty directories (without needing `-r`) |
| `--preserve-root` | Refuse to operate recursively on `/` (default behavior in modern versions) |

The infamous combo `rm -rf` means "recursively force-delete, no prompts, ignore missing files" — powerful and dangerous, always double-check the path before running it.

---

## 11. `wc` — Word/Line/Byte Count

Script usage:
```bash
count=$(wc -l < .bvcs/log)
```

| Flag | Meaning |
|---|---|
| `-l` | Count **lines** |
| `-w` | Count **words** |
| `-c` | Count **bytes** |
| `-m` | Count **characters** (differs from `-c` with multi-byte/unicode text) |
| `-L` | Length of the longest line |

Note the `< file` redirection instead of `wc -l file`: this feeds the file to `wc` via stdin so that `wc` prints **just the number**, not `number filename`. That's important here because the script needs a clean integer to do arithmetic (`ID=$((count + 1))`) — with `wc -l file` you'd get `"5 .bvcs/log"` which would need extra parsing.

---

## 12. `printf` — Formatted Output

Script usage:
```bash
filled=$(printf "%04d" $ID)
```

| Format spec | Meaning |
|---|---|
| `%d` | Integer |
| `%04d` | Integer, zero-padded to 4 digits (e.g. `7` → `0007`) |
| `%s` | String |
| `%-10s` | String, left-justified, padded to width 10 |
| `%f` | Floating point |
| `%x` / `%X` | Hex (lower/upper case) |
| `%%` | Literal percent sign |
| `\n` | Newline (printf does NOT auto-append one like `echo` does) |

`printf "%04d" $ID` turns commit number `7` into `"0007"`, giving predictable, sortable, fixed-width commit IDs (so `0009` sorts before `0010` alphabetically too, which plain `9` vs `10` would not).

---

## 13. `date` — Get/Format Date and Time

Script usage:
```bash
current_time=$(date +'%Y-%m-%d %H:%M:%S')
```

| Format spec | Meaning |
|---|---|
| `%Y` | 4-digit year |
| `%m` | Month (01-12) |
| `%d` | Day of month |
| `%H` | Hour (24h) |
| `%M` | Minute |
| `%S` | Second |
| `%s` | Unix epoch timestamp (seconds since 1970) |
| `%A` | Full weekday name |
| `%B` | Full month name |

Other useful `date` flags:
- `date -d "yesterday"` — parse a relative date string (GNU date)
- `date -u` — show UTC instead of local time
- `date -r file` — show a file's modification time

---

## 14. `cat` — Read/Concatenate Files

Script usage: `cat .bvcs/HEAD`, `cat .bvcs/staging`

| Flag | Meaning |
|---|---|
| `-n` | Number all output lines |
| `-A` | Show non-printing characters (tabs as `^I`, line ends as `$`) — great for debugging invisible whitespace bugs |
| `-s` | Squeeze multiple blank lines into one |
| `-b` | Number only non-blank lines |

Here, `cat` is used simply to read a one-line file's content into a variable: `ID=$(cat .bvcs/HEAD)`.

---

## 15. `dirname` — Strip Filename, Keep Directory Path

Script usage:
```bash
mkdir -p "$(dirname "$dest")"
```
`dirname "a/b/c.txt"` → `a/b`. Used to ensure the parent directory of a nested destination file exists before copying into it (since `cp` won't auto-create parent directories).

Its counterpart, **`basename`**, does the opposite:
```bash
basename "a/b/c.txt"        # → c.txt
basename "a/b/c.txt" .txt   # → c   (also strips a suffix)
```
Not used in this script, but frequently paired with `dirname`.

---

## 16. `read` — Read User Input / Parse Strings

Script usage:
```bash
read -r response
IFS='|' read -r commit_id timestamp message <<< "$entry"
```

| Flag | Meaning |
|---|---|
| `-r` | **Raw** — don't let backslashes act as escape characters (almost always want this on) |
| `-p PROMPT` | Show a prompt string before reading |
| `-s` | Silent — don't echo input (used for passwords) |
| `-n N` | Read only N characters |
| `-t N` | Timeout after N seconds |
| `-a ARRAY` | Read words into an array |
| `-d DELIM` | Use DELIM instead of newline to end input |

`IFS='|' read -r a b c <<< "$entry"` — this changes the **Internal Field Separator** to `|` just for this command, then splits `$entry` on `|` into three variables. `<<<` is a **here-string**, feeding the string directly as if it were stdin. This is how the script pulls apart log lines like `0004|2026-01-01 10:00:00|Fix bug` into `commit_id`, `timestamp`, `message`.

---

## 17. `sort` — Sort Lines

Script usage: `sort` (piped after `find`), and piped after loops printing filenames

| Flag | Meaning |
|---|---|
| (none) | Alphabetical sort |
| `-n` | Numeric sort (so `10` comes after `9`, not before) |
| `-r` | Reverse order |
| `-u` | Unique — remove duplicate lines |
| `-k N` | Sort by field/column N |
| `-t DELIM` | Set field delimiter for `-k` |
| `-f` | Case-insensitive |

Used to keep file listings in predictable alphabetical order for consistent `status`/`diff` output.

---

## 18. `sed` — Stream Editor

Script usage:
```bash
sed "s|^$prefix||"
```

| Part | Meaning |
|---|---|
| `s` | Substitute command |
| `\|pattern\|replacement\|` | The three parts, delimited by `\|` here instead of the usual `/` (chosen because `$prefix` contains `/` characters, which would otherwise need escaping) |
| `^$prefix` | Anchor the pattern to the **start** of the line, matching the prefix variable's value |
| (empty replacement) | Replace with nothing — i.e. delete the matched prefix |

Common `sed` flags:
| Flag | Meaning |
|---|---|
| `-i` | Edit file **in place** (careful — `-i` with GNU vs BSD sed behaves differently regarding backup suffix) |
| `-e` | Add an explicit script expression (lets you chain multiple `-e 's/../../'` ) |
| `-n` | Suppress automatic printing (used with `p` flag to print only matched lines) |
| `g` (suffix) | Global — replace **all** matches per line, not just the first |

So `sed "s|^$prefix||"` strips the `.bvcs/objects/ID/files/` prefix off every line of `find`'s output — functionally similar to the `${var#pattern}` trick from section 7, but applied to a whole stream of lines at once instead of one variable.

---

## 19. `declare -A` — Associative Arrays

Script usage:
```bash
declare -A files
files["$file"]="staged"
```

| Flag | Meaning |
|---|---|
| `-A` | Associative array (string keys, like a dictionary/hash map) |
| `-a` | Indexed array (numeric keys, the "normal" bash array) |
| `-i` | Integer variable |
| `-r` | Read-only |
| `-x` | Export to environment |
| `-l` / `-u` | Force lowercase / uppercase on assignment |

Iterating:
```bash
for key in "${!files[@]}"; do   # ! gives keys, not values
    echo "$key -> ${files[$key]}"
done
```

---

## 20. Command Substitution & Process Substitution (used throughout)

| Syntax | Meaning |
|---|---|
| `$(command)` | **Command substitution** — run command, capture its stdout as a string |
| `<(command)` | **Process substitution** — run command, treat its output as a readable "file" (used as `mapfile -t arr < <(find ...)`) |
| `<<< "string"` | **Here-string** — feed a literal string to a command's stdin |

---

## Quick-Reference Cheat Sheet

```
[ -f file ]     regular file exists
[ -d file ]     directory exists
[ -s file ]     file exists AND is non-empty
[ -z "$s" ]     string is empty
[ -n "$s" ]     string is non-empty
[ a == b ]      string equal
[ a -eq b ]     number equal

mkdir -p dir            create dir + parents, no error if exists
touch file               create empty file / bump timestamp
grep -qxF "x" file        silently check for an exact literal line match
mapfile -t arr < file     read lines into array, no trailing \n
find . -type f ! -path 'X'  list files, excluding a path pattern
${var#pattern}            strip shortest match from front
${var##pattern}           strip longest match from front
${var%pattern}            strip shortest match from back
${var%%pattern}           strip longest match from back
diff -q a b               silently report if files differ
diff -u --label X --label Y a b   unified diff with custom filenames
cp -r src/. dst/           copy contents of src into dst (no nesting)
wc -l < file               line count as bare number
printf "%04d" 7             zero-pad number → 0007
date +'%Y-%m-%d %H:%M:%S'    formatted timestamp
dirname path                strip filename, keep directory
read -r var                 read input, no backslash escaping
IFS='|' read -r a b <<< "$s"  split a string on a custom delimiter
sort                        alphabetical line sort
sed "s|pat||"                delete matched pattern from each line
declare -A arr               associative array (dictionary)
```
