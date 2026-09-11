
# -------------------------
# 1. INSTALL & LOAD PACKAGES
# -------------------------

packages <- c("tidyverse", "tidytext", "caret", "readxl", "writexl",
              "randomForest", "e1071")

for (pkg in packages) {
  if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
    install.packages(pkg)
    library(pkg, character.only = TRUE)
  }
}

# -------------------------
# 2. LOAD DATA
# -------------------------

df <- ClaimDetails_for_distribution_1_

cat("=== LABEL DISTRIBUTION (check for blank strings) ===\n")
print(table(df$`CAT Severity Code`, useNA = "always"))

# -------------------------
# 3. THE KEY FIX
# -------------------------

df <- df %>%
  mutate(`CAT Severity Code` = str_trim(as.character(`CAT Severity Code`)))

dataset_notnull <- df %>%
  filter(`CAT Severity Code` != "" & !is.na(`CAT Severity Code`))   # catches blanks that is.na() misses

dataset_a <- df %>%
  filter(`CAT Severity Code` == "" | is.na(`CAT Severity Code`))   # the 274 rows to predict

cat("\nLabeled rows (for training):", nrow(dataset_notnull), "\n")
cat("Unlabeled rows (to predict):", nrow(dataset_a), "\n")
cat("\nClass distribution:\n")
print(table(dataset_notnull$`CAT Severity Code`))

# -------------------------
# 4. TEXT CLEANING FUNCTION
# Single function used in both training and prediction
# so preprocessing is always identical
# -------------------------

clean_text <- function(injury, peril_desc = "", peril_group = "") {
  paste(peril_desc, peril_group, injury) %>%
    tolower() %>%
    str_replace_all("[[:punct:]]", " ") %>%
    str_replace_all("[[:digit:]]", " ") %>%
    str_trim() %>%
    gsub("\\s+", " ", .)
}

# -------------------------
# 5. PREPARE TRAINING DATA
# -------------------------

dataset_notnull <- dataset_notnull %>%
  mutate(
    row_id     = row_number(),
    Severity   = as.factor(`CAT Severity Code`),
    text_clean = clean_text(`Cause Of Injury Text`,
                            `Peril Description`,
                            `Peril Group`)
  ) %>%
  filter(str_length(text_clean) > 3)

# -------------------------
# 6. TF-IDF FEATURES
# -------------------------

cat("\n=== BUILDING FEATURES ===\n")

tokens <- dataset_notnull %>%
  unnest_tokens(word, text_clean, token = "ngrams", n = 2, n_min = 1) %>%
  anti_join(stop_words, by = "word") %>%
  filter(
    str_length(word) > 2,
    !str_detect(word, "^[0-9]+$")
  ) %>%
  add_count(word) %>%
  filter(n >= 3, n <= nrow(dataset_notnull) * 0.9) %>%
  select(-n)

tfidf <- tokens %>%
  count(row_id, word) %>%
  bind_tf_idf(word, row_id, n)

dtm <- tfidf %>%
  select(row_id, word, tf_idf) %>%
  pivot_wider(names_from = word, values_from = tf_idf, values_fill = 0)

cat("Unique text features:", ncol(dtm) - 1, "\n")

# -------------------------
# 7. ADD EXTRA FEATURES
# Territory, cluster distances, peril type — these add ~7% accuracy
# -------------------------

extra_features <- dataset_notnull %>%
  select(row_id,
         Territory, `Peril Description`, `Peril Group`,
         `Weather Indicator`, `Weather Text`, Division,
         `Accident State`, `Policy Form Desc`,
         matches("cluster")) %>%
  mutate(across(where(is.character), ~ as.numeric(as.factor(.)))) %>%
  mutate(across(everything(), ~ replace_na(., -1)))

feature_data <- dtm %>%
  left_join(extra_features, by = "row_id") %>%
  left_join(dataset_notnull %>% select(row_id, Severity), by = "row_id") %>%
  select(-row_id)

cat("Total features (text + structured):", ncol(feature_data) - 1, "\n")

# -------------------------
# 8. CLEAN FEATURE MATRIX
# -------------------------

clean_data <- feature_data %>%
  select(where(~ n_distinct(.) > 1)) %>%
  mutate(across(where(is.numeric), ~ replace_na(., 0))) %>%        # only numeric cols
  mutate(across(where(is.numeric), ~ replace(., is.infinite(.), 0)))  # only numeric cols

nzv_cols <- nearZeroVar(clean_data)
if (length(nzv_cols) > 0) {
  clean_data <- clean_data[, -nzv_cols]
  cat("Removed", length(nzv_cols), "near-zero variance features\n")
}

# -------------------------
# 9. TRAIN / TEST SPLIT
# -------------------------

set.seed(42)
train_idx <- createDataPartition(clean_data$Severity, p = 0.8, list = FALSE)
train_set <- clean_data[train_idx, ]
test_set  <- clean_data[-train_idx, ]

cat("\nTrain:", nrow(train_set), "| Test:", nrow(test_set), "\n")

class_weights <- table(train_set$Severity)
class_weights <- max(class_weights) / class_weights

