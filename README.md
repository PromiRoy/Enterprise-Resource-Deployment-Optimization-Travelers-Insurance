# CAT Surge Claim Allocation

Mixed-integer optimization system for assigning catastrophe claims
to adjusters during a surge event. Built as a five-person applied
analytics capstone (DS7900) with Travelers Insurance.

**Results on a 1,053-claim historical event window:** 98.6% completed
within SLA, 2.85 travel hours and 109 miles per claim, 124 of 774
adjusters deployed, ~6 minute solve.

**Pipeline:** severity imputation (LinearSVR on claim narratives) →
on-site/virtual routing → K-Means clustering (K=19) → OSRM travel
matrix → Gurobi MIP → dashboard.

[Full report (PDF)](Travelers_CAT_Resource_Deployment_Report.pdf)

**Data note:** original claim and adjuster data provided by the
sponsor for the capstone and not distributed. A synthetic generator
with the same schema is included so the pipeline runs end to end.
