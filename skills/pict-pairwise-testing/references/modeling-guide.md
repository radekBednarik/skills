# Deriving a PICT model from source material

Read this when the user gives you a requirement, user story, spec, API
definition, screen or piece of code instead of a ready parameter list.

Contents: what a good model looks like, finding parameters, choosing values,
negative values, constraints versus assumptions, keeping the model small,
where to look in each kind of source, the review checkpoint, a worked example.

## What a good model looks like

PICT covers every pair of values **in the model**. Whatever is left out of the
model is not tested, and PICT has no way to notice. So a model is good when:

- every factor that can change the behavior under test is a parameter,
- each parameter's values stand for the meaningfully different cases, not all
  possible inputs,
- every constraint corresponds to a real rule,
- it is small enough that a person can read and challenge it.

## Finding parameters

A parameter is something that **varies independently** and **may change what
the system does**. Look for:

- Inputs the user or caller supplies: fields, options, arguments, headers.
- Configuration and environment: platform, browser, locale, role, plan tier,
  feature flags, connectivity.
- State the behavior depends on: logged in or not, empty or full cart, first
  use or returning.

Tests of quality:

- **One decision per parameter.** "Payment and currency" is two parameters.
- **Not a parameter:** something fixed for every test (make it a precondition),
  an output or expected result, or a step in a sequence.
- **Dependent parameters** are still parameters. "Card type" matters only when
  payment is "Card"; model it with an `N/A` value and a constraint (see
  `constraints.md`), not by dropping it.
- **Names** should be the source's own terms, so the table reads naturally to
  the people who wrote the requirement.

## Choosing values

For each parameter, pick values so that each one represents a class of inputs
the system should treat the same way (equivalence partitioning), and add the
edges where the treatment changes (boundary values).

| Kind of parameter | Values to use |
|---|---|
| Fixed set of options | Every option, if there are few. If there are many (countries, currencies), group them by how the system treats them and take one or two per group. |
| Number or amount with thresholds | Both sides of every threshold in the source. "Free shipping from 50": 49 and 50. Add the smallest and largest allowed values. |
| Text | Typical; shortest allowed; longest allowed; special characters or non-Latin script when relevant to the feature. |
| Boolean or flag | Both. |
| Optional input | Present and absent. |
| Date or time | A typical one plus the boundaries the logic names: before/after a cutoff, end of month, leap day, timezone edge. |

Guidelines:

- **Use concrete values where the source gives numbers**, so each row can be
  executed as written: `49`, `50`, not `below threshold`, `at threshold`. Use
  a descriptive label only when no concrete value can be derived, and say so.
- **Keep numeric parameters purely numeric** if constraints need to compare
  them. One non-numeric value such as `empty` turns the whole parameter into
  strings. Put the special case into a separate parameter or a negative
  value.
- **Three to six values per parameter** is typical. The suite size is driven
  mainly by the two parameters with the most values (roughly their product),
  so a parameter with fifteen values dominates everything.
- **Do not add values to feel thorough.** Each value should have a reason: a
  class or a boundary named in the source, or a known risk.

## Negative values

Mark an invalid input with `~` when the system is supposed to **reject or
handle it as an error**: an out-of-range number, a malformed email, an
expired coupon, a missing mandatory field.

PICT keeps negative values apart: a row contains at most one. That is the
point, since most code stops at the first failed check, and a second invalid
input in the same row would never be exercised (input masking).

- Use a handful of negatives per parameter, one per distinct way of being
  invalid, not every imaginable bad input.
- An unusual but valid input is not negative. Zero items, the maximum length,
  a rarely used option: these are positive boundary values.
- If an invalid value makes other parameters irrelevant and you want to avoid
  spending rows on them, see "Excluding parameters" in `advanced.md`.

## Constraints versus assumptions

Go through the source and collect every statement that restricts which
values can be combined. For each one decide:

- **Impossible combination** → constraint.
- **Combination the system must refuse** → not a constraint. Keep it as a
  test, or model the triggering value as negative.
- **Not stated, but you believe it** → assumption. You may encode it, but it
  goes on the assumptions list for the user to confirm.

Typical assumptions worth flagging: which values count as the boundaries,
that an unmentioned option behaves like its neighbors, that two parameters
are independent, that a rule applies in one direction only.

Unclear or contradictory statements in the source are findings. Note them
instead of resolving them silently in whichever way makes the model work.

## Keeping the model small

If the model grows past about ten parameters, or the suite is larger than the
user can run:

- Split by feature. Two models of six parameters each are easier to review
  and often smaller in total than one of twelve.
- Merge values the system treats identically.
- Turn something that does not really vary into a precondition.
- Do not solve size by deleting constraints or boundaries.

## Where to look in each kind of source

| Source | Parameters come from | Constraints come from |
|---|---|---|
| User story, requirement | Nouns that vary, conditions in acceptance criteria ("when", "if", "for ... customers") | "only", "unless", "must", "not available" |
| API spec (OpenAPI and similar) | Query, path and body fields; headers; auth state | `required`, `enum`, `oneOf`, min/max, documented field dependencies |
| Form or screen | Each input; the user's role; the entry point | Fields that appear, disappear or lock depending on others |
| Function or method | Arguments; relevant object or global state | Preconditions, guards at the top of the body |
| Configuration matrix | Each axis: OS, browser, device, version, locale | Supported-platform tables ("Safari only on macOS and iOS") |
| Feature flags | Each flag; the user segment | Flags that depend on or exclude other flags |

When reading code, the branches show which inputs matter and where the
boundaries are. Take the intended rule from the requirement when one exists,
since code may contain the very defect the tests should find.

## The review checkpoint

Before running PICT on a derived model, show the user:

1. **Parameters and values**, one line each, with a short reason for
   non-obvious values ("49 / 50: free-shipping threshold").
2. **Constraints**, each next to the rule it encodes, in plain words.
3. **Negative values** and what makes each invalid.
4. **Assumptions and open questions**, anything not stated in the source.
5. **Left out on purpose**, with the reason.

Keep it short enough to read in a minute. Ask them to confirm or correct,
then generate.

## Worked example

Source:

> Customers can ship orders within the country, to the EU, or
> internationally. Shipping is standard or express; in-store pickup is
> offered for domestic orders only. Payment is by card, PayPal or invoice.
> Invoice is available for orders of 50 EUR or more. One coupon can be
> applied: a percentage discount or free shipping. Expired coupons are
> rejected with an error.

Model:

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

Reasoning shown at the checkpoint:

- `Cart total` 49 and 50 sit on either side of the invoice threshold; 1 and
  500 are a small and a large order. **Assumed:** no maximum order value is
  stated.
- "Pickup for domestic only" is an impossible combination (the option is not
  offered), so it is a constraint.
- "Invoice from 50 EUR": the text says "available", so the option is taken to
  be hidden below 50 and it is a constraint. **Open question:** if the user
  can select invoice below 50 and gets an error, this should be a test, and
  the constraint should be removed.
- `~Expired` is negative: the source says it is rejected.
- **Assumed:** a free-shipping coupon can be combined with pickup. The source
  does not say. Left unconstrained so the combination gets tested.
- Left out: currency and customer type, which the source does not mention.

Result: 21 test cases at pairwise coverage, against 432 exhaustive
combinations (3 x 3 x 3 x 4 x 4).