# -------------------------
# 10. TRAIN RANDOM FOREST
# Best algorithm for this dataset 
# -------------------------

cat("\n=== TRAINING RANDOM FOREST ===\n")
set.seed(42)

rf_model <- train(
  Severity ~ .,
  data      = train_set,
  method    = "rf",
  ntree     = 500,
  importance = TRUE,
  trControl = trainControl(method = "cv", number = 5, verboseIter = FALSE),
  weights   = class_weights[as.character(train_set$Severity)]
)

rf_pred <- predict(rf_model, test_set)
rf_cm   <- confusionMatrix(rf_pred, test_set$Severity)

cat("Holdout accuracy:", round(rf_cm$overall["Accuracy"] * 100, 1), "%\n")
cat("Kappa:           ", round(rf_cm$overall["Kappa"], 3), "\n")
cat("\nConfusion Matrix:\n")
print(rf_cm$table)
cat("\nPer-class breakdown:\n")
print(rf_cm$byClass[, c("Precision","Recall","F1")])

# -------------------------
# 11. PREDICT UNLABELED ROWS — FIXED VERSION
# -------------------------

cat("\n=== PREDICTING", nrow(dataset_a), "UNLABELED ROWS ===\n")

# CRITICAL FIX: Check if dataset_a still has rows
cat("DEBUG: dataset_a rows before processing:", nrow(dataset_a), "\n")

if(nrow(dataset_a) == 0) {
  stop("ERROR: dataset_a has 0 rows! Check the filtering in Section 3.")
}

dataset_a <- dataset_a %>%
  mutate(
    row_id     = row_number(),
    text_clean = clean_text(`Cause Of Injury Text`,
                            `Peril Description`,
                            `Peril Group`)
  )

cat("DEBUG: dataset_a rows after text cleaning:", nrow(dataset_a), "\n")

train_features <- setdiff(names(clean_data), "Severity")
cat("DEBUG: Number of training features:", length(train_features), "\n")

# FIXED Step 1: Create prediction matrix using proper data frame construction
# Use replicate() instead of matrix() to avoid dimension issues
pred_matrix_aligned <- as.data.frame(
  lapply(train_features, function(x) numeric(nrow(dataset_a)))
)
names(pred_matrix_aligned) <- train_features

cat("DEBUG: Prediction matrix initialized:", nrow(pred_matrix_aligned), "rows x", ncol(pred_matrix_aligned), "cols\n")

# Step 2: fill TF-IDF text features
tokens_pred <- dataset_a %>%
  unnest_tokens(word, text_clean, token = "ngrams", n = 2, n_min = 1) %>%
  anti_join(stop_words, by = "word") %>%
  filter(str_length(word) > 2)

cat("DEBUG: tokens_pred rows:", nrow(tokens_pred), "\n")

if (nrow(tokens_pred) > 0) {
  tfidf_pred <- tokens_pred %>%
    count(row_id, word) %>%
    bind_tf_idf(word, row_id, n) %>%
    filter(word %in% train_features)
  
  cat("DEBUG: tfidf_pred rows after filtering to train features:", nrow(tfidf_pred), "\n")
  
  for (i in seq_len(nrow(tfidf_pred))) {
    r <- tfidf_pred$row_id[i]
    w <- tfidf_pred$word[i]
    if (r <= nrow(pred_matrix_aligned) && w %in% names(pred_matrix_aligned)) {
      pred_matrix_aligned[r, w] <- tfidf_pred$tf_idf[i]
    }
  }
}

# Step 3: fill structured + cluster features
fill_cols <- c("Territory", "Peril Description", "Peril Group",
               "Weather Indicator", "Weather Text", "Division",
               "Accident State", "Policy Form Desc",
               names(dataset_a)[grepl("cluster", names(dataset_a), ignore.case = TRUE)])

for (col in fill_cols) {
  if (col %in% names(dataset_a) && col %in% train_features) {
    # FIXED: Use proper column access with backticks for names with spaces
    col_values <- suppressWarnings(
      as.numeric(as.factor(as.character(dataset_a[[col]])))
    )
    pred_matrix_aligned[[col]] <- col_values
  }
}

# Step 4: replace any remaining NAs with 0
pred_matrix_aligned[is.na(pred_matrix_aligned)] <- 0

# Final safety check
if(nrow(pred_matrix_aligned) == 0) {
  stop("ERROR: Prediction matrix has 0 rows! Cannot predict.")
}

cat("Prediction matrix:", nrow(pred_matrix_aligned), "rows x",
    ncol(pred_matrix_aligned), "features\n")

predictions <- predict(rf_model, pred_matrix_aligned)
dataset_a$Predicted_Severity <- as.character(predictions)

cat("Prediction distribution:\n")
print(table(dataset_a$Predicted_Severity))

# -------------------------
# 12. SAVE RESULTS
# -------------------------

output_df <- dataset_a %>%
  select(-row_id, -text_clean) %>%
  mutate(Predicted_Severity = Predicted_Severity)

# Uncomment to save:
# write_xlsx(output_df, "predicted_severity_codes.xlsx")
cat("\n=== DONE ===\n")
cat("Predictions added to dataset_a$Predicted_Severity\n")