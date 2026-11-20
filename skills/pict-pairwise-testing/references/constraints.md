# PICT constraints

Contents: what constraints are for, syntax, types, operators, patterns for
common rules, errors and their fixes, warnings that do not stop PICT (skipped
constraints, unreachable values).

## What a constraint is for

A constraint tells PICT that a combination **cannot occur**, so it should not
appear in any test case. PICT then finds other rows to cover the pairs that
the excluded combination would have covered. This is why you cannot simply
generate without constraints and delete the impossible rows afterwards: each
deleted row takes valid pairs with it.

Before writing a constraint, ask which of these it is:

| Situation | Example | Constraint? |
|---|---|---|
| The combination cannot be entered or cannot exist | Pickup is not offered outside the home country | Yes |
| The system should reject the combination | Invoice payment under the minimum order value returns an error | **No**. That is a test worth running. Keep it, or model the offending value as negative with `~`. |
| The combination is merely unlikely or uninteresting | Few customers use option X with Y | No. Pairwise is already small; leave it in. |

Each constraint should trace back to a rule in the source. If you cannot say
which rule it encodes, it is an assumption: list it as one.

## Syntax

```
IF <predicate> THEN <predicate>;
IF <predicate> THEN <predicate> ELSE <predicate>;
<predicate>;
```

- Constraints come after all parameter definitions (and after sub-models).
- Each one ends with a semicolon. A missing semicolon is reported as
  `Constraint terminated incorectly` (PICT's spelling).
- Parameter names are written in square brackets, exactly as defined,
  including spaces: `[Cart total]`.
- Keywords and comparisons are case-insensitive by default. `-c` makes the
  whole model case-sensitive.
- A constraint may span several lines.

The third form, without `IF`, is an invariant that must hold in every row:

```
[Source disk] <> [Target disk];
```

## Types

A parameter is numeric only when all of its values are numbers. Otherwise it
is a string parameter, including any numbers among its values.

```
Size:  10, 100, 1000        # numeric
Level: 1, 2, max            # string, because of "max"
```

- Numeric parameters are compared with bare numbers: `[Size] > 100`.
- String parameters are compared with quoted strings: `[Level] = "2"`.
- Mixing them gives `Parameter/value type mismatch`.
- `<`, `>` on string parameters compare alphabetically, so `"10" < "9"`. If
  you need numeric ordering, make every value of that parameter a number and
  express special cases as a separate parameter.
- The `~` prefix of a negative value and the names after the first alias do
  not affect the type, and neither appears in constraints: for `A: ~-1, 0, 1`
  write `[A] = -1`.

## Operators

| Kind | Operators | Example |
|---|---|---|
| Comparison | `=` `<>` `>` `>=` `<` `<=` | `[Size] >= 100` |
| Set | `IN { ... }` | `[FS] IN {"FAT", "FAT32"}` |
| Wildcard | `LIKE` with `*` (any run of characters) and `?` (one character) | `[FS] LIKE "FAT*"` |
| Logic | `NOT`, `AND`, `OR`, parentheses | `NOT ([A] = 1 OR [B] = 2)` |
| Parameter to parameter | any comparison, same type on both sides | `[Min] <= [Max]` |

Use parentheses whenever `AND` and `OR` are mixed, so the intent is explicit.

## Patterns for common rules

**"X is only available with Y"**: X implies Y.

```
IF [Shipping] = "Pickup" THEN [Destination] = "Domestic";
```

**"X requires one of several"**

```
IF [Payment] = "Invoice" THEN [Customer] IN {"Business", "Government"};
```

**"X and Y cannot go together"**: state it from one side only.

```
IF [Browser] = "Safari" THEN [OS] <> "Windows";
```

**Writing both directions.** `IF A THEN B` does not imply `IF B THEN A`. Add
the second rule only when the requirement really is two-way, because every
extra constraint shrinks the valid space and can make values unreachable.

**"Field is not applicable unless..."**: give the dependent parameter an
explicit `N/A` value and tie it both ways with `ELSE`.

```
Discount type:  None, Percent, Fixed
Discount value: N/A, 5, 50

IF [Discount type] = "None"
  THEN [Discount value] = "N/A"
  ELSE [Discount value] <> "N/A";
```

`Discount value` is a string parameter here because of `N/A`, so its values
are quoted in constraints.

**Numeric dependency between parameters**

```
[Start page] <= [End page];
```

**Thresholds**

```
IF [File system] = "FAT" THEN [Size] <= 4096;
```

## Errors and fixes

PICT writes errors to standard error and exits with a non-zero code. Exit
code 5 means the constraints are at fault, 4 the model or file, 3 an option.

| Message | Cause | Fix |
|---|---|---|
| `Parameter/value type mismatch: <constraint>` | Number compared with a string parameter or the reverse | Quote the value or remove the quotes, according to the parameter's type |
| `Constraint terminated incorectly: <constraint>` | Missing `;` | Add it |
| `Too restrictive constraints. All values of parameter 'X' got excluded.` | The rules contradict each other outright | See below |
| `Order cannot be larger than number of parameters` | `-o` too high, or a sub-model order above its size | Lower the order |
| `Couldn't open file` | Wrong path | Check the model path |
| `Unknown option` | Option not supported by this binary | Check `flags` from `find-pict` |

The constraint text in a message tells you which line to look at. Fix the
specific line; do not rewrite the model wholesale.

## Warnings that do not stop PICT

Two problems leave the exit code at 0 and a normal-looking table on standard
output. Only standard error reveals them, which is why it must be read on
every run.

### Skipped constraints

```
Constraints Warning: Constraint IF [Shiping] = "Pickup" THEN [Destination] = "Domestic"; contains unknown parameter. Skipping...
```

A parameter name in the constraint matches no defined parameter, usually a
typo or a renamed parameter. PICT **drops the whole constraint and carries
on**, so the table is generated as if that rule did not exist and will
contain combinations the rule was meant to exclude. Correct the name (copy
it from the parameter line) and rerun.

### Unreachable values

When the constraints leave some value with no valid combination, PICT still
succeeds and prints:

```
Constraints Warning: Restrictive constraints. Output will not contain following values:
  Destination: International
```

Example of how it happens:

```
IF [Shipping] = "Express"          THEN [Destination] = "Domestic";
IF [Destination] = "International" THEN [Shipping] = "Express";
```

International needs Express, Express needs Domestic, so International can
never appear. Each rule looks fine alone.

What to do:

1. Find the constraints that mention the missing value or the values it
   depends on.
2. Check each against the source. Typical modeling slips: a rule written in
   the wrong direction, a rule written both ways when it is one-way, `AND`
   where `OR` was meant, an `ELSE` branch that says more than intended.
3. If you mis-encoded a rule, correct it and rerun.
4. If the constraints match the source faithfully, the requirements
   themselves conflict. Report it: name the rules and the value that becomes
   impossible. Leave the constraints as they are and let the user decide. This
   is a real finding and often the most useful thing the exercise produces.

The same applies to `Too restrictive constraints`: it is the extreme form,
where a whole parameter has no value left.
