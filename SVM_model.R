# Install packages (run once)
install.packages("tidyverse")
install.packages("tidytext")
install.packages("caret")
install.packages("readxl")
install.packages("writexl")
install.packages("e1071")

# Load libraries
library(tidyverse)
library(tidytext)
library(caret)
library(readxl)
library(writexl)
library(e1071)

# Load data
df <- read_excel("ClaimDetails_for_distribution.xlsx")
df <- ClaimDetails_for_distribution_1_
# Split datasets
dataset_notnull <- df %>%
  filter(!is.na(`CAT Severity Code`)) %>%
  mutate(row_id = row_number())

dataset_a <- df %>%
  filter(is.na(`CAT Severity Code`)) %>%
  mutate(row_id = row_number())

# -------------------------
# TRAINING DATA PROCESSING
# -------------------------

tokens <- dataset_notnull %>%
  unnest_tokens(word, `Cause Of Injury Text`) %>%
  anti_join(stop_words, by = "word")

tfidf <- tokens %>%
  count(row_id, word) %>%
  bind_tf_idf(word, row_id, n)

tfidf_matrix <- tfidf %>%
  select(row_id, word, tf_idf) %>%
  pivot_wider(names_from = word, values_from = tf_idf, values_fill = 0)

# Join severity label correctly
tfidf_matrix <- tfidf_matrix %>%
  left_join(dataset_notnull %>% select(row_id, `CAT Severity Code`), by = "row_id")

# Rename target variable
tfidf_matrix$Severity <- as.factor(tfidf_matrix$`CAT Severity Code`)
tfidf_matrix$`CAT Severity Code` <- NULL

# Remove row_id from predictors
train_data <- tfidf_matrix %>%
  select(-row_id)

# -------------------------
# TRAIN MODEL
# -------------------------
# Remove constant columns
train_data <- train_data %>%
  select(where(~ n_distinct(.) > 1))

model <- train(
  Severity ~ .,
  data = train_data,
  method = "svmLinear",
  trControl = trainControl(method = "cv", number = 5)
)

# -------------------------
# PREPARE PREDICTION DATA
# -------------------------

tokens_pred <- dataset_a %>%
  unnest_tokens(word, `Cause Of Injury Text`) %>%
  anti_join(stop_words, by = "word")

tfidf_pred <- tokens_pred %>%
  count(row_id, word) %>%
  bind_tf_idf(word, row_id, n)

tfidf_pred_matrix <- tfidf_pred %>%
  select(row_id, word, tf_idf) %>%
  pivot_wider(names_from = word, values_from = tf_idf, values_fill = 0)

# Ensure same vocabulary as training
missing_cols <- setdiff(names(train_data), names(tfidf_pred_matrix))
missing_cols <- missing_cols[missing_cols != "Severity"]

for (col in missing_cols) {
  tfidf_pred_matrix[[col]] <- 0
}

tfidf_pred_matrix <- tfidf_pred_matrix %>%
  select(names(train_data)[names(train_data) != "Severity"])

# -------------------------
# PREDICT
# -------------------------

predicted_severity <- predict(model, tfidf_pred_matrix)

dataset_a$Predicted_Severity <- predicted_severity

# Combine datasets
final_dataset <- bind_rows(dataset_notnull, dataset_a)


pred_train <- predict(model, train_data)
cm <- confusionMatrix(pred_train, train_data$Severity)
cm


# Save file
#write_xlsx(final_dataset, "ClaimDetails_predicted_severity_method2.xlsx")




install.packages("openxlsx")
install.packages("writexl")
library(writexl)
library(openxlsx)




out_dir <- "C:/Users/shahr/Downloads"

if (!dir.exists(out_dir)) {
  dir.create(out_dir, recursive = TRUE)
}

write.csv(
  final_dataset,
  file.path(out_dir, "output.csv"),
  row.names = FALSE
)




