# Header goes here 

############################
#         ADSL
############################

rm(list=ls())

# Libs
library(tidyverse)
library(admiral)

# Data
dm <- admiral.test::admiral_dm %>% convert_blanks_to_na()
ex <- admiral.test::admiral_ex %>% convert_blanks_to_na()
ds <- admiral.test::admiral_ds %>% convert_blanks_to_na()
sv <- admiral.test::admiral_sv %>% convert_blanks_to_na()
qs <- admiral.test::admiral_qs %>% convert_blanks_to_na()
vs <- admiral.test::admiral_vs %>% convert_blanks_to_na()
# sc <- admiral.test::admiral_sc %>% convert_blanks_to_na()
mh <- admiral.test::admiral_mh %>% convert_blanks_to_na()

# Metadata, labels & order
ADSL_vars <- c(
  SIT
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
           "80" = "3")

RACEN <- c(
  "WHITE" = 1,
  "BLACK OR AFRICAN AMERICAN" = 2,
  "ASIAN" = 3,
  "AMERICAN INDIAN OR ALASKA NATIVE" = 5
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
           LSTEXDTC = max(EXESDT)) %>%
    ungroup %>%
    select(USUBJID, LSTEXDTC) %>%
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
    mutate(cumdose = if_else(
      TRT01P == 0,
      0,
      EXDOSE * if_else(
        is.na(EXENDY),
        EXENDY - EXSTDY + 1,
        as.numeric(TRTEDT - TRTSDT) + 1
      )
    )) %>%
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
    group_by(USUBJID,VISITNUM) %>%
    mutate(
      EFFFL=if_else(n_distinct(cat) >= 2,"Y","N")
    ) %>%
    ungroup() %>%
    select(USUBJID, EFFFL) %>%
    distinct
  
  .data %>%
    left_join(qs_efffl, by="USUBJID")
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
      BMIBL = round(WEIGHTBL / (HEIGHTBL / 100)^2,1),
      BMIGR1 = cut(
        x = BMIBL,
        breaks = c(-Inf, 25, 30, Inf),
        labels = c("<25", "25-<30", ">=30"),
        right = FALSE
      )
    ) %>%
    distinct
  
  .data %>% 
    left_join(vs_baseline, by = "USUBJID")
}

# Code

ADSL <- dm %>%
  # Derive treatment decode vars & treatment start date
  mutate(
    TRT01P = ARM,
    TRT01A = ACTARM,
    TRT01PN = recode(TRT01P, !!!TRTN),
    TRT01AN = recode(TRT01A, !!!TRTN),
    TRTSDT = convert_dtc_to_dt(RFXSTDTC),
    EOSDT = convert_dtc_to_dt(RFENDTC),
    EOSDY = as.numeric(EOSDT - convert_dtc_to_dt(RFSTDTC)) + 1
  ) %>%
  # Derive LSTEXDTC, TRTEDT and TRTDURD
  add_lstexdtc %>%
  mutate(TRTEDT = if_else(is.na(LSTEXDTC), EOSDT, LSTEXDTC),
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
  mutate(AVGDD = CUMDOSE / TRTDURD) %>%
  # agegr1 and racen
  mutate(
    AGEGR1N = cut(
      x = AGE,
      breaks = c(-Inf, 64, 80, Inf),
      labels = c(1, 2, 3)
    ),
    AGEGR1 = fct_recode(AGEGR1N, !!!AGEGR),
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
  # left_join(
  #   filter(sc, SCTESTCD == "EDLEVEL") %>%
  #     select(USUBJID, EDLEVEL=SCSTRESN) %>%
  #     distinct,
  #   by = "USUBJID"
  # ) %>% 
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
    DURDISM = as.numeric(VIS1DT - DISONDT)/30.417,
    DURDSGR1 = cut(
      x = DURDISM,
      breaks = c(-Inf, 12, Inf),
      labels = c("<12", ">=12"),
      right = FALSE
    )
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
  )

