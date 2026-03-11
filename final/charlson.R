library(tidyverse)
library(data.table)
library(comorbidity)
library(dplyr)

# all admissions of patients
admissions <- fread("~/BIOSTAT203B/mimic-iv-3.1/hosp/admissions.csv.gz") %>%
  mutate(
    admittime = as.POSIXct(admittime),
    dischtime = as.POSIXct(dischtime)
  )

# finds all icd codes per stay
diagnoses_patients <-
  fread("~/BIOSTAT203B/mimic-iv-3.1/hosp/diagnoses_icd.csv.gz") %>%
  as_tibble

# ordering the stays per patient in order
admissions <- admissions %>%
  group_by(subject_id) %>%
  arrange(admittime, .groups = TRUE) %>%
  mutate(
    stay_seq = row_number(),
    days_between_stays = as.numeric(difftime(admittime, lag(dischtime), units = "days"))
  ) %>%
  as_tibble()

# all transfers of patients from one dept to another
transfers <- fread("~/BIOSTAT203B/mimic-iv-3.1/hosp/transfers.csv.gz") |>
  as_tibble()

# find all first admits per stay that are to an icu dept
first_icu <- transfers %>%
  filter(eventtype == "admit", grepl("ICU", careunit)) %>%
  group_by(subject_id, hadm_id) %>%
  slice_min(intime, with_ties = FALSE) %>%
  ungroup() %>%
  select(subject_id, transfer_id, hadm_id, intime, outtime) %>%
  mutate(is_first_icu = TRUE)

first_icu_transfer <- first_icu %>%
  select(transfer_id, is_first_icu)

# find all first admits per stay that go from ed to an icu stay
ed_to_icu <- transfers %>%
  group_by(subject_id, hadm_id) %>%
  arrange(intime, .by_group = TRUE) %>%
  left_join(first_icu_transfer, by = "transfer_id") %>%
  filter(
    (is_first_icu & lag(careunit) == "Emergency Department") |
      (careunit == "Emergency Department" & lead(is_first_icu))
  ) %>%
  ungroup()

# join all stays with icd codes later on billed
icd_visits <- diagnoses_patients %>%
  inner_join(
    select(admissions, subject_id, hadm_id, stay_seq, admittime, dischtime, days_between_stays),
    by = c("subject_id", "hadm_id") 
  )

# get all the icd 9 codes that are needed for charlson score and see if a patient was diagnosed with them
map9 <- comorbidity(x = filter(icd_visits, icd_version == 9),
                    id = "hadm_id", code = "icd_code",
                    map = "charlson_icd9_quan", assign0 = TRUE)

# get all the icd 10 codes that are needed for charlson score and see if a patient was diagnosed with them
map10 <- comorbidity(x = filter(icd_visits, icd_version == 10),
                     id = "hadm_id", code = "icd_code",
                     map = "charlson_icd10_quan", assign0 = TRUE)

# put these maps together and join back into main dataset icd_visits
all_maps <- bind_rows(map9, map10) %>%
  group_by(hadm_id) %>%
  summarise(across(mi:aids, max)) %>%
  left_join(
    unique(select(icd_visits, subject_id, hadm_id, stay_seq)),
    by = "hadm_id"
  )

# make sure if previous stays have been diagnosed with certain code, future stays still have that recorded for patient history
final_cci <- all_maps %>%
  group_by(subject_id) %>%
  arrange(stay_seq) %>%
  mutate(across(mi:aids, ~ {
    # calculate cumulative history including current visit
    cum_history = cumany(.x == 1)
    # lag it by 1 so current visit only sees history from stay_seq - 1
    lag(cum_history, default = FALSE)
  })) %>%
  ungroup()

# for score to work, force meta tags to have class comorbidity and attributes to be charlson_icd10_quan
class(final_cci) <- c("comorbidity", class(final_cci))
attr(final_cci, "map") <- "charlson_icd10_quan"

# finally, weighted score based on all diagnoses
final_cci$charlson_score <- score( 
  final_cci, weights = "quan", assign0 = TRUE
)

# only keep the stays where we are interested in the ed to icu transfers
charlson <- final_cci %>%
  select(subject_id, hadm_id, stay_seq, charlson_score) %>%
  right_join(
    first_icu,
    by = c("subject_id", "hadm_id")
  )

charlson %>%
  filter(if_any(charlson_score, is.na))

# there are some missing icd codes for patient hadm_id, the scores become NA
diagnoses_patients %>%
  filter(subject_id == 10909927)
