library(tidyverse)
library(data.table)
library(comorbidity)
library(dplyr)

diagnoses_patients <-
  fread("~/BIOSTAT203B/mimic-iv-3.1/hosp/diagnoses_icd.csv.gz") %>%
  as_tibble

codes_dict <-
  fread("~/BIOSTAT203B/mimic-iv-3.1/hosp/d_icd_diagnoses.csv.gz") %>%
  as_tibble()

all_trauma_patients <- diagnoses_patients %>%
  left_join(
    codes_dict,
    by = c("icd_code", "icd_version")
  ) %>%
  filter(
    # ICD-10 Logic: Must be version 10 AND within the S00-T88 range
    (icd_version == 10 & icd_code >= "S00" & icd_code <= "T88") | 
      
      # ICD-9 Logic: Must be version 9 AND (Numeric range OR E-code range)
      (icd_version == 9 & (
        (icd_code >= "800" & icd_code <= "959") | 
          (icd_code >= "E800" & icd_code <= "E999")
      ))
  )

admissions <- fread("~/BIOSTAT203B/mimic-iv-3.1/hosp/admissions.csv.gz") %>%
  mutate(
    admittime = as.POSIXct(admittime),
    dischtime = as.POSIXct(dischtime)
  )

admissions <- admissions %>%
  group_by(subject_id) %>%
  arrange(admittime, .groups = TRUE) %>%
  mutate(
    stay_seq = row_number(),
    days_between_stays = as.numeric(difftime(admittime, lag(dischtime), units = "days"))
    ) %>%
  as_tibble()

transfers <- fread("~/BIOSTAT203B/mimic-iv-3.1/hosp/transfers.csv.gz") %>%
  arrange(subject_id, hadm_id, intime) %>%
  as_tibble()

# list of all transfers of patients who go from ed to icu per stay
first_icu <- transfers %>%
  filter(eventtype == "admit", grepl("CU", careunit)) %>%
  group_by(subject_id, hadm_id) %>%
  slice_min(intime, with_ties = FALSE) %>%
  ungroup() %>%
  select(subject_id, transfer_id, hadm_id, intime, outtime) %>%
  mutate(is_first_icu = TRUE)

first_icu_transfer <- first_icu %>%
  select(transfer_id, is_first_icu)

# find all rows where we get patient going from ed to icu
ed_to_icu <- transfers %>%
  group_by(subject_id, hadm_id) %>%
  arrange(intime, .by_group = TRUE) %>%
  left_join(first_icu_transfer, by = "transfer_id") %>%
  filter(
    (is_first_icu & lag(careunit) == "Emergency Department") |
    (careunit == "Emergency Department" & lead(is_first_icu))
  ) %>%
  ungroup()

ed_to_icu %>%
  group_by(subject_id) %>%
  count()
# 35, 540 patients that have gone from ED to ICU (at any point)

ed_to_icu %>%
  group_by(careunit) %>%
  count()

icu_trauma_patients <- 
  ed_to_icu %>%
  inner_join(
    all_trauma_patients,
    by = c("subject_id", "hadm_id")
  ) %>%
  arrange(subject_id, hadm_id, intime)

icu_trauma_patients %>%
  group_by(subject_id) %>%
  count()
# 14,915 trauma patients that have gone from ED to ICU
# 14,807 trauma patients that go from ED to ICU at first admit per hadm_id

#typically, outtime of ED = intime of ICU
waittime <- icu_trauma_patients %>%
  group_by(subject_id, hadm_id) %>%
  mutate(
    hour = hour(outtime - intime)
  ) %>%
  filter(careunit == "Emergency Department") %>%
  print(width = Inf)

############################################################################
# look through d_labitems
labitems <- fread("~/BIOSTAT203B/mimic-iv-3.1/hosp/d_labitems.csv.gz") %>%
  as_tibble()

hpc <- fread("~/BIOSTAT203B/mimic-iv-3.1/hosp/hcpcsevents.csv.gz") %>%
  as_tibble()

table <- hpc %>%
  group_by(short_description) %>%
  count()

#############################################################################
# look through ed
triage <- fread("~/BIOSTAT203B/mimic-iv-3.1/ed/triage.csv.gz") %>%
  as_tibble()

ed_vitals <- fread("~/BIOSTAT203B/mimic-iv-3.1/ed/vitalsign.csv.gz") %>%
  as_tibble()

ed_diagnoses <- fread("~/BIOSTAT203B/mimic-iv-3.1/ed/diagnosis.csv.gz") %>%
  as_tibble()

#############################################################################

#all patients with hadm_id by admittime, dischtime and icd codes
icd_visits <- diagnoses_patients %>%
  inner_join(
    select(admissions, subject_id, hadm_id, stay_seq, admittime, dischtime, days_between_stays),
    by = c("subject_id", "hadm_id") 
    )

map9 <- comorbidity(x = filter(icd_visits, icd_version == 9),
                    id = "hadm_id", code = "icd_code",
                    map = "charlson_icd9_quan", assign0 = TRUE)

map10 <- comorbidity(x = filter(icd_visits, icd_version == 10),
                    id = "hadm_id", code = "icd_code",
                    map = "charlson_icd10_quan", assign0 = TRUE)

all_maps <- bind_rows(map9, map10) %>%
  group_by(hadm_id) %>%
  summarise(across(mi:aids, max)) %>%
  left_join(
    unique(select(icd_visits, subject_id, hadm_id, stay_seq)),
    by = "hadm_id"
  )

final_cci <- all_maps %>%
  group_by(subject_id) %>%
  arrange(stay_seq) %>%
  mutate(across(mi:aids, ~ cumany(.x == 1))) %>%
  ungroup()

class(final_cci) <- c("comorbidity", class(final_cci))
attr(final_cci, "map") <- "charlson_icd10_quan"

final_cci$charlson_score <- score( 
  final_cci, weights = "quan", assign0 = TRUE
)

charlson <- final_cci %>%
  select(subject_id, hadm_id, stay_seq, charlson_score) %>%
  right_join(
    first_icu,
    by = c("subject_id", "hadm_id")
  )
  


####################################################################
test <- ed_to_icu_basecase %>%
  filter(!is.na(stay_id))

comparison <- 
  test %>%
  left_join(
    ed_to_icu, 
    by = c("subject_id", "hadm_id")
  ) %>%
  filter(is.na(transfer_id))

looking <-
  transfers %>%
  inner_join(
    comparison,
    by = c("subject_id", "hadm_id")
  )



unique(transfers$careunit)







