###############################################################################
#  ____                  _
# |  _ \  ___  _ __ ___ (_)_ __   ___
# | | | |/ _ \| '_ ` _ \| | '_ \ / _ \
# | |_| | (_) | | | | | | | | | | (_) |
# |____/ \___/|_| |_| |_|_|_| |_|\___/
# ____________________________________________________________________________
# Sponsor              : Domino
# Compound             : Xanomeline
# Study                : H2QMCLZZT
# Analysis             : PILOT01
# Program              : adsl.R 
# ____________________________________________________________________________
# DESCRIPTION 
#
# Sample R code to create an ADaM ADSL.
#                                                                   
# Input files: dm, ex, ds, sv, qs, vs, sc, mh
#
# Output files: adsl.xpt
#
# Macros: tidyverse, admiral
#
# Assumptions: 
# ____________________________________________________________________________
# PROGRAM HISTORY                                                         
# ----------------------------------------------------------------------------
#  20220607  | tom.ratford        | Init         
##############################################################################

# Libs
library(tidyverse)
library(lubridate)
library(admiral)

# Data

address = paste0("/mnt/imported/data/snapshots/SDTM/SDTM_", Sys.getenv("DCUTDTC"))
datasets = c("dm","ex","ds","sv","qs","vs","sc","mh")

for (dset_name in datasets){
  assign(dset_name, haven::read_sas(paste0(address,"/",dset_name,".sas7bdat")))
}

dm <- dm %>% convert_blanks_to_na()
ex <- ex %>% convert_blanks_to_na()
ds <- ds %>% convert_blanks_to_na()
sv <- sv %>% convert_blanks_to_na()
qs <- qs %>% convert_blanks_to_na()
vs <- vs %>% convert_blanks_to_na()
sc <- sc %>% convert_blanks_to_na()
mh <- mh %>% convert_blanks_to_na()

# Metadata, labels & order
ADSL_vars <- c(
  STUDYID = "Study Identifier",
  USUBJID = "Unique Subject Identifier",
  SUBJID = "Subject Identifier for the Study",
  SITEID = "Study Site Identifier",
  SITEGR1 = "Pooled Site Group 1",
  ARM = "Description of Planned Arm",
  TRT01P = "Planned Treatment for Period 01",
  TRT01PN = "Planned Treatment for Period 01 (N)",
  TRT01A = "Actual Treatment for Period 01",
  TRT01AN = "Actual Treatment for Period 01 (N)",
  RFSTDTC = "Subject Reference Start Date/Time",
  RFENDTC = "Subject Reference End Date/Time",
  RFXSTDTC = "Date/Time of First Study Treatment",
  RFXENDTC = "Date/Time of Last Study Treatment",
  LSTEXDTC = "Date/Time of Last End of Exposure",
  EOSSTT = "End of Study Status",
  EOSDT = "End of Study Date",
  EOSDY = "End of Study Day",
  DCSREAS = "Reason for Discontinuation from Study",
  DCSREAPL = "Reason for Disc from Study (Pooled)",
  RANDDT = "Date of Randomization",
  TRTSDT = "Date of First Exposure to Treatment",
  TRTEDT = "Date of Last Exposure to Treatment",
  TRTDURD = "Total Treatment Duration (Days)",
  CUMDOSE = "Cumulative Dose (as planned)",
  AVGDD = "Avg Daily Dose (as planned)",
  AGE = "Age",
  AGEGR1 = "Pooled Age Group 1",
  AGEGR1N = "Pooled Age Group 1 (N)",
  AGEU = "Age Units",
  RACE = "Race",
  RACEN = "Race (N)",
  SEX = "Sex",
  ETHNIC = "Ethnicity",
  RANDFL = "Randomized Population Flag",
  ITTFL = "Intent-To-Treat Population Flag",
  SAFFL = "Safety Population Flag",
  EFFFL = "Efficacy Population Flag",
  COMPLFL = "Completers Population Flag",
  COMP8FL = "Completers of Week 8 Population Flag",
  COMP16FL = "Completers of Week 16 Population Flag",
  COMP26FL = "Completers of Week 26 Population Flag",
  DTHFL = "Subject Death Flag",
  DTHDTC = "Date/Time of Death",
  DTHDT = "Date of Death",
  BMIBL = "Baseline BMI (kg/m2)",
  BMIGR1 = "Pooled Baseline BMI Group 1",
  HEIGHTBL = "Baseline Height (cm)",
  WEIGHTBL = "Baseline Weight (kg)",
  EDLEVEL = "Years of Education Completed",
  DISONDT = "Date of Disease Onset",
  VIS1DT = "Date of Visit 1",
  DURDISM = "Duration of Disease (Months)",
  DURDSGR1 = "Pooled Disease Duration Group 1",
  VISNUMEN = "End of Trt Visit (Vis 12 or Early Term.)",
  BLDSEV = "Baseline Disease Severity (MMSE)"
) 

