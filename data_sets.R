library(readxl)

#CatRosterReportDayOf_for_distribution_cleaned <- read_excel("ds7900_spring26_travelers/CatRosterReportDayOf_for_distribution_cleaned.xlsx")
#View(CatRosterReportDayOf_for_distribution_cleaned)

cat_events <- CatRosterReportDayOf_for_distribution_cleaned 

#ClaimDetails_for_distribution <- read_excel("ds7900_spring26_travelers/ClaimDetails_for_distribution.xlsx")
#View(ClaimDetails_for_distribution)

cat_claims_details <- ClaimDetails_for_distribution


#Data_Set_decode_table_updated <- read_excel("ds7900_spring26_travelers/Data_Set_decode_table_updated.xlsx")
#View(Data_Set_decode_table_updated)
#cat_decodetable <- Data_Set_decode_table_updated

claim_table <-cat_decodetable

#Data_Set_decode_table_updated <- read_excel("ds7900_spring26_travelers/Data_Set_decode_table_updated.xlsx", 
#                                            sheet = "Cat Roster Table")
#View(Data_Set_decode_table_updated)

cat_roster_table <- Data_Set_decode_table_updated 




