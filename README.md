# skills

Agent skills for free use. Each skill lives in its own folder under
[`skills/`](skills/) and follows the `SKILL.md` format used by Claude Code and
other agents that support agent skills.

## Available skills

| Skill | What it does |
|---|---|
| [`pict-pairwise-testing`](skills/pict-pairwise-testing/SKILL.md) | Designs pairwise (all-pairs) and n-way combinatorial test cases with [Microsoft PICT](https://github.com/microsoft/pict). It turns a requirement, spec, API, form or configuration matrix into a PICT model, runs the real PICT engine, checks the result and returns a compact test case table. |

## Install

With the [`skills`](https://www.npmjs.com/package/skills) CLI:

```sh
# list skills in this repository
npx skills add radekBednarik/skills --list

# install one skill
npx skills add radekBednarik/skills --skill pict-pairwise-testing
```

Or copy the skill folder by hand into your agent's skills directory, for
example `~/.claude/skills/pict-pairwise-testing/` for Claude Code.

## pict-pairwise-testing

### Requirements

The skill needs the PICT executable (version 3.7.4 or newer). It looks for it
in this order:

1. the `PICT_BIN` environment variable
2. `pict` / `pict.exe` on `PATH`
3. a user cache directory: `~/.cache/pict-skill/` (Linux, macOS) or
   `%LOCALAPPDATA%\pict-skill\` (Windows)

If PICT is missing, the agent offers ways to get it and **does not install,
download or build anything without your explicit consent**. The options are:

| Platform | Option |
|---|---|
| macOS, Linux with Homebrew | `brew install pict` |
| Windows | official `pict.exe` from the v3.7.4 release, SHA256-verified, saved to the cache directory |
| Anything with git, CMake 3.13+ and a C++17 compiler | build the pinned v3.7.4 tag from source into the cache directory |

No option needs `sudo` or administrator rights. If you decline, you still get
the PICT model file and the command to run later, but no test cases: the
skill never writes combination tables by hand.

### Example prompts

- "Generate pairwise test cases for Browser: Chrome, Firefox, Safari; OS: Windows, macOS, Linux; Locale: en, de, ja; Theme: light, dark."
- "Here's the user story for our export feature. We can't test every combination; work out a sensible set of test cases."
- "We have 9 feature flags and bugs keep showing up in flag combinations. Which combinations should we test?"
- "I need negative test combinations for the money transfer form."

### What you get

- a `.pict` model file and the `.tsv` output that PICT wrote from it, unchanged
- a table with `ID` and `Type` (positive or negative) columns
- the generated row count compared with the exhaustive count, plus the exact
  command used
- the assumptions made while modeling, and any warnings or values that the
  constraints made unreachable

## Repository layout

```
skills/<name>/     the skill itself (this is what gets installed)
evals/<name>/      eval prompts, assertions and grading helpers (not installed)
tests/             tests for the bundled scripts (not installed)
```

Run the script tests with:

```sh
pnpm test          # or: sh tests/find-pict.test.sh
```

## License

[MIT](LICENSE). PICT itself is a separate project by Microsoft, also under the
MIT License; this repository does not contain or redistribute it. See
[`NOTICE.md`](skills/pict-pairwise-testing/NOTICE.md).
