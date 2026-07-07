# Create recoding steps for categorical variables

This function uses optimized expression evaluation for all recoding
conditions. All conditional expressions are validated and optimized for
efficient execution.

## Usage

``` r
step_recode(
  svy,
  new_var,
  ...,
  .default = NA_character_,
  .name_step = NULL,
  ordered = FALSE,
  .copy = use_copy_default(),
  comment = "Recode step",
  .to_factor = FALSE,
  .level = "auto",
  use_copy = deprecated()
)
```

## Arguments

- svy:

  A `Survey` or `RotativePanelSurvey` object. If NULL, creates a step
  that can be applied later using the pipe operator (%\>%)

- new_var:

  Name of the new variable to create (unquoted)

- ...:

  Sequence of two-sided formulas defining recoding rules. Left-hand side
  (LHS) is a conditional expression, right-hand side (RHS) defines the
  replacement value. Format: `condition ~ value`

- .default:

  Default value assigned when no condition is met. Defaults to
  `NA_character_`

- .name_step:

  **\[deprecated\]** Custom name for the step in the history. Now
  auto-generated from the variable name. Use `comment` for user-facing
  documentation instead.

- ordered:

  Logical indicating whether the new variable should be an ordered
  factor. Defaults to FALSE

- .copy:

  Logical indicating whether to create a copy of the object before
  applying transformations. Defaults to
  [`use_copy_default()`](https://metasurveyr.github.io/metasurvey/reference/use_copy_default.md)

- comment:

  Descriptive text for the step for documentation and traceability.
  Compatible with Markdown syntax. Defaults to "Recode step"

- .to_factor:

  Logical indicating whether the new variable should be converted to a
  factor. Defaults to FALSE

- .level:

  For RotativePanelSurvey objects (default `"auto"`), specifies the
  level where recoding is applied: `"implantation"`, `"follow_up"`,
  `"quarter"`, `"month"`, or `"auto"`

- use_copy:

  **\[deprecated\]** Use `.copy` instead.

## Value

Same type of input object (`Survey` or `RotativePanelSurvey`) with the
new recoded variable and the step added to the history

## Details

**Execution model:** The recoding is applied immediately when the step
is created and the step is recorded as already executed (`bake = TRUE`).
Calling
[`bake_steps()`](https://metasurveyr.github.io/metasurvey/reference/bake_steps.md)
afterwards is safe: executed steps are skipped, so rules are never
applied twice.

**Condition evaluation:** Conditions are two-sided formulas evaluated in
order. The first matching condition determines the assigned value. If no
condition matches, `.default` is used. Replacement values keep their
native type (character, numeric, integer or logical).

Condition examples:

- Simple: `variable == 1 ~ "Yes"`

- Complex: `age >= 18 & income > 12000 ~ "High"`

- Vectorized: `variable %in% c(1,2,3) ~ "Group A"`

- Logical: `!is.na(education) ~ "Has education"`

## See also

[`step_compute`](https://metasurveyr.github.io/metasurvey/reference/step_compute.md)
for more complex calculations
[`bake_steps`](https://metasurveyr.github.io/metasurvey/reference/bake_steps.md)
to execute all pending steps
[`get_steps`](https://metasurveyr.github.io/metasurvey/reference/get_steps.md)
to view step history

Other steps:
[`bake_steps()`](https://metasurveyr.github.io/metasurvey/reference/bake_steps.md),
[`get_steps()`](https://metasurveyr.github.io/metasurvey/reference/get_steps.md),
[`step_compute()`](https://metasurveyr.github.io/metasurvey/reference/step_compute.md),
[`step_filter()`](https://metasurveyr.github.io/metasurvey/reference/step_filter.md),
[`step_join()`](https://metasurveyr.github.io/metasurvey/reference/step_join.md),
[`step_remove()`](https://metasurveyr.github.io/metasurvey/reference/step_remove.md),
[`step_rename()`](https://metasurveyr.github.io/metasurvey/reference/step_rename.md),
[`step_validate()`](https://metasurveyr.github.io/metasurvey/reference/step_validate.md),
[`view_graph()`](https://metasurveyr.github.io/metasurvey/reference/view_graph.md)

## Examples

``` r
# Basic recode: categorize ages
dt <- data.table::data.table(
  id = 1:6, age = c(10, 25, 45, 60, 70, 80), w = 1
)
svy <- Survey$new(
  data = dt, edition = "2023", type = "test",
  psu = NULL, engine = "data.table",
  weight = add_weight(annual = "w")
)
svy <- svy |>
  step_recode(
    age_group,
    age < 18 ~ "Under 18",
    age >= 18 & age < 65 ~ "Working age",
    age >= 65 ~ "Senior",
    .default = "Unknown"
  )
svy <- bake_steps(svy)
get_data(svy)
#>       id   age     w   age_group
#>    <int> <num> <num>      <char>
#> 1:     1    10     1    Under 18
#> 2:     2    25     1 Working age
#> 3:     3    45     1 Working age
#> 4:     4    60     1 Working age
#> 5:     5    70     1      Senior
#> 6:     6    80     1      Senior

# \donttest{
# ECH example: labor force status
# ech <- ech |>
#   step_recode(labor_status,
#     POBPCOAC == 2 ~ "Employed",
#     POBPCOAC %in% 3:5 ~ "Unemployed",
#     .default = "Missing")
# }
```
