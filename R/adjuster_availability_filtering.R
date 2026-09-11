# Adjuster Filtering

library(dplyr)

# checking to see if all adjusters have a CL level <= PL Level
all(adjuster_data$`PL Skill Level` >= adjuster_data$`CL Skill Level`, na.rm = TRUE)

adjuster_data %>%
  filter(`CL Skill Level` > `PL Skill Level`) %>%
  select(`CL Skill Level`, `PL Skill Level`)

sum(adjuster_data$`CL Skill Level` > adjuster_data$`PL Skill Level`, na.rm = TRUE)

# NA values
sum(is.na(adjuster_data$`CL Skill Level`))
sum(is.na(adjuster_data$`PL Skill Level`))

# FILTERING 

# ============================================================
# ADJUSTER ELIGIBILITY FILTERING LOGIC
# ============================================================
# This script:
# 1️⃣ Generates a minimum Required Skill Level from CAT Severity
# 2️⃣ Filters adjusters to Available + Non-Trainees
# 3️⃣ Counts how many adjusters meet minimum skill requirements
# 4️⃣ Uses Division-specific skill logic:
#       - BI → CL Skill Level
#       - PI → PL Skill Level
# 5️⃣ Required Skill Level acts as a MINIMUM (>= logic)
# ============================================================

library(dplyr)

# ============================================================
# 1️⃣ Generate Required Skill Level (Minimum Required)
# ============================================================
# Maps CAT Severity Code to the minimum skill level required.
# Higher severity = higher minimum skill requirement.
# If severity is missing, Required Skill remains NA.

claims_data <- claims_data %>%
  mutate(
    `Required Skill Level` = case_when(
      `CAT Severity Code` == 5 ~ 4,  # Most severe → minimum skill 4
      `CAT Severity Code` == 4 ~ 3,
      `CAT Severity Code` == 3 ~ 2,
      `CAT Severity Code` %in% c(1,2) ~ 1,  # Low severity → minimum skill 1
      TRUE ~ NA_real_  # Leave NA if severity missing
    )
  )

# ============================================================
# 2️⃣ Filter Adjuster Pool
# ============================================================
# Keeps only:
# ✔ Adjusters currently Available
# ✔ Adjusters who are not trainees
#     (Trainees assumed to have skill level 0 in both CL and PL)
#
# coalesce() converts NA skills to 0 so they do not incorrectly pass the filter.

adjuster_pool <- adjuster_data %>%
  filter(
    `Current Status` == "Available",  # Must be available
    coalesce(`CL Skill Level`, 0) > 0 | 
      coalesce(`PL Skill Level`, 0) > 0  # Must have at least one non-zero skill
  )

# ============================================================
# 3️⃣ Count Eligible Adjusters Per Claim
# ============================================================
# For each claim:
# - Look at its Division (BI or PI)
# - Use the appropriate skill column
# - Count adjusters whose skill >= Required Skill Level
#
# IMPORTANT:
# Required Skill Level is a MINIMUM threshold.
# Example:
#   If Required Skill = 2
#   Then adjusters with skill 2, 3, 4, 5 all qualify.

claims_data <- claims_data %>%
  rowwise() %>%   # Evaluates each claim individually
  mutate(
    Num_Eligible = case_when(
      
      # BI Claims → use CL Skill Level
      Division == "BI" ~
        sum(
          adjuster_pool$`CL Skill Level` >= `Required Skill Level`,
          na.rm = TRUE
        ),
      
      # PI Claims → use PL Skill Level
      Division == "PI" ~
        sum(
          adjuster_pool$`PL Skill Level` >= `Required Skill Level`,
          na.rm = TRUE
        ),
      
      # If Division missing or unrecognized → no eligible adjusters
      TRUE ~ 0
    )
  ) %>%
  ungroup()  # Return to normal dataframe behavior

# ============================================================
# OUTPUT
# ============================================================
# claims_data now contains:
#   Required Skill Level  → minimum skill needed per claim
#   Num_Eligible          → number of available, non-trainee
#                           adjusters meeting minimum skill
#
# No constraints included for:
#   - Travel
#   - Resource Type
#
# Eligibility is now purely:
#   Available + Non-Trainee + Skill >= Minimum Required
# ============================================================

