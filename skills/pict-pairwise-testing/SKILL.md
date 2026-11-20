---
name: pict-pairwise-testing
description: Design pairwise (all-pairs) and n-way combinatorial test cases with Microsoft PICT. Turns a requirement, spec, API, form, feature-flag set or configuration matrix into a PICT model with parameters, values, constraints and negative values, runs the real PICT engine, and returns a compact, checked test case table. Use whenever the user mentions pairwise, all-pairs, combinatorial testing, PICT, orthogonal arrays or a test matrix, and also when they never name the technique but describe the problem - too many combinations to test them all, which combinations of browsers / OSes / devices / locales / settings / flags / options to cover, or shrinking an oversized test matrix. Not for unit tests of one function, test automation code, state-transition or sequence testing, or performance testing.
---

# Pairwise test design with PICT

PICT is Microsoft's combinatorial test generator. Give it a model (parameters,
their values, and rules about which values cannot go together) and it returns a
small set of test cases in which every pair of values appears at least once.
Most defects are triggered by one value or by the interaction of two, so this
finds most of what exhaustive testing would at a fraction of the size.

Your job splits in two, and the split matters:

- **The model is your work.** Choosing parameters, picking representative
  values, and encoding the real business rules as constraints is where the
  thinking happens and where the quality of the tests is decided.
- **The combinations are PICT's work.** Covering every pair under constraints
  with few rows is a hard search problem. People and language models are bad at
  it: hand-built tables miss pairs and break constraints while looking
  perfectly reasonable. So every test case table you deliver comes from an
  actual PICT run. If PICT cannot be run, you deliver the model and say so. You
  do not write the rows yourself, not even for a small model.

That single rule is what makes the output trustworthy, and it is why the user
is using this skill instead of asking for "some test combinations".

## Workflow

1. Check the technique fits
2. Locate PICT
3. Build the model
4. Run PICT
5. Check the result
6. Present the test cases

### 1. Check the technique fits

Pairwise pays off when there are **three or more parameters that can be
combined freely** and their interactions could matter. Say so and step aside
when it does not fit, instead of forcing a model:

- Two parameters: all pairs is simply every combination. Just list them, PICT
  adds nothing.
- One function with a few inputs, sequences of steps, state machines, timing,
  load: other techniques fit (boundary values, state-transition testing, and
  so on). Mention which one and offer to continue without this skill.

The scope here is **test design**: a table of input combinations. Turning rows
into executable test code is a separate task; do it only if asked, after the
table exists.

### 2. Locate PICT

Run the bundled detection script. It is read-only and offline.

```
sh <skill-dir>/scripts/find-pict.sh                                             # Linux, macOS, WSL, Git Bash
powershell -NoProfile -ExecutionPolicy Bypass -File <skill-dir>\scripts\find-pict.ps1   # Windows
```

If the user told you where the binary is, pass it in: `PICT_BIN=/path/to/pict sh .../find-pict.sh`.

It prints `key=value` lines:

```
status=found
path=/usr/local/bin/pict
source=PATH
flags=o d a n e r c s
```

- `path` is the executable to run. Use that exact path from here on.
- `flags` lists the option letters this binary supports. The released version
  (3.7.4, which is what Homebrew and the official Windows download provide)
  supports exactly `o d a n e r c s`. Newer source builds add others, such as
  `b` (best of N seeds) and `t` (threads). **Only use an option whose letter is
  in `flags`**; an unknown option makes PICT exit with an error. If the user
  asks for something the binary lacks, tell them and offer what does work.

