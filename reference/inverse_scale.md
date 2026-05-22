# Inverse-Transform Scaled Data

Reverses the scaling applied by
[`scale_data()`](https://easterntechfusion.github.io/atspR/reference/scale_data.md)
to recover original units.

## Usage

``` r
inverse_scale(scaled_data, scale_result)
```

## Arguments

- scaled_data:

  A `data.frame` of scaled values.

- scale_result:

  The list returned by
  [`scale_data()`](https://easterntechfusion.github.io/atspR/reference/scale_data.md).

## Value

A `data.frame` with the scaled columns back in their original units.

## Examples

``` r
data(airquality)
clean <- airquality[complete.cases(airquality), ]
sp    <- split_data(clean, verbose = FALSE)
sc    <- scale_data(sp, verbose = FALSE)
original_train <- inverse_scale(sc$train_scaled, sc)
```
