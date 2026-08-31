# Install packages (run once if not installed)
install.packages("tidyverse")
install.packages("readxl")
install.packages("writexl")

# Load libraries
library(tidyverse)
library(readxl)
library(writexl)

# Read the Excel file
df <- read_excel("ClaimDetails_for_distribution.xlsx")



df <- ClaimDetails_for_distribution_1_
# Split "Cause Of Injury Text" into word columns and add to original dataset
word_cols <- df %>%
  mutate(row_id = row_number()) %>%
  select(row_id, `Cause Of Injury Text`) %>%
  separate(`Cause Of Injury Text`,
           into = paste0("word_", 1:50),
           sep = " ",
           fill = "right",
           extra = "drop")
head(df) 

# Add the word columns back to the original dataset
df_final <- bind_cols(df, word_cols %>% select(-row_id))

# Replace NA with blank only in word columns
df_final[is.na(df_final)] <- ""