# Standardise Missing Value Indicators to NA

Converts custom "missing" representations such as `"-"`, `"Missing"`,
`"N/A"`, `"none"`, `"null"`, `""`, or any user-defined string/number
into proper `NA` values so that the rest of the pipeline can detect and
handle them correctly.

## Usage

``` r
standardize_na(
  data,
  na_strings = character(0),
  na_numbers = NULL,
  cols = NULL,
  trim = TRUE,
  verbose = TRUE
)
```

## Arguments

- data:

  A `data.frame`.

- na_strings:

  Character vector. Additional strings to treat as `NA`. These are
  combined with the built-in defaults. Set to `character(0)` to use only
  the defaults.

- na_numbers:

  Numeric vector. Numeric sentinel values to treat as `NA`, e.g. `-999`,
  `9999`, `0`. Default `NULL` (none).

- cols:

  Character vector. Column names to process. `NULL` (default) processes
  all columns.

- trim:

  Logical. If `TRUE` (default), trim leading/trailing whitespace from
  character columns before matching.

- verbose:

  Logical (default `TRUE`).

## Value

The `data.frame` with all matched values replaced by `NA`.

## Examples

``` r
df <- data.frame(
  date  = c("2024-01-01", "2024-01-02", "2024-01-03"),
  temp  = c(25.1, -999, 26.2),
  humid = c("80", "-", "Missing"),
  wind  = c("N/A", "12", "")
)

# Use defaults + custom
clean <- standardize_na(df,
  na_strings = c("N/A"),
  na_numbers = c(-999)
)
#> 
#> ============================================================
#>   STANDARDISE MISSING VALUES
#> ============================================================
#> 
#>   Built-in NA strings : 31 patterns
#>   User NA strings     : N/A
#>   NA numbers          : -999
#>   Cells converted     : 5
#> 
#> ------------------------------------------------------------
#>   Conversions per Column
#> ------------------------------------------------------------
#>  column converted
#>    temp         1
#>   humid         2
#>    wind         2
#> 
clean
#>         date temp humid wind
#> 1 2024-01-01 25.1    80 <NA>
#> 2 2024-01-02   NA  <NA>   12
#> 3 2024-01-03 26.2  <NA> <NA>
```
