# notes and EDA findings on dataset

library(dplyr)


#-----------------------------
#      DATA DICTIONARY
#----------------------------
class(Data_Set_decode_table_updated)
names(Data_Set_decode_table_updated)

colnames(Data_Set_decode_table_updated)
summary(Data_Set_decode_table_updated)

#Claims variables listed as important!
# CAT Severity Code
# Peril Description
# Cause of Injury Text (extract common terms)
# Peril Group
# Weather Text
# Policy Form Desc (extract common terms)
# Cluster columns (explore with to see if they help)


table(ClaimDetails_for_distribution$`Peril Description`)
table(ClaimDetails_for_distribution$`Peril Group`)


# Variables listed as important for adjustors roster
# Department (extract common terms from titles)
# HR Job Title (extract common terms from titles)
# Deployed Role
# WFM Resource Type Desc
# Wrk Cell Nbr Employee (extract common terms)
# CL Skill Level
# PL Skill Level
# Evnt Name (extract common terms)
# CAT Center Name (make geographical areas?)
# Qtr Rank Id 


#---------
#ADJUSTERS
#---------

# 774 Obs, 85 variables

colnames(CatRosterReportDayOf_for_distribution_cleaned)
summary(CatRosterReportDayOf_for_distribution_cleaned)


adjuster_data <- CatRosterReportDayOf_for_distribution_cleaned

#availability column lacks any substantial info - can just get rid of it
# what are the Primary Ofc Cd, Employee LOB Cd variables?
# last 16 variables are 1s and 0s.  binary?, the last few seem to be all 0s 
# so may not be necessary to include or look in to

table(CatRosterReportDayOf_for_distribution_cleaned$Location)

#see the number of NAs per column
colSums(is.na(adjuster_data))

# Org Group - 30 - can maybe use location and department to fill these in
# ERT Champion Ind - 23 - not too sure abt this variable
# ERT Champion - 512
# WFM Tour Supervisor Name - 211
# Preferred Role - 131
# Availability - 765 (essentially all obs are blank)
# Deployed Role - 211
# Evnt Name - 211
# Instruct Date - 211
# Deploy Notify Date - 208
# Tour Start Date - 211 ( wonder if all the ones with 211 NAs are for the same rows)
# Tour End Date - 211
#  Primary Ofc Cd  - 83
# Employee LOB Cd - 13
# CAT Cd - 508
# TRAVCAT Ext - 623
# CAT Center Name - 363
# Worksite Name - 211
# Will Travel - 20
 # Total Missing Values = 4756 of 65790 cells

# only focusing on important variables for now

# TIES ID
#Individual adjuster ID

# Org Group
table(adjuster_data$`Org Group`)

org_dept <- adjuster_data %>%
  count(`Org Group`, `Department`)

org_dept

# Department
table(adjuster_data$Department)
# questions to consider -> what makes a department, how are adjusters placed in a department
# filtering to look at just department 10 we see 2 with location orlando but the third is charlotte
# notes on potential use say to extract common terms from titles -> possibly the job title may place someone
# into a certain department (doesn't seem the case when filtering by the first HR Job title)


# Location
table(adjuster_data$Location)

location_org <- adjuster_data %>%
  count(`Org Group`, Location)

loc_dept <- adjuster_data %>%
  count(`Department`, Location)
# doesnt seem that location has an impact on the org group or department of an adjuster

# HR Job Title
table(adjuster_data$`HR Job Title`)
# why so many job titles if these are all supposed to be adjusters??

# ERT Champion Ind
table(adjuster_data$`ERT Champion Ind`) 
# N for 751 of 774 obs, may just be N for all, what is N?

# ERT Champion
table(adjuster_data$`ERT Champion`)

ert_loc <- adjuster_data %>%
  count(`ERT Champion`, Location)
# doesn't seem location dependent

# Preferred Role
table(adjuster_data$`Preferred Role`)

pref_hr <- adjuster_data %>%
  count(`Preferred Role`, `HR Job Title`)

