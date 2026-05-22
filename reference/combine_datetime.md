# Combine Separate Date and Time Columns into One Timestamp

Many datasets store date and time in separate columns. This function
merges them into a single `POSIXct` column ready for
[`fill_time_gaps()`](https://easterntechfusion.github.io/atspR/reference/fill_time_gaps.md).
The date format is detected automatically.

## Usage

``` r
combine_datetime(
  data,
  date_col = "date",
  time_col = "time",
  new_col = "datetime",
  date_format = NULL,
  time_type = c("hour", "hhmm", "string"),
  tz = "UTC",
  drop_cols = TRUE,
  verbose = TRUE
)
```

## Arguments

- data:

  A `data.frame`.

- date_col:

  Character. Name of the date column. Supports many formats
  automatically:

  - `"2024-01-31"` or `"2024/01/31"`

  - `"31-01-2024"` or `"31/01/2024"`

  - `"01-31-2024"` or `"01/31/2024"`

  - `"31.01.2024"` or `"2024.01.31"`

  - `"31 Jan 2024"` or `"January 31, 2024"`

  - `"20240131"` (compact)

- time_col:

  Character. Name of the time/hour column.

- new_col:

  Character. Name of the new combined column. Default `"datetime"`.

- date_format:

  Character. Override auto-detection with a `strptime` format string.
  Leave `NULL` (default) to auto-detect.

- time_type:

  Character. How the time column is stored:

  - `"hour"` - integer 0-23, e.g. `8`, `14`

  - `"hhmm"` - integer HHMM, e.g. `830`, `1430`

  - `"string"` - character `"HH:MM"` or `"HH:MM:SS"`

- tz:

  Character. Timezone. Default `"UTC"`.

- drop_cols:

  Logical. If `TRUE` (default), remove `date_col` and `time_col` after
  combining.

- verbose:

  Logical (default `TRUE`).

## Value

The original `data.frame` with a new `POSIXct` column prepended (and
optionally the source columns removed).

## Examples

``` r
# Hour stored as integer
df <- data.frame(
  date = c("2024-01-01", "2024-01-01", "2024-01-01"),
  hour = c(8L, 9L, 11L),
  temp = c(25.1, 25.4, 26.2)
)
df2 <- combine_datetime(df, date_col = "date", time_col = "hour",
                        time_type = "hour")
#> 
#> ============================================================
#>   STEP : Combine Date + Time into One Column
#> ============================================================
#> 
#>   Date column : date  (format: %Y-%m-%d [auto])
#>   New column  : datetime  (tz: UTC)
#>   Sample      : 2024-01-01 08:00:00
#> 
#>   >> Next: fill_time_gaps()
#> 
df2$datetime
#> [1] "2024-01-01 08:00:00 UTC" "2024-01-01 09:00:00 UTC"
#> [3] "2024-01-01 11:00:00 UTC"

# Time stored as "HH:MM" string
df3 <- data.frame(
  date = c("01/01/2024", "01/01/2024"),
  time = c("08:30", "09:00"),
  val  = c(10, 12)
)
df4 <- combine_datetime(df3, date_col = "date", time_col = "time",
                        time_type = "string")
#> 
#> ============================================================
#>   STEP : Combine Date + Time into One Column
#> ============================================================
#> 
#>   Date column : date  (format: %Y/%m/%d [auto])
#>   New column  : datetime  (tz: UTC)
#>   Sample      : 1-01-20 08:30:00
#> 
#>   >> Next: fill_time_gaps()
#> 
```
