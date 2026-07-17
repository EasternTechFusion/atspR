# Fill Missing Timestamps in Time-Series Data

Handles three types of timestamp trouble common in time-series:

1.  **Drifted timestamps** - a reading scheduled for 13:05 was logged at
    13:06 instead. For `unit \%in\% c("sec","min","hour","day")`, each
    observed timestamp is snapped to the nearest point on the regular
    grid, provided it falls within `tolerance` of that point. (Not
    applicable to `"month"`/`"quarter"`/`"year"`, whose calendar steps
    have no fixed duration - those units always use exact matching, as
    before.)

2.  **Missing rows** - timestamps that are absent entirely. These rows
    are inserted with `NA` for all value columns.

3.  **Missing values** - rows that exist but have `NA` in some columns.

After filling gaps the result is ready to pass into
[`missing_analysis()`](https://easterntechfusion.github.io/atspR/reference/missing_analysis.md)
and
[`handle_missing()`](https://easterntechfusion.github.io/atspR/reference/handle_missing.md).

## Usage

``` r
fill_time_gaps(
  data,
  time_col,
  n = 1,
  unit = c("sec", "min", "hour", "day", "month", "quarter", "year"),
  tolerance = NULL,
  verbose = TRUE
)
```

## Arguments

- data:

  A `data.frame`, `tibble`, or `tsibble` with a timestamp column, sorted
  ascending. tsibble and tibble are converted to `data.frame`
  automatically.

- time_col:

  Character. Name of the timestamp column (must be `Date` or `POSIXct`).
  Use
  [`combine_datetime()`](https://easterntechfusion.github.io/atspR/reference/combine_datetime.md)
  first if date and time are stored in separate columns.

- n:

  Numeric. Number of units per step. e.g. `1`, `3`, `15`.

- unit:

  Character. One of `"sec"`, `"min"`, `"hour"`, `"day"`, `"month"`,
  `"quarter"`, `"year"`.

  - `"month"` - calendar months (1, 2, 3, ...)

  - `"quarter"` - calendar quarters of 3 months each (Q1, Q2, Q3, Q4)

  Note: `"month"` and `"quarter"` require the timestamp column to be
  `Date` and each value to fall on the first day of the month (e.g.
  `2024-01-01`, `2024-04-01`).

- tolerance:

  Numeric seconds, or `NULL`. Only used when
  `unit \%in\% c("sec","min","hour","day")`. Maximum distance an
  observed timestamp may sit from its nearest grid point and still be
  snapped to it. `NULL` (default) uses half the step size (`n`/`unit`),
  the widest tolerance that still avoids ambiguity between two adjacent
  grid points. Set to `0` to disable snapping and fall back to the
  legacy exact-match behavior (a timestamp must land exactly on the grid
  to count; otherwise it is left as-is and its grid slot is reported as
  a gap). Ignored (with a warning if non-`NULL`) for `"month"`,
  `"quarter"`, and `"year"`.

- verbose:

  Logical (default `TRUE`).

## Value

An invisible list with elements:

- `data`:

  Complete `data.frame` with no missing timestamps. Inserted rows have
  `NA` for all value columns.

- `n_gaps`:

  Number of timestamp rows inserted.

- `n_na_before`:

  Total NA cells before gap-filling.

- `n_na_after`:

  Total NA cells after gap-filling (includes inserted rows).

- `gap_timestamps`:

  Vector of timestamps that were inserted.

- `time_col`:

  Name of the timestamp column.

- `freq`:

  Frequency string describing the step used.

- `n_snapped`:

  Number of observed timestamps snapped onto the grid (`0` for calendar
  units or when `tolerance = 0`).

- `n_dropped_duplicate`:

  Rows dropped because a closer observation already claimed the same
  grid slot.

- `n_dropped_tolerance`:

  Rows dropped because they were too far from any grid slot.

## Details

tsibble and tibble inputs are automatically converted to `data.frame`.

## Examples

``` r
# Sensor drift: 13:06 should have been 13:05
df <- data.frame(
  datetime = as.POSIXct(c("2024-01-01 13:00:00",
                           "2024-01-01 13:06:00",
                           "2024-01-01 13:10:00")),
  vpd = c(1.2, 1.4, 1.5)
)
result <- fill_time_gaps(df, time_col = "datetime", n = 5, unit = "min")
#> 
#> ============================================================
#>   STEP : Check and Fill Missing Timestamps
#> ============================================================
#> 
#>   Frequency  : every 5 minute(s)
#>   Tolerance  : +/- 150 sec
#>   Expected   : 3 rows
#>   Found      : 3 rows
#>   Gaps       : 0 rows inserted
#>   Snapped    : 1 timestamp(s) moved onto the grid
#>   Dropped    : 0 duplicate(s), 0 out-of-tolerance
#> 
#>   NA before  : 0
#>   NA after   : 0
#> 
#>   [OK] No gaps found
#> 
#>   >> Next: ts_preprocess()
#> 
result$data
#>              datetime vpd
#> 1 2024-01-01 13:00:00 1.2
#> 2 2024-01-01 13:05:00 1.4
#> 3 2024-01-01 13:10:00 1.5

# Monthly data - missing February (calendar unit: exact match only)
df_m <- data.frame(
  date  = as.Date(c("2024-01-01", "2024-03-01", "2024-04-01")),
  sales = c(100, 130, 150)
)
result_m <- fill_time_gaps(df_m, time_col = "date", n = 1, unit = "month")
#> 
#> ============================================================
#>   STEP : Check and Fill Missing Timestamps
#> ============================================================
#> 
#>   Frequency  : every 1 month(s)
#>   Expected   : 4 rows
#>   Found      : 3 rows
#>   Gaps       : 1 rows inserted
#> 
#>   NA before  : 0
#>   NA after   : 1
#>     └─ inserted rows  : 1 x 1 cols = 1  (filled in next step)
#>     └─ pre-existing   : 0
#> 
#> ------------------------------------------------------------
#>   Inserted timestamps (1 of 1)
#> ------------------------------------------------------------
#> [1] "2024-02-01"
#> 
#>   >> Next: ts_preprocess(gap$data, ...)
#> 
```