# what is FNOL, maybe the Prefered is of better use if needed

# Deployed Role
table(adjuster_data$`Deployed Role`)

pref_dep <- adjuster_data %>%
  count(`Preferred Role`, `Deployed Role`)

# May need to coincide the HR, Pref, and Deployed job titles

# WFM Resource Type Desc
table(adjuster_data$`WFM Resource Type Desc`)

# Preferred Tour Length
table(adjuster_data$`Preferred Tour Length`)

# Cl Skill Level - Business Claim Level
table(adjuster_data$`CL Skill Level`)

# PL Skill Level
table(adjuster_data$`PL Skill Level`)

cl_pl <- adjuster_data %>%
  count(`CL Skill Level`, `PL Skill Level`)


# removing unnecessary columns
#adjuster_data <- CatRosterReportDayOf_for_distribution_cleaned %
#select(-


#------
#CLAIMS 
#------

colnames(ClaimDetails_for_distribution)
summary(ClaimDetails_for_distribution)


# 1065 obs with 29 variables
# there are 274 NAs for CAT Severity Code
# all obs in the Weather column are listed as Weather, therefore, not a necessary variable
# CAT Code is 82 for all obs - not needed
# Weather Indicator is 'Yes' for all obs - not needed
# Loss type is P for all obs - not needed

table(ClaimDetails_for_distribution$`Accident City`)
table(ClaimDetails_for_distribution$`Accident State`)
table(ClaimDetails_for_distribution$`Accident Zip`)

table(ClaimDetails_for_distribution$Division)


# removing unnecessary columns -
# each of these have the same entry for all obs,
# so we don't need them in the dataset
claims_data <- ClaimDetails_for_distribution %>%
  select(-Weather, -`CAT Code`, -`Weather Indicator`, -`Loss Type`, -`Claimant Number`)

#see the number of NAs per column
colSums(is.na(claims_data))
# 3 for Territory (obs 146, 769, and 1063)
#   we have the Accident City for each of these, so we could match Territory
#   with the city - fixed all 3 in the excel file

# 274 for CAT Severity Code - majority fixed with code below with predicted values (60 remain)
# 3 for Accident Zip 
#   1 is for Tuscaloosa, AL (the only entry with that city)
#   2nd is Madison, TN (all other Madison TN have the same zip so we can just manually enter that in)
#   3rd is Hendersonville, TN (the wedding obs) - all Hendersonvill (and Hendersonville) cities have
#    the same zip, so can also just manually enter in the zip code (check excel file)
# 10 for Policy Form Desc - not sure how to adress this one yet

# but after assessing for missing values (started with 290) - now only 71 missing values/cells
# in the entire dataset

#looking into each variable:

# Territory
table(claims_data$Territory)

# Claim Number
# checking for duplicates
sum(duplicated(claims_data$`Claim Number`)) # = 0 :)
# is there any meaning or sequence to determine the claim number 
# i don't think so, it looks completely random

# CAT Severity Code
table(claims_data$`CAT Severity Code`)
hist(claims_data$`CAT Severity Code`)
# Two way contingency table with CAT Severity Code and Peril Description
severity_table <- claims_data %>%
  count(`CAT Severity Code`, `Peril Description`)

# the description goes beyond CAT levels, meaning "hail" for example,
# as with many others, can be any of the levels
# thus to fill in the empty observations we would need to look into the longer 
# descriptions of the event in order to match the NAs with an actual value

severity_table2 <- claims_data %>%
  count(`CAT Severity Code`, `Peril Group`)
# similar sitch, no commonality between type of weather and CAT Code

severity_table3 <- claims_data %>%
  count(`CAT Severity Code`, `Division`)
# No BI (businesses) labeled with a 1 CAT code


## next step would be to compare the CAT code levels with key words from the Cause of Injury Text
# text-mining and classification

