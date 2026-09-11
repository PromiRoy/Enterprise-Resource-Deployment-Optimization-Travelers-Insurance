# CAT Surge Claim Allocation

Mixed-integer optimization system for assigning catastrophe (CAT) claims to
field adjusters during a surge event. Built as a five-person applied analytics
capstone (DS7900, Kennesaw State University) with **Travelers Insurance**.

**Results on a 1,053-claim historical event window:** 98.6% of claims completed
within SLA · 2.85 travel hours and 109 miles per claim · 124 of 774 adjusters
deployed · ~6-minute solve.

📄 [Full report (PDF)](reports/Travelers_CAT_Resource_Deployment_Report.pdf)

## Problem

When a catastrophe hits, thousands of property claims arrive within days and a
limited pool of adjusters — with different skills, locations, and availability —
must be deployed to inspect them. Assigning claims by hand is slow and leaves
SLA deadlines and travel time on the table. The client asked for a repeatable,
data-driven deployment plan.

## Approach

```
claim narratives ──► severity imputation (LinearSVR) ─┐
                                                       ├─► on-site / virtual routing
adjuster roster  ──► availability & skill filtering ──┘
                                                          │
                     K-Means clustering of claims (K=19) ◄┘
                                                          │
                     OSRM drive-time matrix (claims × adjusters)
                                                          │
                     Gurobi MIP: assign claims to adjusters s.t. capacity,
                     skills, SLA windows; minimize travel + lateness
                                                          │
                     assignments, deployments, diagnostics, dashboard
```

## Repository layout

```
notebooks/            pipeline, in order
  01_adjuster_clean.ipynb
  02_severity_classification.ipynb
  03_productivity_matrix.ipynb
  04_claim_clean.ipynb
  05_clustering.ipynb
  06_time_matrix_osrm.ipynb
  07_gurobi_assignment_model.ipynb
  08_metrics_and_figures.ipynb
  exploratory/        supporting analyses (maps, data dictionary, filters)
R/                    staffing-adequacy, SVM severity model, validation scripts
data/raw/             client-provided inputs (sanitized "for_distribution" copies)
data/processed/       cleaned tables, clusters, travel matrices
outputs/              assignments, deployments, diagnostics, figures
reports/              final client report
archive/              scratch notebooks kept for reference
```

## How to run

1. Python ≥ 3.10 with `pandas`, `scikit-learn`, `geopandas`, `folium`,
   `gurobipy` (a Gurobi license is required for `07_…`); R with `readxl`, `e1071`.
2. An OSRM endpoint for `06_time_matrix_osrm.ipynb` (the public demo server
   works for small batches).
3. Open the notebooks from the `notebooks/` folder and run them in numeric
   order. File paths are relative to each notebook's own folder
   (`../data/raw/…`, `../outputs/…`), which is Jupyter's default working
   directory. R scripts likewise expect to be run from `R/`.

## Data

Inputs are the sanitized datasets Travelers supplied for the capstone
(`*_for_distribution*`). No personally identifiable information is included.

## Team

Five-person DS7900 capstone team, Spring 2026.
My contributions: **[fill in — e.g., claim/adjuster cleaning, clustering and
OSRM travel matrix, the Gurobi assignment model, the results report]**.

## License

Code is released under the [MIT License](LICENSE). Client-provided data is
shared under the terms of the capstone agreement and may not be redistributed
outside this repository.
