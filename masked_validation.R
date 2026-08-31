# Install packages (run once)
install.packages("tidyverse")
install.packages("tidytext")
install.packages("caret")
install.packages("readxl")
install.packages("e1071")

# Load libraries
library(tidyverse)
library(tidytext)
library(caret)
library(readxl)
library(e1071)

# Load dataset
df <- read_excel("ClaimDetails_for_distribution.xlsx")

# Keep rows with known severity
dataset <- df %>%
  filter(!is.na(`CAT Severity Code`)) %>%
  mutate(row_id = row_number())

# -------------------------
# MASK 20% OF SEVERITY
# -------------------------

set.seed(123)

mask_index <- sample(1:nrow(dataset),
                     size = 0.2 * nrow(dataset))

dataset$Severity_original <- dataset$`CAT Severity Code`
dataset$`CAT Severity Code`[mask_index] <- NA

# Split data
train_set <- dataset %>% filter(!is.na(`CAT Severity Code`))
test_set  <- dataset %>% filter(is.na(`CAT Severity Code`))

# -------------------------
# TRAIN MODEL
# -------------------------

tokens_train <- train_set %>%
  unnest_tokens(word, `Cause Of Injury Text`) %>%
  anti_join(stop_words, by="word")

tfidf_train <- tokens_train %>%
  count(row_id, word) %>%
  bind_tf_idf(word, row_id, n)

train_matrix <- tfidf_train %>%
  select(row_id, word, tf_idf) %>%
  pivot_wider(names_from = word,
              values_from = tf_idf,
              values_fill = 0)

train_matrix <- train_matrix %>%
  left_join(train_set %>% select(row_id, `CAT Severity Code`),
            by="row_id")

train_matrix$Severity <- as.factor(train_matrix$`CAT Severity Code`)
train_matrix$`CAT Severity Code` <- NULL

train_data <- train_matrix %>%
  select(-row_id)

# Remove constant columns
train_data <- train_data %>%
  select(where(~ n_distinct(.) > 1))

# Remove zero / near-zero variance predictors
nzv <- nearZeroVar(train_data)

if(length(nzv) > 0){
  train_data <- train_data[, -nzv]
}

# Train SVM model
model <- train(
  Severity ~ .,
  data = train_data,
  method = "svmLinear",
  trControl = trainControl(method="cv", number=5)
)

# -------------------------
# PREPARE TEST DATA
# -------------------------

tokens_test <- test_set %>%
  unnest_tokens(word, `Cause Of Injury Text`) %>%
  anti_join(stop_words, by="word")

tfidf_test <- tokens_test %>%
  count(row_id, word) %>%
  bind_tf_idf(word, row_id, n)

test_matrix <- tfidf_test %>%
  select(row_id, word, tf_idf) %>%
  pivot_wider(names_from = word,
              values_from = tf_idf,
              values_fill = 0)

# Align vocabulary with training data
missing_cols <- setdiff(names(train_data), names(test_matrix))
missing_cols <- missing_cols[missing_cols != "Severity"]

for(col in missing_cols){
  test_matrix[[col]] <- 0
}

test_matrix <- test_matrix %>%
  select(names(train_data)[names(train_data)!="Severity"])

# -------------------------
# PREDICT MASKED VALUES
# -------------------------

predicted <- predict(model, test_matrix)

actual <- dataset$Severity_original[mask_index]

# -------------------------
# VALIDATION RESULTS
# -------------------------

cm <- confusionMatrix(predicted, as.factor(actual))

print(cm)

cat("\nAccuracy:", cm$overall["Accuracy"])
cat("\nKappa:", cm$overall["Kappa"])
cat("\nSensitivity:", mean(cm$byClass[,"Sensitivity"]))
cat("\nSpecificity:", mean(cm$byClass[,"Specificity"]))


unique(dataset_notnull$`CAT Severity Code`)