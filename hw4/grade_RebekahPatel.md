*Rebekah Patel*

### Overall Grade: 255/270

### Late penalty

- Is the homework submitted (git tag time) before deadline? Take 10 pts off per day for late submission.  

### Quality of report: 10/10

### Completeness, correctness and efficiency of solution: 210/220

- Q1 (100/100)

  - Q1.5: All 9 lab items correct. `right_join` with `patients_tble` then `left_join` with `icustays_tble` for intime. `slice_max(storetime)`, `case_when` pivot, `pivot_wider`. `arrange(subject_id, stay_id)` present at end (line 133). No early collect.
  - Q1.6: All 5 vital items with proper column names matching ground truth. `left_join` by `stay_id`, `slice_min(storetime, with_ties = TRUE)`, `summarise(mean(...))`, `case_when` pivot, `pivot_wider`. `arrange(subject_id, stay_id)` present at end (line 172). No early collect.
  - Q1.7: `collect()` correctly placed at line 204. `arrange(subject_id, hadm_id, stay_id)` and `print(width = Inf)` present. Correct age computation (`age_intime = anchor_age + year(intime) - anchor_year`).
  - Q1.8: `fct_lump_n` with matching n values. Creative `fct_collapse` using `str_subset(unique(race), "ASIAN")` to dynamically detect subcategories with `other_level = "Other"`. `los_long = los >= 2` correct.

- Q2 (90/100)

  - **Folder structure**: Separate `app.R` in `mimiciv_shiny/`. No penalty.
  - **Tab 1 (Variable Exploration)**: Single dropdown covering labs, vitals, and demographics. Bar plots for categorical, boxplots for continuous. `tbl_summary` rendered via `gt_output`. Not organized into groups (no bonus).
  - **Tab 2 (Patient Exploration)**: Contains full HW3-style ADT timeline plot with all 3 layers: `geom_segment` for ADT (color = careunit, linewidth = ICU detection), `geom_point` for Lab (shape = "+"), `geom_point` for Procedure (shape = long_title). `scale_y_discrete(limits = rev)`. Diagnoses correctly sorted by `seq_num` (`slice_min(order_by = seq_num, n = 3)`). Patient ID via `selectizeInput` with server-side rendering.
  - (-10): No ICU vitals faceted plot.
  - **Error handling**: `req()`. Uses `!!as.numeric()` for BigQuery filter injection.

- Q3 (20/20)

  - Lists AI tools (Copilot, Gemini 3 Fast) and discusses use.
  - Provides 5 instances of AI errors with screenshots: missing `server = TRUE`, unnecessary SQL code, unwanted columns, non-working `limit` function, unnecessary `group_by`. Full credit.

### Usage of Git: 10/10

### Reproducibility: 5/10
  - (-5): Hardcoded path in `bq_auth()` (line 17: `"~/BIOSTAT203B/203b-hw/hw4/biostat-203b-2026-winter-92fefbfab477.json"`).
  
### R code style: 20/20

-   [Rule 2.6](https://style.tidyverse.org/syntax.html#long-function-calls) The maximum line length is 80 characters.  
    - No violations found.

-   Other rules: No violations found.