# Codelists

TRTN <- c(
  "Placebo" = 0,
  "Xanomeline Low Dose" = 54,
  "Xanomeline High Dose" = 81,
  "Screen Failure" = NA
)

AGEGR <- c("<65" = "1",
           "65-80" = "2",
           ">80" = "3")

RACEN <- c(
  "WHITE" = 1,
  "BLACK OR AFRICAN AMERICAN" = 2,
  "ASIAN" = 3,
  "AMERICAN INDIAN OR ALASKA NATIVE" = 6
)

DCSREAPL_FMT <- c("ADVERSE EVENT" = "Adverse Event", 
                  "DEATH" = "Death", 
                  "LACK OF EFFICACY" = "Lack of Efficacy", 
                  "LOST TO FOLLOW-UP" = "Lost to Follow-up", 
                  "PHYSICIAN DECISION" = "Physician Decision",
                  "PROTOCOL VIOLATION" = "Protocol Violation",
                  "STUDY TERMINATED BY SPONSOR" = "Sponsor Decision",
                  "WITHDRAWAL BY SUBJECT" = "Withdrew Consent"
)

# User defined functions

## SAS Round function: SAS's `round` does not round to even as per IEEE / IEC
## This function implements a crude rounding
sas_round <- function(x, digits = 1) {
  mult <- 10^digits
  floor((x * mult) + 0.5) / mult
}

## SITEGR1 Derivation
add_sitegr1 <- function(.data) {
  if (all(c("SITEID", "ARMCD") %in% colnames(.data))) {
    .data %>%
      group_by(SITEID, ARMCD) %>%
      mutate(siteid_n = n_distinct(USUBJID)) %>%
      ungroup(ARMCD) %>%
      mutate(
        siteid_n = if_else(!(ARMCD %in% c("Xan_Lo", "Xan_Hi", "Pbo")), 999, as.double(siteid_n)),
        min_siteid = min(siteid_n),
        SITEGR1 = if_else(min_siteid < 3, "900", SITEID)
      ) %>%
      ungroup
  } else {
    errorCondition("SITEID or ARMCD not present in data")
    .data
  }
}

## Derive last exposure date
add_lstexdtc <- function(.data,
                         ex_data = ex) {
  latest_ex <- ex_data %>%
    filter((EXDOSE == 0 & EXTRT == "PLACEBO") | EXDOSE > 0) %>%
    group_by(USUBJID) %>%
    mutate(EXESDT = convert_dtc_to_dt(EXENDTC),
           LSTEXDT = max(EXESDT),
           LSTEXDTC = as.character(LSTEXDT)) %>%
    ungroup %>%
    select(USUBJID, LSTEXDT, LSTEXDTC) %>%
    distinct
  
  .data %>%
    left_join(latest_ex, by = "USUBJID")
}

## randdt
add_randdt <- function(.data) {
  sv_randdt <- sv %>%
    filter(VISITNUM == 3) %>%
    mutate(RANDDT = convert_dtc_to_dt(SVSTDTC)) %>%
    select(USUBJID, RANDDT) %>%
    distinct
  
  .data %>%
    left_join(sv_randdt, by = "USUBJID")
}

## cumdose
add_cumdose <- function(.data, ex_data = ex) {
  ex_cumdose <- ex_data %>%
    left_join(.data, by = "USUBJID") %>%
    group_by(USUBJID) %>%
    mutate(
      diffdose = if_else(
        TRT01P == 0,
        0,
        EXENDY - EXSTDY + 1
      ),
      diffdose = if_else(
        is.na(diffdose),
        TRTEDT - TRTSDT + 1,
        diffdose
      ),
      cumdose = EXDOSE * as.numeric(diffdose)
    ) %>%
    summarize(CUMDOSE = sum(cumdose)) %>%
    ungroup %>%
    select(USUBJID, CUMDOSE) %>%
    distinct
  
  .data %>%
    left_join(ex_cumdose, by = "USUBJID")
}

