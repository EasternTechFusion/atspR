# Export Preprocessing Results to CSV

Saves the scaled train and test sets (and optionally the cleaned data
and summary report) produced by
[`ts_preprocess()`](https://easterntechfusion.github.io/atspR/reference/ts_preprocess.md)
to CSV files in a specified directory.

## Usage

``` r
ts_export(
  result,
  dir = "atspR_output",
  prefix = "atspR",
  export_clean = TRUE,
  export_report = FALSE,
  verbose = TRUE
)
```

## Arguments

- result:

  The list returned by
  [`ts_preprocess()`](https://easterntechfusion.github.io/atspR/reference/ts_preprocess.md).

- dir:

  Character. Directory to save files. Created if it does not exist.
  Default `"atspR_output"`.

- prefix:

  Character. Filename prefix. Default `"atspR"`.

- export_clean:

  Logical. Also export `data_clean`. Default `TRUE`.

- export_report:

  Logical. Also export `missing_report` and `scale_params` as CSV.
  Default `FALSE`.

- verbose:

  Logical (default `TRUE`).

## Value

Invisibly returns a named character vector of exported file paths.

## Examples

``` r
if (FALSE) { # \dontrun{
data(airquality)
result <- ts_preprocess(airquality, verbose = FALSE)
ts_export(result, dir = "output", prefix = "airquality")
} # }
```
