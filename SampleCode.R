# install.packages("devtools")
devtools::install_github("EasternTechFusion/atspR")
install.packages("readxl")

library(atspR)
library(readxl)
RawData <- read_excel("RawData.xlsx")
df  <- combine_datetime(RawData, date_col = "Date",
                        time_col = "Time",
                        new_col = "datetime",
                        time_type = "string")

gap <- fill_time_gaps(df, time_col = "datetime",
                      n = 1,
                      unit = "hour")


result <- ts_preprocess(
  data          = gap$data,
  train_ratio   = 0.8,
  impute_method = "linear",
  target_col    = "VPD",
  k_folds       = 5
)
result$train_scaled
result$test_scaled

# ts_export(result, dir = "C:/Users/suepp/Documents/testR", prefix = "data")