## Derive disc reason
add_disc_reas <- function(.data, ds_dset = ds){
  ds_reas <- ds %>%
    filter(DSCAT == "DISPOSITION EVENT" & DSDECOD == "COMPLETED") %>%
    select(USUBJID, DCSREAS=DSDECOD) %>%
    mutate(
      DCSREAPL = recode(DCSREAS, !!!DCSREAPL_FMT)
    ) %>%
    distinct
  
  .data %>%
    left_join(ds_reas, by = "USUBJID")
}

## Derive Efficacy pop flag
add_efffl <- function(.data, qs_dset = qs){
  qs_efffl <- qs %>%
    mutate(
      cat = case_when(
        grepl("^ACITM", QSTESTCD) ~ "ADAS",
        QSTESTCD == "CIBIC" ~ "CIBIC",
        TRUE ~ "DROP"
      )
    ) %>%
    filter(VISITNUM > 3 & (cat != "DROP")) %>%
    group_by(USUBJID) %>%
    mutate(
      EFFFL=if_else(n_distinct(cat) >= 2,"Y","N")
    ) %>%
    select(USUBJID, EFFFL) %>%
    distinct %>%
    ungroup
  
  .data %>%
    left_join(qs_efffl, by="USUBJID") %>%
    mutate(
      EFFFL=if_else(SAFFL == "N" | is.na(EFFFL), "N", EFFFL),
  )  
}

## Completer flag
add_complfl <- function(.data, sv_dset = sv) {
  sv_withfl <- sv %>% 
    left_join(select(.data, USUBJID, EOSDT), by="USUBJID") %>%
    group_by(USUBJID) %>%
    mutate(
      SVSTDT = convert_dtc_to_dt(SVSTDTC),
      COMPLFL = if_else(any(VISITNUM == 12 & EOSDT >= SVSTDT),"Y","N"),
      COMP8FL = if_else(any(VISITNUM == 8 & EOSDT >= SVSTDT),"Y","N"),
      COMP16FL = if_else(any(VISITNUM == 10 & EOSDT >= SVSTDT),"Y","N"),
    ) %>%
    ungroup %>%
    select(USUBJID, COMPLFL, COMP8FL, COMP16FL) %>%
    distinct
  
  .data %>%
    left_join(sv_withfl, BY="USUBJID")
}

## BMI group, pooled BMI group, HEIGHTBL and WEIGHTBL
add_baseline_vs <- function(.data, vs_dset = vs) {
  vs_baseline <- vs %>%
    filter((VSTESTCD == "HEIGHT" & VISITNUM == 1) | (VSTESTCD == "WEIGHT" & VISITNUM == 3)) %>%
    pivot_wider(
      id_cols = USUBJID,
      names_from = VSTESTCD,
      names_glue = "{VSTESTCD}BL",
      values_from = VSSTRESN
    ) %>%
    mutate(
      HEIGHTBL = sas_round(HEIGHTBL,1),
      WEIGHTBL = sas_round(WEIGHTBL,1),
      BMIBL = sas_round(WEIGHTBL / (HEIGHTBL / 100)^2,1),
      BMIGR1 = as.character(cut(
        x = BMIBL,
        breaks = c(-Inf, 25, 30, Inf),
        labels = c("<25", "25-<30", ">=30"),
        right = FALSE
      )),
    ) %>%
    distinct
  
  .data %>% 
    left_join(vs_baseline, by = "USUBJID")
}

# Code