# split data -> 
# training set -> severity code is present
# prediction set -> severity code is blank
train_df <- claims_data %>%
  filter(!is.na(`CAT Severity Code`) & `CAT Severity Code` !="")

predict_df <- claims_data%>%
  filter(is.na(`CAT Severity Code`) | `CAT Severity Code` == "")


# clean text in `Cause of Injury Text`
# lowercase, remove punctuation, remove stop words

install.packages("tidytext")
library(tidytext)
library(stringr)
library(tidyr)

clean_text <- function(text) {
  text %>%
    str_to_lower() %>%
    str_replace_all("[^a-z\\s]", " ") %>%
    str_squish()
}

train_df <- train_df %>%
  mutate(clean_text = clean_text(`Cause Of Injury Text`))

predict_df <- predict_df %>%
  mutate(clean_text = clean_text(`Cause Of Injury Text`))

# extract common phrases
# unigrams (single words), bigrams, trigrams
common_phrases <- train_df %>%
  unnest_tokens(bigram, clean_text, token = "ngrams", n=2)

# removing stop words
data("stop_words")

common_phrases <- common_phrases %>%
  separate(bigram, c("word1", "word2"), sep = " ") %>%
  filter(
    !word1 %in% stop_words$word,
    !word2 %in% stop_words$word
  ) %>%
  unite(bigram, word1, word2, sep = " ")

# identify phrase patterns by severity (what phrases most often appear in each of the CAT Codes)
severity_phrases <- common_phrases %>%
  count(`CAT Severity Code`, bigram, sort = TRUE)

severity_phrases %>%
  group_by(`CAT Severity Code`) %>%
  slice_max(n, n=10)

# build phrase lookup dictionary
phrase_lookup <- severity_phrases %>%
  group_by(`CAT Severity Code`) %>%
  slice_max(n, n=20) %>%
  ungroup()


# PREDICT MISSING CAT SEVERITY CODES
assign_severity <- function(text, lookup) {
  
  text <- as.character(text)
  
  matches <- lookup %>%
    filter(str_detect(text, bigram))
  
  if (nrow(matches) == 0) return(NA_character_)
  
  top <- matches %>%
    count(`CAT Severity Code`, wt = n) %>%
    slice_max(n, n=1) %>%
    pull(`CAT Severity Code`)
  
  return(as.character(top[1]))
}

predict_df$predicted_CAT_severity <- 
  vapply(
    predict_df$clean_text,
    assign_severity,
    FUN.VALUE = character(1),
    lookup = phrase_lookup
)

final_df <- bind_rows(
  train_df %>% mutate(predicted_CAT_severity = as.character(`CAT Severity Code`)),
  predict_df
)


# get distribution on new CAT codes

table(final_df$predicted_CAT_severity)
# still have NA for 60 values but getting there

# Loss Date
table(final_df$`Loss Date`)

# NOL Date
table(final_df$`NOL Date`)

# could maybe look into the amount of days from Loss to NOL date and
# see if that matches the SLA values given the CAT Severity Code

# Peril Description
table(final_df$`Peril Description`)

# Cause of Injury Text
# extracted common phrases above in order to predict CAT Severity code for NA values

# Weather Indicator
# Yes for all obs

# Weather Text
table(final_df$`Weather Text`)

severity_table4 <- final_df %>%
  count(`CAT Severity Code`, `Weather Text`)
# doesn't seem to have much of a pattern

# Division
table(final_df$Division)

cat_division <- final_df %>%
  count(`predicted_CAT_severity`, `Division`)

cat_division


# Accident City
table(final_df$`Accident City`)


# Accident State
table(final_df$`Accident State`)

cat_state <- final_df %>%
  count(`predicted_CAT_severity`, `Accident State`)

cat_state

# Accident Zip
table(final_df$`Accident Zip`)

# Policy Form Desc
table(final_df$`Policy Form Desc`)
# highest frequencies are condo home owners 
# and landlord dwelling 

# Clusters
table(final_df$`6_cluster_cluster_id`)











