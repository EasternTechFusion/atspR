# Split Data into Temporal Train and Test Sets

Performs a **time-ordered** (non-random) train/test split so that the
training set always precedes the test set chronologically – the correct
approach for time-series and any dataset where row order encodes time.

## Usage

``` r
split_data(data, train_ratio = 0.8, verbose = TRUE)
```

## Arguments

- data:

  A `data.frame` (rows assumed ordered by time).

- train_ratio:

  Numeric in (0, 1). Fraction of rows for training. Default `0.8` (80 /
  20 split).

- verbose:

  Logical (default `TRUE`).

## Value

An invisible list with elements:

- `train`:

  Training `data.frame`.

- `test`:

  Test `data.frame`.

- `train_idx`:

  Integer vector of training row indices.

- `test_idx`:

  Integer vector of test row indices.

- `ratio`:

  Named numeric `c(train = ..., test = ...)`.

## Examples

``` r
data(airquality)
clean <- airquality[complete.cases(airquality), ]
sp    <- split_data(clean, train_ratio = 0.7)
#> 
#> ============================================================
#>   TRAIN / TEST SPLIT  (temporal)
#> ============================================================
#> 
#>   Total rows  : 111
#>   Train ratio : 69%  (77 rows)
#>   Test  ratio : 31%  (34 rows)
#> 
nrow(sp$train); nrow(sp$test)
#> [1] 77
#> [1] 34
```