If you cannot run the script, do the same checks by hand: the `PICT_BIN`
environment variable, then `pict` on PATH, then the cache directory
(`~/.cache/pict-skill/` or `%LOCALAPPDATA%\pict-skill\`). Run the candidate
with no arguments and confirm it prints "Pairwise Independent Combinatorial
Testing" followed by its option list.

**When `status=missing`:** read `references/installing-pict.md` and follow it.
The short version: never install, download or build anything without the
user's explicit go-ahead, because fetching and compiling software is their
decision, not a side effect of asking for test cases. Offer the choices, let
them pick. If they decline, or installing fails, keep going with step 3 and
then use the "No PICT" ending in step 6.

### 3. Build the model

A model is a plain text file. Parameters first, then optional sub-models, then
constraints, in that order.

```
# Checkout - shipping and payment
Destination: Domestic, EU, International
Shipping:    Standard, Express, Pickup
Payment:     Card, PayPal, Invoice
Coupon:      None, Percent, FreeShipping, ~Expired
Cart total:  1, 49, 50, 500

IF [Shipping] = "Pickup"  THEN [Destination] = "Domestic";
IF [Payment]  = "Invoice" THEN [Cart total] >= 50;
```

Essentials:

- `Name: value, value, ...` one parameter per line. `#` starts a comment.
- A value cannot contain the separator. Quoting does not help: `"a, b"` is
  read as two values. Reword the value or change the separator with `-d`.
- A parameter is **numeric only if every one of its values is a number**;
  otherwise all of its values are strings. Numeric parameters compare against
  bare numbers (`[Cart total] >= 50`), string parameters against quoted strings
  (`[Payment] = "Invoice"`). Mixing the two is the most common model error.
- `~` marks an invalid value for negative testing. PICT puts at most one
  invalid value in a row, so one bad input never hides another. In constraints
  write the value without the `~`.
- Every constraint ends with `;`. Parameter names go in `[brackets]`.
  Comparisons ignore case unless you pass `-c`.
- Constraints remove combinations that **cannot happen**. They are not for
  combinations that should be rejected by the system: a rejected combination
  is a test you want to keep.

**Given parameters or deriving them?**

- If the user handed you the parameters and values, use them as given and go
  straight to step 4. Do not re-interview them about a model they already
  wrote.
- If you derive the model from a requirement, spec, code, API or screen, read
  `references/modeling-guide.md` first. It covers how to find parameters, pick
  values with equivalence classes and boundaries, and separate real constraints
  from assumptions. Then **show the model before generating**: a short list of
  parameters with their values, the constraints with the rule each one encodes,
  and anything you assumed that the source did not state. Ask the user to
  confirm or correct. A wrong model produces a clean-looking table with a hole
  in it and PICT cannot notice, so this is the cheapest place to catch it. If
  you cannot ask (non-interactive run), proceed and list the assumptions
  prominently in the result.

Read `references/constraints.md` when a constraint is more than a simple
`IF ... THEN ...`, or when PICT reports a constraint error. Read
`references/advanced.md` when you need higher coverage for a subset of
parameters (sub-models), must keep existing test cases stable (seeding), want
to exclude irrelevant parameters from negative tests, or need aliases, weights
or parameter reuse.

### 4. Run PICT

Save the model as `<name>.pict` and write PICT's output next to it as
`<name>.tsv`. Put them where the user asked, or where the project already
keeps test design documents. If nothing indicates a place, ask before writing
instead of scattering files in the repository root.

```
"<path-from-step-2>" checkout.pict > checkout.tsv
```

- Standard output is the table: a header row, then one test case per line,
  tab-separated. Leave this file exactly as PICT wrote it; it is the evidence
  that the cases came from the engine.
- Standard error carries warnings and errors. Let it reach you and read it.
- Write options with a dash: `-o:3`, `-d:";"`. PICT's own documentation shows
  `/o:3`, which is the same thing, but shells on Windows (Git Bash) rewrite
  arguments starting with `/` into file paths.
- Do not pass `-r` unless asked. Without it the same model always yields the
  same table, which keeps reviews and diffs meaningful. With `-r`, PICT prints
  the seed it used on standard error; record it so the run can be repeated
  with `-r:<seed>`.

**Order.** The default is pairs (`-o:2`). Raise it to `-o:3` only for a stated
reason, such as a known three-way interaction or a safety-critical area, and
tell the user what it costs in rows. To strengthen just a few parameters, use
a sub-model instead of raising the order for everything.

### 5. Check the result

PICT guarantees coverage of the model it was given. It cannot tell whether the
model says what was meant, and one important failure does not even produce an
error. Go through this every run:

1. **Exit code.** Non-zero means no usable table: 3 bad option, 4 bad model or
   unreadable file, 5 bad constraints. Fix the cause and rerun.
2. **Standard error.** Read every line. Two warnings leave the exit code at 0
   and still mean the table is wrong:
   - `Constraints Warning: Restrictive constraints. Output will not contain following values:`
     One or more values appear in no row, so everything involving them is
     silently untested.
   - `Constraints Warning: Constraint ... contains unknown parameter. Skipping...`
     A parameter name in that constraint is misspelled. PICT dropped the whole
     rule and generated the table without it. Fix the name and rerun.
3. **Every declared value appears in at least one row** of the `.tsv`. If one
   is missing, the constraints made it unreachable. Either a constraint is
   wrong (fix it), or the rules truly contradict each other (tell the user
   which rules collide and which value is lost). Do not present the table as
   complete while a value is missing.
4. **Size.** Count the rows and compare with the exhaustive count, which is
   the product of the number of values of each parameter. (`-s` prints
   statistics instead of test cases; its "Combinations" figure is the number
   of pairs to cover, not the exhaustive count.)
5. **Negative rows.** Each row has at most one value starting with `~`.

Two rules for repairs:

- **Fix your own mistakes, at most three reruns.** Syntax slips, type
  mismatches and typos are yours to fix. If the third attempt still fails,
  stop and show the user the model and PICT's message instead of looping.
- **Do not quietly change a rule to make an error go away.** A constraint
  stands for a business rule. If the rules conflict, that conflict is a finding
  about the requirements, often a valuable one. Report it and let the user
  decide; do not delete or loosen the constraint on your own.

### 6. Present the test cases

Show the table in the conversation, built from the `.tsv` with two columns
added in front:

```
| ID | Type     | Destination | Shipping | Payment | Coupon   | Cart total |
|----|----------|-------------|----------|---------|----------|------------|
| 1  | positive | Domestic    | Pickup   | Card    | None     | 49         |
| 2  | negative | EU          | Standard | PayPal  | ~Expired | 500        |
```

- `ID` numbers the rows in PICT's order.
- `Type` is `negative` when the row contains a `~` value, otherwise `positive`.

Follow it with:

- A one-line summary: `5 parameters, pairwise (order 2): 21 test cases instead of 432 exhaustive.`
- The paths of the `.pict` and `.tsv` files and the exact command used.
- Assumptions made while modeling, and any warning or unreachable value from
  step 5.

**Expected results.** PICT produces inputs, not outcomes. Add an `Expected`
column only where the source material states the outcome, and say where it
comes from ("per requirement 4.2"). Where the source is silent, write
`not specified` and do not invent a plausible outcome: a guessed expected
result looks authoritative in a table and turns into a wrong test. For
negative rows the expected outcome is normally rejection of the invalid
value; state the specific error only if the source defines it. Keep
`Expected` out of the `.tsv` so engine output and your reasoning stay
separable.

**Other formats** (CSV, JSON, Gherkin, a test management import): convert from
the `.tsv` when asked. Do not produce them unprompted.

**No PICT.** When PICT is unavailable and the user chose not to install it,
deliver:

- the `.pict` model file, with the note that it has not been validated because
  PICT has not parsed it,
- the exact command to run once PICT is available,
- the parameter and constraint summary, and the exhaustive count,
- a plain statement that no test cases were generated and why.

Do not include a hand-made table "as a preview" or "for illustration". A
partial table without the coverage guarantee is worse than none, because it
will be used.

## Reference files

| Read | When |
|---|---|
| `references/modeling-guide.md` | Deriving a model from a requirement, spec, API, UI or code |
| `references/constraints.md` | Non-trivial constraints, or any constraint error from PICT |
| `references/advanced.md` | Sub-models, seeding, excluding parameters in negative tests, aliases, weights, reuse, separators |
| `references/installing-pict.md` | `find-pict` reports `status=missing` |
