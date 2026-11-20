# Advanced PICT modeling

Reach for these when the basic model cannot express what is needed. All of
them work in PICT 3.7.4.

Contents: sub-models, seeding, excluding parameters in negative tests,
aliases, weights, reusing parameter definitions, separators and prefixes,
randomization, option summary.

## Sub-models: different coverage for a group of parameters

Use when a few parameters interact strongly and deserve three-way coverage
while the rest stay pairwise, or when a group should be combined as a unit
(for example hardware parameters, so that fewer distinct machines are needed).

Sub-models go between the parameter definitions and the constraints:

```
PLATFORM: x86, x64, arm
CPUS:     1, 2, 4
RAM:      1GB, 4GB
OS:       Win10, Win11
APP:      Word, Excel

{ PLATFORM, CPUS, RAM } @ 3
```

- `@ N` is the order inside the group. Without it, the group uses the order
  given by `-o`.
- The order cannot exceed the number of parameters in the group.
- A parameter may belong to several sub-models. Groups cannot be nested.
- The groups are then combined with each other and with the remaining
  parameters at the `-o` order.

**Cost.** Sub-models can enlarge the suite a lot, because every combination
produced inside the group is then paired with the other parameters. The
model above gives 10 rows without the sub-model and 36 with it. Report the
row count before and after, so the user can judge whether the extra coverage
is worth it.

Prefer a sub-model over raising `-o` for the whole model when only some
parameters need the stronger coverage.

## Seeding: fixed or carried-over test cases

Use when certain combinations must be in the suite (a customer's
configuration, a past defect), or when a model changes and the existing test
cases should stay as stable as possible.

A seed file has the same format as PICT output: a header row with parameter
names, then one row per test case, all tab-separated.

```
OS	SKU	Lang
Win11	Pro	de
Win10		en
```

```
pict model.pict -e:seed.tsv > model.tsv
```

- A row may leave a cell empty; PICT chooses that value.
- PICT starts the suite with the seed rows and adds whatever is needed to
  complete the coverage.
- To keep a suite stable after editing the model, pass the previous `.tsv`
  as the seed file.
- Columns for parameters no longer in the model are ignored, and values no
  longer in the model are dropped from their row, each with a warning.
- **A seed row that violates a constraint is skipped entirely.** If a
  must-have case is missing from the output, check it against the
  constraints.
- Seeding needs unambiguous names: no blank names, no tab characters in
  names, no duplicate values within a parameter.

## Excluding parameters in negative tests

When one invalid value stops processing, the other parameters in that row do
not matter, yet PICT still pairs the invalid value with every value of every
other parameter. To spend only one row on it, give the other parameters a
placeholder value and tie it to the invalid one:

```
P1: -1, 0, 1
P2: A, B, C, NA
P3: X, Y, Z, NA

IF [P1] = -1
  THEN [P2] =  "NA" AND [P3] =  "NA"
  ELSE [P2] <> "NA" AND [P3] <> "NA";
```

The result has a single row for `-1` with `NA` in the other columns, and no
`NA` anywhere else.

- Here the invalid value is written without `~`, since the constraint
  already isolates it.
- This becomes hard to follow once several parameters have such values,
  because the `ELSE` branches interact. Use it for one or two cases; beyond
  that, the standard `~` marking is easier to keep correct, at the price of
  a few more rows.

## Aliases: several names for one value

```
SKU: Professional, Server | Datacenter
```

`Server` and `Datacenter` are treated as a single value for coverage, and
PICT alternates the names across the rows where it appears. Use it when
several items are equivalent for the logic under test but you still want each
exercised at least once, without enlarging the suite.

- In constraints only the first name exists: `[SKU] = "Server"` matches,
  `[SKU] = "Datacenter"` does not.
- Only the first name decides the type (numeric or string) and whether the
  value is negative.
- When checking that every value appears in the output, an alias group counts
  as one value. With few rows, not every name is guaranteed to show up.
- The alias separator `|` can be changed with `-a`.

## Weights: preferring some values

```
File system: FAT, FAT32, NTFS (10)
```

A weight is a hint used only when PICT has a free choice between values that
would cover equally much. Coverage always comes first, so a weight of 10
does not mean ten times as many rows, and it may have no visible effect.
Use it to nudge the suite toward the common configuration. Do not promise the
user a particular distribution.

## Reusing parameter definitions

```
OS_1: Win10, Win11
OS_2: <OS_1>, Linux
```

`<Name>` copies the values of a parameter defined earlier. Handy for models
with two of the same thing (source and target, client and server). Combine
with parameter-to-parameter constraints such as `[OS_1] <> [OS_2];`.

## Separators and prefixes

| Option | Changes | Default | When |
|---|---|---|---|
| `-d:C` | value separator | `,` | A value itself contains a comma |
| `-a:C` | alias separator | `\|` | A value contains `\|` |
| `-n:C` | negative prefix | `~` | A valid value starts with `~` |

Quote the option in the shell when the character is special there:
`pict model.pict "-d:;"`. The model file must then use the new character:

```
Amount: 1,5; 10; 100
```

## Randomization

Without options PICT is deterministic. `-r` picks a random seed and prints
`Used seed: N` on standard error; `-r:N` repeats that exact run. Different
seeds give suites of slightly different size. Use it only on request, and
always record the seed next to the result.

Some newer builds offer `-b:N`, which tries N seeds and keeps the smallest
suite. Use it only if `b` is listed in `flags` from `find-pict`.

## Option summary (3.7.4)

| Option | Meaning |
|---|---|
| `-o:N` or `-o:max` | Order of combinations, default 2. `max` is exhaustive. `-o:1` covers each value once. |
| `-d:C` | Value separator |
| `-a:C` | Alias separator |
| `-n:C` | Negative value prefix |
| `-e:file` | Seed file |
| `-r` or `-r:N` | Randomize, optionally with a given seed |
| `-c` | Case-sensitive model |
| `-s` | Print statistics instead of test cases |

PICT's documentation writes these with a slash (`/o:2`). Both forms work;
the dash avoids path rewriting in some Windows shells.
