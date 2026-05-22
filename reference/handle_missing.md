# Handle Missing Values

Automatically chooses between **imputation** and **row deletion** based
on two criteria: dataset size (`n`) and overall missing rate.

## Usage

``` r
handle_missing(
  analysis_result = NULL,
  data = NULL,
  method = c("linear", "knn"),
  knn_k = 5L,
  verbose = TRUE
)
```

## Arguments

- analysis_result:

  The list returned by
  [`missing_analysis()`](https://easterntechfusion.github.io/atspR/reference/missing_analysis.md).
  Alternatively, pass a plain `data.frame` to `data`.

- data:

  A `data.frame`. Used only when `analysis_result` is `NULL`.

- method:

  Character. Imputation method: `"linear"` (default) or `"knn"`.

- knn_k:

  Integer. Number of neighbours for KNN (default 5).

- verbose:

  Logical. Print progress messages (default `TRUE`).

## Value

An invisible list with elements:

- `data_clean`:

  The cleaned `data.frame`.

- `action`:

  Character: `"drop"` or `"impute"`.

- `method`:

  Imputation method used (or `"none"`).

- `imputed_mask`:

  Logical `data.frame` marking imputed cells (same dimensions as
  `data_clean`). All `FALSE` when action is `"drop"`.

- `n_imputed`:

  Integer. Number of cells that were imputed.

- `report`:

  A short character string summarising the action taken.

## Details

Decision rules:

- `n <= 50` -\> always impute (data too small to lose rows)

- `n > 50` and `missing > 5%` -\> impute

- `n > 50` and `missing <= 5%` -\> drop rows with NA

When imputing, linear interpolation is the default; KNN imputation is
available as an alternative.

## Examples

``` r
data(airquality)
ana  <- missing_analysis(airquality, plot = FALSE)
#> 
#> ============================================================
#>   STEP 3/7 : Missing Value Analysis
#> ============================================================
#> 
#>   Rows    : 153  |  Cols: 6  |  Total cells: 918
#>   Missing : 4.79%  (44 cells)  |  2 / 6 cols affected
#>   Action  : DROP  -- missing = 4.79% <= 5% threshold, safe to remove rows
#> 
#> ------------------------------------------------------------
#>   Missing per column
#> ------------------------------------------------------------
#>  variable n_missing pct_missing
#>     Ozone        37      24.18%
#>   Solar.R         7       4.58%
#> 
clean <- handle_missing(ana)
#> 
#> ============================================================
#>   STEP 5/9 : Handle Missing Values  [DROP]
#> ============================================================
#> 
#>   Missing : 4.79%  |  Reason: 50 < n = 153 < 1000 and missing = 4.79% <= 5% -> drop rows
#> 
#>   Rows before : 153  ->  after: 111  (-42 removed)
#> 
clean$report
#> [1] "Action: ROW DELETION  |  Removed 42 rows  |  50 < n = 153 < 1000 and missing = 4.79% <= 5% -> drop rows"
```
