# Fill Missing Timestamps in Time-Series Data

Handles two types of missingness common in time-series:

1.  **Missing rows** - timestamps that are absent entirely. These rows
    are inserted with `NA` for all value columns.

2.  **Missing values** - rows that exist but have `NA` in some columns.

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

## Details

tsibble and tibble inputs are automatically converted to `data.frame`.

## Examples

``` r
# Hourly data with a missing row
df <- data.frame(
  datetime = as.POSIXct(c("2024-01-01 08:00:00",
                           "2024-01-01 09:00:00",
                           "2024-01-01 11:00:00")),
  temp  = c(25.1, 25.4, 26.2),
  humid = c(80, NA, 85)
)
result <- fill_time_gaps(df, time_col = "datetime", n = 1, unit = "hour")
#> 
#> ============================================================
#>   STEP : Check and Fill Missing Timestamps
#> ============================================================
#> 
#>   Frequency  : every 1 hour(s)
#>   Expected   : 4 rows
#>   Found      : 3 rows
#>   Gaps       : 1 rows inserted
#> 
#>   NA before  : 1
#>   NA after   : 3
#>     └─ inserted rows  : 1 x 2 cols = 2  (filled in next step)
#>     └─ pre-existing   : 1
#> 
#> ------------------------------------------------------------
#>   Inserted timestamps (1 of 1)
#> ------------------------------------------------------------
#> [1] "2024-01-01 10:00:00 UTC"
#> 
#>   >> Next: ts_preprocess(gap$data, ...)
#> 
result$data
#>              datetime temp humid
#> 1 2024-01-01 08:00:00 25.1    80
#> 2 2024-01-01 09:00:00 25.4    NA
#> 3 2024-01-01 10:00:00   NA    NA
#> 4 2024-01-01 11:00:00 26.2    85

# Monthly data - missing February
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

# Quarterly data - missing Q2
df_q <- data.frame(
  date  = as.Date(c("2024-01-01", "2024-07-01", "2024-10-01")),
  sales = c(300, 420, 390)
)
result_q <- fill_time_gaps(df_q, time_col = "date", n = 1, unit = "quarter")
#> 
#> ============================================================
#>   STEP : Check and Fill Missing Timestamps
#> ============================================================
#> 
#>   Frequency  : every 1 quarter(s)
#>   (1 quarter = 3 months)
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
#> [1] "2024-04-01"
#> 
#>   >> Next: ts_preprocess(gap$data, ...)
#> 
```