ADSL <- dm %>%
  # drop screen failures
  filter(ARM != "Screen Failure") %>%
  # Derive treatment decode vars & treatment start date
  mutate(
    TRT01P = ARM,
    TRT01A = ARM,
    TRT01PN = recode(TRT01P, !!!TRTN),
    TRT01AN = recode(TRT01A, !!!TRTN),
    TRTSDT = convert_dtc_to_dt(RFXSTDTC),
    EOSDT = convert_dtc_to_dt(RFENDTC),
    EOSDY = as.numeric(EOSDT - convert_dtc_to_dt(RFSTDTC)) + 1
  ) %>%
  # Derive LSTEXDTC, TRTEDT and TRTDURD
  add_lstexdtc %>%
  mutate(TRTEDT = if_else(is.na(LSTEXDT), EOSDT, LSTEXDT),
         TRTDURD = as.numeric(TRTEDT - TRTSDT) + 1) %>%
  # Derive end of study status
  derive_var_disposition_status(
    dataset_ds = ds,
    new_var = EOSSTT,
    status_var = DSDECOD,
    format_new_var = format_eoxxstt_default,
    filter_ds = DSCAT == "DISPOSITON EVENT"
  ) %>%
  add_disc_reas %>%
  # randdt
  add_randdt %>%
  # cumdose
  add_cumdose %>%
  mutate(AVGDD = sas_round(CUMDOSE / TRTDURD, 1)) %>%
  # agegr1 and racen
  mutate(
    AGEGR1N = cut(
      x = AGE,
      breaks = c(-Inf, 64, 80, Inf),
      labels = c(1, 2, 3)
    ),
    AGEGR1 = as.character(fct_recode(AGEGR1N, !!!AGEGR)),
    RACEN = recode(RACE,!!!RACEN)
  ) %>%
  # sitegr1
  add_sitegr1 %>% 
  # randfl
  mutate(
    RANDFL = if_else(!is.na(ARMCD), "Y", "N"),
    ITTFL = RANDFL,
    SAFFL = if_else(ITTFL == "Y" & !is.na(TRTSDT), "Y", "N")
  ) %>%
  # efficacy pop
  add_efffl %>% 
  # completion flags
  add_complfl %>% 
  mutate(
    COMP26FL =  if_else(EOSSTT == "COMPLETED", "Y", "N")
  ) %>%
  # death date
  mutate(
    DTHDT=convert_dtc_to_dt(DTHDTC)
  ) %>% 
  # VS baseline vals
  add_baseline_vs %>%
  # years of education
  left_join(
    filter(sc, SCTESTCD == "EDLEVEL") %>%
      select(USUBJID, EDLEVEL=SCSTRESN) %>%
      distinct,
    by = "USUBJID"
  ) %>%
  # Date of disease onset
  left_join(
    filter(mh, MHCAT == "PRIMARY DIAGNOSIS") %>%
      mutate(DISONDT = convert_dtc_to_dt(MHSTDTC)) %>%
      select(USUBJID, DISONDT) %>%
      distinct,
    by = "USUBJID"
  ) %>% 
  # Date of visit 1
  left_join(
    filter(sv, VISITNUM == 1) %>%
      mutate(VIS1DT = convert_dtc_to_dt(SVSTDTC)) %>%
      select(USUBJID, VIS1DT) %>%
      distinct,
    by = "USUBJID"
  ) %>% 
  # Duration of disease 
  mutate(
    DURDISM = floor(time_length(interval(DISONDT,VIS1DT),"months")),
    DURDSGR1 = as.character(cut(
      x = DURDISM,
      breaks = c(-Inf, 12, Inf),
      labels = c("<12", ">=12"),
      right = FALSE
    ))
  ) %>%
  # End of treatment visit. 
  left_join(
    filter(ds, DSDECOD == "COMPLETED" & DSCAT == "DISPOSITION EVENT") %>%
      mutate(VISNUMEN = min(12, VISITNUM)) %>%
      select(USUBJID, VISNUMEN) %>%
      distinct,
    by = "USUBJID"
  ) %>%
  # Baseline disease severity
  left_join(
    filter(qs, QSCAT == "MINI-MENTAL STATE") %>%
      group_by(USUBJID) %>%
      summarise(BLDSEV = sum(as.numeric(QSORRES))) %>%
      ungroup %>%
      distinct,
    by = "USUBJID"
  ) %>%
  select(!!!names(ADSL_vars))
  
# Labels

walk2(names(ADSL_vars), ADSL_vars, ~ {attr(ADSL[[.x]], "label") <<- .y})
attr(ADSL, "label") <- "Subject-Level Analysis Dataset"

# Date vars correct format

ADSL %>% 
  select(ends_with("DT")) %>%
  colnames %>%
  walk(~ {attr(ADSL[[.x]], "format.sas") <<- "DATE9"})

# export
haven::write_xpt(ADSL, "/mnt/data/ADAM/adsl.xpt")
