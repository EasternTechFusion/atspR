# Auto-Convert Columns to Numeric

Scans all character and factor columns and attempts to convert them to
numeric. A column is converted only when the proportion of values that
can be parsed as numbers meets the `min_success_rate` threshold. Values
that cannot be parsed become `NA`.

## Usage

``` r
coerce_numeric(data, cols = NULL, min_success_rate = 0.8, verbose = TRUE)
```

## Arguments

- data:

  A `data.frame`.

- cols:

  Character vector. Columns to attempt conversion on. `NULL` (default)
  tries all character and factor columns.

- min_success_rate:

  Numeric in (0, 1\]. Minimum fraction of non-NA values that must parse
  successfully for the column to be converted. Default `0.8` (80%).

- verbose:

  Logical (default `TRUE`).

## Value

The `data.frame` with eligible columns converted to numeric.

## Details

This step should run **after**
[`standardize_na()`](https://easterntechfusion.github.io/atspR/reference/standardize_na.md)
so that custom missing indicators (e.g. `"-"`, `"Missing"`) are already
`NA` and do not count against the success rate.

## Examples

``` r
df <- data.frame(
  date  = c("2024-01-01", "2024-01-02", "2024-01-03"),
  temp  = c("25.1", "26.3", "NA"),
  humid = c("80", "85", "90"),
  label = c("A", "B", "C"),
  stringsAsFactors = FALSE
)
# temp and humid will be converted; date and label will stay as character
result <- coerce_numeric(df)
#> 
#> ============================================================
#>   COERCE TO NUMERIC
#> ============================================================
#> 
#>   Min success rate : 80%
#> 
#>  column success converted na_added
#>    date      0%        no        3
#>    temp   66.7%        no        1
#>   humid    100%       YES        0
#>   label      0%        no        3
#> 
#>   Converted : 1 column(s)  [humid]
#>   Skipped   : 3 column(s)  [date, temp, label]
#> 
str(result)
#> 'data.frame':    3 obs. of  4 variables:
#>  $ date : chr  "2024-01-01" "2024-01-02" "2024-01-03"
#>  $ temp : chr  "25.1" "26.3" "NA"
#>  $ humid: num  80 85 90
#>  $ label: chr  "A" "B" "C"
```
