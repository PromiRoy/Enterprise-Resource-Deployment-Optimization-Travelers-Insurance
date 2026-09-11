# Random Generator for Claim Severity 2 and 3s

set.seed(123)

claims_data$Assignment <- sapply(claims_data$`CAT Severity Code`, function(severity) {
  
  if(is.na(severity)) return(NA)  # or assign a default
  
  if(severity == 1) return("Virtual")
  if(severity == 2) return(sample(c("Virtual","In-Person"), 1, prob = c(0.5,0.5)))
  if(severity == 3) return(sample(c("Virtual","In-Person"), 1, prob = c(0.25,0.75)))
  if(severity %in% c(4,5)) return("In-Person")
  
})


# check to make sure it works
prop.table(
  table(claims_data$`CAT Severity Code`, claims_data$Assignment),
  1
)
