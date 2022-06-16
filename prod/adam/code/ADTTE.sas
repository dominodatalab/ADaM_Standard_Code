/*****************************************************************************\
*  ____                  _
* |  _ \  ___  _ __ ___ (_)_ __   ___
* | | | |/ _ \| '_ ` _ \| | '_ \ / _ \
* | |_| | (_) | | | | | | | | | | (_) |
* |____/ \___/|_| |_| |_|_|_| |_|\___/
* ____________________________________________________________________________
* Sponsor              : Domino
* Study                : H2QMCLZZT
* Program              : adtte.sas
* Purpose              : Create ADTTE dataset
* ____________________________________________________________________________
* DESCRIPTION                                                    
*                                                                   
* Input files:  ADAM.ADAE
*               ADaM.ADSL
*                                                                   
* Output files: ADaM.ADTTE 
*                                                                 
* Macros:       None                                                       
*                                                                   
* Assumptions:                                                    
*                                                                   
* ____________________________________________________________________________
* PROGRAM HISTORY     
*  08JUN2022  | Tom Ratford  | Original  
* ---------------------------------------------------------------------------- 
\*****************************************************************************/

    
*********;
** Setup environment including libraries for this reporting effort;
%include "!DOMINO_WORKING_DIR/config/domino.sas";
*********;


**** USER CODE FOR ALL DATA PROCESSING **;

%let keepvars = STUDYID SITEID USUBJID TRTA TRTAN AGE AGEGR1 AGEGR1N RACE RACEN SEX SAFFL TRTSDT TRTEDT ASEQ ADT ADY 
                PARAM PARAMCD STARTDT CNSR AVAL EVNTDESC CNSDTDSC;

* Get dermatologic events from ADAE;
data adae (keep = usubjid cq01nam astdt);
  set adam.adae;
  if (cq01nam eq "DERMATOLOGIC EVENTS") and (trtemfl eq "Y");
run;

* Choose the first event;
proc sort data = adae;
  by usubjid astdt;
run;

data derm;
  set adae;
    by usubjid;
  if first.usubjid;
run;

* Merge with subjects in ADSL to create a dataset with 1 record per subject;
data adsl (keep   = studyid siteid usubjid trt01a trt01an age agegr1 agegr1n race racen sex saffl trtsdt trtedt dthdt eosdt eosstt
           rename = (trt01a = trta trt01an = trtan));
  set adam.adsl;
run;

data all;
  merge adsl derm;
    by usubjid;
run;

data adtte;
  set all;

  length paramcd param evntdesc cnsdtdsc $ 200;

  * ADT, CNSR;
  * Event occurred;
  if (cq01nam eq "DERMATOLOGIC EVENTS") then do;
    adt      = astdt;
        cnsr     = 0;
        evntdesc = "Dermatologic event occurred";
  end;
  * Event did not occur;
  else if (cq01nam ne "DERMATOLOGIC EVENTS") then do;
    if (dthdt ne .)      then do;
      adt      = dthdt;
          evntdesc = "Death";
        end;
        else if (eosdt ne .) then do;
      adt      = eosdt;
          if (eosstt eq "DISCONTINUED")   then evntdesc = "Early terminated without dermatologic event";
          else if (eosstt eq "COMPLETED") then evntdesc = "Completed study without dermatologic event";
        end;
        else put "Check: " usubjid= ;
        cnsr = 1;
        if (dthdt ne .)      then cnsdtdsc = "Death";
        else if (eosdt ne .) then cnsdtdsc = "End of study date";
  end;

  * ADY;
  if (trtsdt ne .) and (adt ne .) then do;
    if (adt ge trtsdt)      then ady = adt - trtsdt + 1;
        else if (adt lt trtsdt) then ady = adt - trtsdt;
  end;

  * PARAMCD, PARAM;
  paramcd = "TTDERM";
  param   = "Time to Dermatologic Event";

  * STARTDT, AVAL;
  startdt = trtsdt;
  if (adt ne .) and (startdt ne .) then aval = adt - startdt + 1;
  else put "Check: " usubjid= adt=;
run; 

proc sort data = adtte;
  by usubjid paramcd;
run;

* ASEQ;
data final;
  set adtte;
    by usubjid;
  if first.usubjid then aseq = 0;
  aseq + 1;
run;

data adam.adtte (label = "Time to Event Analysis Dataset");
  retain &keepvars.;
  set final (keep = &keepvars.);

  label
    STUDYID  = "Study Identifier"
    SITEID   = "Study Site Identifier"
    USUBJID  = "Unique Subject Identifier"
    TRTA     = "Actual Treatment"
    TRTAN    = "Actual Treatment (N)"
    AGE      = "Age"
    AGEGR1   = "Pooled Age Group 1"
    AGEGR1N  = "Pooled Age Group 1 (N)"
    RACE     = "Race"
    RACEN    = "Race (N)"
    SEX      = "Sex"
    SAFFL    = "Safety Population Flag"
    TRTSDT   = "Date of First Exposure to Treatment"
    TRTEDT   = "Date of Last Exposure to Treatment"
    ASEQ     = "Analysis Sequence Number"
    ADT      = "Analysis Date"
    ADY      = "Analysis Relative Day"
    PARAM    = "Parameter"
    PARAMCD  = "Parameter Code"
    STARTDT  = "Time to Event Origin Date for Subject"
    CNSR     = "Censor"
    AVAL     = "Analysis Value"
    EVNTDESC = "Event or Censoring Description"
    CNSDTDSC = "Censor Date Description"
  ;
  format trtsdt trtedt adt startdt date9.;
run;

**** END OF USER DEFINED CODE **;

********;
*%s_scanlog;
********;
