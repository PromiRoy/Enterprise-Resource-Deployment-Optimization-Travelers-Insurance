library(readxl)
library(ggplot2)


roster <- read_excel("../data/raw/CatRosterReportDayOf_for_distribution_cleaned.xlsx", sheet = 1)
claims <- read_excel("../data/raw/ClaimDetails_for_distribution.xlsx", sheet = 1)

# -----------------------------
# 1) Helpers: clean/extract city
# -----------------------------
normalize_city <- function(x) {
  x <- toupper(trimws(as.character(x)))
  x <- gsub("\\.", "", x)                 # remove dots
  x <- gsub("[,]", "", x)                 # remove commas
  x <- gsub("\\s+", " ", x)               # collapse spaces
  x
}

# Extract city from roster Location:
# "Boston-Financial Center" -> "BOSTON"
# "Albany - Park Pl"        -> "ALBANY"
extract_city_from_location <- function(loc) {
  loc <- toupper(trimws(as.character(loc)))
  loc <- gsub("\\s*-\\s*", "-", loc)      # normalize " - " to "-"
  city <- sub("-.*$", "", loc)            # take before first "-"
  city <- normalize_city(city)
  city
}

# -----------------------------
# 2) Create clean city columns
# -----------------------------
roster$city <- extract_city_from_location(roster$Location)

claims$city  <- normalize_city(claims$`Accident City`)
claims$state <- trimws(as.character(claims$`Accident State`))

# Drop empty city/state rows in claims
claims_ok <- claims[!is.na(claims$city) & claims$city != "" &
                      !is.na(claims$state) & claims$state != "", ]

# -----------------------------
# 3) Build City -> State mapping FROM CLAIMS ONLY
#    If a city appears in multiple states, choose the most frequent one.
# -----------------------------
city_state_counts <- as.data.frame(table(claims_ok$city, claims_ok$state), stringsAsFactors = FALSE)
names(city_state_counts) <- c("city", "state", "n")
city_state_counts <- city_state_counts[city_state_counts$n > 0, ]

# Pick the state with max count per city
city_to_state <- do.call(rbind, lapply(split(city_state_counts, city_state_counts$city), function(df) {
  df <- df[order(-df$n), ]
  df[1, c("city", "state", "n")]
}))
row.names(city_to_state) <- NULL

# -----------------------------
# 4) Join roster with claims-derived mapping
# -----------------------------
roster2 <- merge(roster, city_to_state[, c("city", "state")], by = "city", all.x = TRUE)

# -----------------------------
# 5) Availability (supply flag)
#     Your data: mostly NA, and only "Available to Deploy" is explicit.
# -----------------------------
roster2$is_available <- roster2$Availability == "Available to Deploy"

# -----------------------------
# 6) Diagnostics: how good is the city match?
# -----------------------------
cat("=== DIAGNOSTICS ===\n")
cat("Roster rows:", nrow(roster2), "\n")
cat("Roster unique cities:", length(unique(roster2$city)), "\n")
cat("Claims unique cities:", length(unique(claims_ok$city)), "\n\n")

cat("Roster rows with mapped state:", sum(!is.na(roster2$state)), "\n")
cat("Roster rows unmapped (no state):", sum(is.na(roster2$state)), "\n\n")

cat("Available to Deploy (total in roster):", sum(roster2$is_available, na.rm = TRUE), "\n")
cat("Available to Deploy AND mapped to state:", sum(roster2$is_available & !is.na(roster2$state), na.rm = TRUE), "\n\n")

# List top unmapped roster cities (so you can see what doesn't match claims cities)
unmapped_cities <- sort(unique(roster2$city[is.na(roster2$state)]))
cat("Top 25 unmapped roster cities:\n")
print(head(unmapped_cities, 25))
cat("\n")

# -----------------------------
# 7) DEMAND: claims per state
# -----------------------------
demand_by_state <- aggregate(rep(1, nrow(claims_ok)) ~ state, data = claims_ok, FUN = sum)
names(demand_by_state) <- c("state", "claims_demand")

# -----------------------------
# 8A) SUPPLY (Strict): available staff per state (mapped only)
# -----------------------------
roster_mapped <- roster2[!is.na(roster2$state), ]

supply_by_state_available <- aggregate(is_available ~ state, data = roster_mapped,
                                       FUN = function(x) sum(x, na.rm = TRUE))
names(supply_by_state_available) <- c("state", "available_staff")

gap_available <- merge(demand_by_state, supply_by_state_available, by = "state", all = TRUE)
gap_available$claims_demand[is.na(gap_available$claims_demand)] <- 0
gap_available$available_staff[is.na(gap_available$available_staff)] <- 0
gap_available$claims_per_staff <- ifelse(gap_available$available_staff == 0, Inf,
                                         gap_available$claims_demand / gap_available$available_staff)

gap_available$status <- cut(gap_available$claims_per_staff,
                            breaks = c(-Inf, 5, 10, Inf),
                            labels = c("Green", "Yellow", "Red"))

gap_available <- gap_available[order(-gap_available$claims_per_staff), ]

cat("=== GAP TABLE (STRICT: Available to Deploy only) ===\n")
print(head(gap_available, 15))
cat("\n")

cat("=== SHORTAGE ALERTS (STRICT: Red states) ===\n")
print(gap_available[gap_available$status == "Red", ])
cat("\n")

# -----------------------------
# 8B) SUPPLY (Potential): total staff per state (mapped only)
# -----------------------------
supply_by_state_total <- aggregate(rep(1, nrow(roster_mapped)) ~ state, data = roster_mapped, FUN = sum)
names(supply_by_state_total) <- c("state", "total_staff_mapped")

gap_total <- merge(demand_by_state, supply_by_state_total, by = "state", all = TRUE)
gap_total$claims_demand[is.na(gap_total$claims_demand)] <- 0
gap_total$total_staff_mapped[is.na(gap_total$total_staff_mapped)] <- 0
gap_total$claims_per_staff <- ifelse(gap_total$total_staff_mapped == 0, Inf,
                                     gap_total$claims_demand / gap_total$total_staff_mapped)

gap_total$status <- cut(gap_total$claims_per_staff,
                        breaks = c(-Inf, 5, 10, Inf),
                        labels = c("Green", "Yellow", "Red"))

gap_total <- gap_total[order(-gap_total$claims_per_staff), ]

cat("=== GAP TABLE (POTENTIAL: Total staff mapped) ===\n")
print(head(gap_total, 15))
cat("\n")

cat("=== SHORTAGE ALERTS (POTENTIAL: Red states) ===\n")
print(gap_total[gap_total$status == "Red", ])
cat("\n")

# -----------------------------
# 9) Heatmap (choose which gap table you want to visualize)
#     Use gap_available (strict) or gap_total (potential)
# -----------------------------
plot_gap <- gap_total   # <- change to gap_available if you want strict

# Force correct order of legend + colors
plot_gap$status <- factor(plot_gap$status, levels = c("Green", "Yellow", "Red"))

ggplot(plot_gap, aes(x = 1, y = reorder(state, -claims_per_staff), fill = status)) +
  geom_tile() +
  labs(title = "Staffing Adequacy (Claims per Staff) - City matched from Claims",
       x = "", y = "State") +
  scale_fill_manual(
    values = c("Green" = "green", "Yellow" = "yellow", "Red" = "red"),
    drop = FALSE
  ) +
  theme_minimal() +
  theme(
    axis.text.x = element_blank(),
    axis.ticks.x = element_blank()
  )
