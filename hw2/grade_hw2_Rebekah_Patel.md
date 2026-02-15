*Rebekah Patel*

### Overall Grade: 198/200

### Quality of report: 10/10

-   Is the homework submitted (git tag time) before deadline? Take 10 pts off per day for late submission.  

-   Is the final report in a human readable format (html, pdf)? 

-   Is the report prepared as a dynamic document (Quarto) for better reproducibility?

-   Is the report clear (whole sentences, typos, grammar)? Do readers have a clear idea what's going on and how results are produced by just reading the report? Take some points off if the solutions are too succinct to grasp, or there are too many typos/grammar. 

### Completeness, correctness and efficiency of solution: 150/150

- Q1 (20/20)
    - Q1.1 (10/10) Benchmarks all three functions with `system.time` and `pryr::object_size`. Correctly identifies `fread` as fastest. Reports memory for all three and compares data types.
    - Q1.2 (10/10) Uses `col_factor()` for categorical columns. Reports memory at 48.19 MB (< 50 MB).

- Q2 (80/80)

    - Q2.1 (10/10) Code provided (eval:false). Correctly reports exceeding 3 minutes and aborted. Good explanation of memory exhaustion.
    
    - Q2.2 (10/10) Code provided (eval:false). Correctly explains that column selection does not solve the issue since read_csv still reads the entire file.
    
    - Q2.3 (15/15) Correct bash command with all 9 lab item IDs including 50862. Extracts columns $2, $5, $7, $10. Reports 33,712,352 rows and read_csv timing.
    
    - Q2.4 (15/15) Correct Arrow approach with `open_dataset`. Correct item IDs. Uses `arrange(subject_id, charttime, itemid)`. Row count and head(, 10) displayed. Good Apache Arrow explanation.
    
    - Q2.5 (15/15) Full CSV correctly written to Parquet via `write_dataset`. Reports Parquet size (~2.6 GB). Correct filtering with `arrange()`. Row count and head(, 10) match Q2.4. Good Parquet explanation.
    
    - Q2.6 (15/15) Correct DuckDB approach with `to_duckdb`. Uses `arrange(subject_id, charttime, itemid)`. Row count and head(, 10) match Q2.4/Q2.5. Good DuckDB explanation.

- Q3 (30/30) Converts chartevents.csv.gz to Parquet, then uses DuckDB to filter. Correct vital sign item IDs (220045, 220181, 220179, 223761, 220210). Selects subject_id, itemid, charttime, valuenum. Uses `arrange()`. Row count and first 10 rows displayed. Well-documented steps.

- Q4 (20/20) Reports using GitHub Copilot and Claude Sonnet 4.5. Provides 5 instances of AI errors with screenshots.
	    
### Usage of Git: 10/10

-   Are branches (`main` and `develop`) correctly set up? Is the hw submission put into the `main` branch?

-   Are there enough commits (>=5) in develop branch? Are commit messages clear? The commits should span out not clustered the day before deadline. 
          
-   Is the hw2 submission tagged? 

-   Are the folders (`hw1`, `hw2`, ...) created correctly? 
  
-   Do not put auxiliary and big data files into version control. 

### Reproducibility: 10/10

-   Are the materials (files and instructions) submitted to the `main` branch sufficient for reproducing all the results? Just click the `Render` button will produce the final `html`? 

-   If necessary, are there clear instructions, either in report or in a separate file, how to reproduce the results?

### R code style: 18/20

-   [Rule 2.6] -2: R code line 220 exceeds 80 characters (89c: `filter(itemid %in% c(50862, 50912, 50971, 50983, 50902, 50882, 51221, 51301, 50931)) |>`).
