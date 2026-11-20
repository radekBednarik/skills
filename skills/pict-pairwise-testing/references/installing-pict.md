# Getting PICT when it is missing

Read this when `find-pict` reports `status=missing`.

## Ground rules

- **Ask first.** Installing a package, downloading an executable or compiling
  source code changes the user's machine and runs third-party code. That is
  their call. Present the options below, recommend one, and wait for an
  explicit yes before running any command in this file.
- **No elevated rights.** Nothing here needs `sudo` or an administrator
  prompt. If a step asks for one, stop and tell the user.
- **Nothing goes into the skill directory.** A downloaded or built binary
  lives in the user-level cache directory that `find-pict` already searches:
  `${XDG_CACHE_HOME:-$HOME/.cache}/pict-skill/` on Linux and macOS,
  `%LOCALAPPDATA%\pict-skill\` on Windows.
- **Pinned and verified.** The download and the source build below are tied
  to release v3.7.4 and include a check. If a check fails, delete what was
  fetched and stop; do not "try anyway".
- **Run the commands one at a time** so the user sees each step, and report
  what happened.

## What to offer

Pick the options that apply to the user's system (`os=` in the `find-pict`
output) and present them in this order.

| Option | Applies to | Effort | Result |
|---|---|---|---|
| A. Homebrew | macOS, Linux with `brew` | one command, prebuilt | `pict` on PATH, v3.7.4 |
| B. Official download | Windows | one small file | `pict.exe` in the cache dir, v3.7.4 |
| C. Build from source | Linux, macOS, anything with git + CMake + a C++17 compiler | about a minute | `pict` in the cache dir, v3.7.4 |
| D. User installs it | everywhere | none for you | they point `PICT_BIN` at it |
| E. Skip | everywhere | none | model file only, no test cases |

If the user picks E, or an install fails and they do not want another
attempt, return to the skill and use its "No PICT" ending.

## A. Homebrew

```
brew install pict
```

Then rerun `find-pict`.

## B. Official Windows download

Microsoft publishes `pict.exe` on the GitHub release page. It is a 32-bit
console program and also runs on 64-bit Windows.

```powershell
$dir = Join-Path $env:LOCALAPPDATA 'pict-skill'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
Invoke-WebRequest -Uri 'https://github.com/microsoft/pict/releases/download/v3.7.4/pict.exe' -OutFile (Join-Path $dir 'pict.exe')
(Get-FileHash (Join-Path $dir 'pict.exe') -Algorithm SHA256).Hash
```

The last command must print (letter case does not matter):

```
80ABA862739CF18B4FAA13D408163324D188A1C4EFCCDD977D9C5BA3F8950BBD
```

If it prints anything else, delete the file, tell the user the download did
not match the expected release file, and stop. Otherwise rerun `find-pict`.

## C. Build from source

Needs `git`, `cmake` 3.13 or newer, and a C++17 compiler (`g++` or
`clang++`). Check they exist before starting; if one is missing, say which
and let the user decide how to get it. Do not install toolchains on your own.

```sh
src=$(mktemp -d)
git clone --depth 1 --branch v3.7.4 https://github.com/microsoft/pict.git "$src"
git -C "$src" rev-parse HEAD
```

The last command must print exactly:

```
d529bb1535b725c8f29704f183b23dd344895d02
```

That is the commit of the v3.7.4 release. A different value means the tag no
longer points at the reviewed release: remove `$src`, report it, and stop.
Otherwise continue:

```sh
cmake -DCMAKE_BUILD_TYPE=Release -S "$src" -B "$src/build"
cmake --build "$src/build" --target pict_cli
mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/pict-skill"
cp "$src/build/cli/pict" "${XDG_CACHE_HOME:-$HOME/.cache}/pict-skill/pict"
rm -rf "$src"
```

Then rerun `find-pict`; it should report `source=cache`.

If the build fails, show the user the compiler or CMake error. Do not patch
the PICT sources to get past it.

## D. The user installs it

Tell them what is needed: any PICT 3.7.4 or newer executable. Once they have
it, either it is on PATH, or they give you the location and you run
`find-pict` with `PICT_BIN` set to it.

## Why v3.7.4

It is the latest tagged release and what Homebrew and the official download
provide, so every route gives the same behavior and the same output for the
same model. The repository's main branch has newer, unreleased features. A
user who built that themselves can use it: `find-pict` reports the extra
options in `flags`.

## Removing it later

Tell the user how to undo the install if they ask: `brew uninstall pict`, or
delete the `pict-skill` cache directory.
