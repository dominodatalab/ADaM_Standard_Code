/*****************************************************************************\
*  ____                  _
* |  _ \  ___  _ __ ___ (_)_ __   ___
* | | | |/ _ \| '_ ` _ \| | '_ \ / _ \
* | |_| | (_) | | | | | | | | | | (_) |
* |____/ \___/|_| |_| |_|_|_| |_|\___/
* ____________________________________________________________________________
* Sponsor              : Domino
* Study                : Pilot01
* Program              : advs.sas
* Purpose              : Create ADVS dataset
* ____________________________________________________________________________
* DESCRIPTION
*
* Input files:  SDTM.VS
*               ADaM.ADSL
*
* Output files: ADaM.ADVS
*
* Macros:       None
*
* Assumptions:
*
* ____________________________________________________________________________
* PROGRAM HISTORY
*  12APR2022 |  Dianne Weatherall   |  Original
* ----------------------------------------------------------------------------
\*****************************************************************************/


*********;
** Setup environment including libraries for this reporting effort;
%include "!DOMINO_WORKING_DIR/config/domino.sas";
*********;


**** USER CODE FOR ALL DATA PROCESSING **;

%let keepvars = STUDYID USUBJID SUBJID SITEID TRTA TRTAN VSSTAT VSLOC ADT ADY VISIT VISITNUM AVISIT AVISITN ATPT ATPTN
                PARAM PARAMCD PARAMN AVAL BASE BASETYPE CHG ABLFL ANL01FL;

* Get variables from ADSL;
data adsl (keep = studyid usubjid subjid siteid trt01a trt01an trtsdt rename = (trt01a = trta trt01an = trtan));
  set adamw.adsl;
run;

* Get vital sign data;
data vs (keep = usubjid vsstat vsloc adt visit visitnum avisitn avisit atpt atptn vstestcd vstest vsstresu aval basetype);
  set sdtm.vs;

  length avisit atpt $ 200;

  * ADT;
  if (length(vsdtc) ge 10) then adt = input(vsdtc,e8601da.);

  * AVISITN, AVISIT;
  avisitn = visitnum;
  avisit  = trim(left(visit));
  substr(avisit,2)  = lowcase(substr(avisit,2));
  avisit  = tranwrd(avisit,"ecg","ECG");
  avisit  = tranwrd(avisit,"Ae","AE");

  * ATPT, ATPTN;
  if (vstpt ne "")   then atpt = trim(left(vstpt));
  if (vstptnum ne .) then atptn = vstptnum;

  * AVAL;
  if (vsstresn ne .) then aval = vsstresn;

  * BASETYPE;
  basetype = trim(left(atpt));
run;

* Merge with ADSL to derive ADY;
proc sort data = vs;
  by usubjid;
run;

data vsadsl;
  merge adsl vs (in = v);
    by usubjid;
  if v;
run;

data vsadsl1;
  set vsadsl;

  * ADY;
  if (adt ne .) and (trtsdt ne .) and (adt ge trtsdt)      then ady = adt - trtsdt + 1;
  else if (adt ne .) and (trtsdt ne .) and (adt lt trtsdt) then ady = adt - trtsdt;
run;

* Get unique vstestcd, vstest with non-missing vsstresu to create param;
proc sort data = vsadsl1 out = tests (keep = vstestcd vstest vsstresu rename = (vsstresu = resu)) nodupkey;
  by vstestcd vstest vsstresu;
  where vsstresu ne "";
run;

proc sort data = vsadsl1;
  by vstestcd vstest vsstresu;
run;

data advspar1;
  merge tests vsadsl1;
    by vstestcd vstest;
run;

data advspar2;
  set advspar1;

  length paramcd param $ 200;

  * PARAMCD, PARAM, PARAMN;
  paramcd = trim(left(vstestcd));

  if (resu ne "")      then param = trim(left(vstest)) || " (" || trim(left(resu)) || ")";
  else if (resu eq "") then param = trim(left(vstest));

  select (paramcd);
    when ("SYSBP")     paramn = 1;
        when ("DIABP")     paramn = 2;
        when ("PULSE")     paramn = 3;
        when ("TEMP")      paramn = 4;
        when ("WEIGHT")    paramn = 5;
        when ("HEIGHT")    paramn = 6;
        otherwise put "Check: " paramcd=;
  end;
run;

* Get last on treatment record;
data eot;
  set advspar2;
  if (ady gt 1) and (visitnum le 12) and (aval ne .) then ontrt = 1;
run;

proc sort data = eot;
  by ontrt usubjid paramcd atptn adt;
run;

data eot1;
  set eot;
    by ontrt usubjid paramcd atptn adt;
  if last.atptn and (ontrt eq 1) then lvotfl = "Y";
run;

* Output the last on-treatment record as a visit;
data eot2;
  set eot1;
  if (lvotfl eq "") then output;
  else if (lvotfl eq "Y") then do;
    output;
        avisitn = 601;
        avisit  = "End of treatment";
        output;
  end;
run;

* Baseline;
data vsbase;
  set eot2;

  if (adt ne .) and (trtsdt ne .) and (adt le trtsdt) and (aval ne .) then baserec = 1;
run;

proc sort data = vsbase;
  by baserec usubjid paramcd atptn adt avisitn;
run;

data vsbase1;
  set vsbase;
    by baserec usubjid paramcd atptn adt avisitn;

  length ablfl $ 200;

  if last.atptn and (baserec eq 1) then ablfl = "Y";
run;

proc sort data = vsbase1;
  by usubjid paramcd atptn adt avisitn;
run;

data vsbase2;
  retain base;
  set vsbase1;
    by usubjid paramcd atptn;
  if first.atptn then base = .;
  if (ablfl eq "Y") then base = aval;
run;

* Analysable records;
data advs;
  set vsbase2;

  length anl01fl $ 200;

  * CHG;
  if (aval ne .) and (base ne .) and (ablfl ne "Y") then chg = aval - base;

  * ANL01FL;
  if (paramcd in ("SYSBP","DIABP","PULSE","WEIGHT")) and ((upcase(avisit) in ("WEEK 24","END OF TREATMENT")) or (ablfl eq "Y")) then anl01fl = "Y";
run;

proc sort data = advs;
  by usubjid paramcd atptn avisitn;
run;

* ASEQ;
data final;
  set advs;
    by usubjid paramcd atptn avisitn;
  if first.usubjid then aseq = 0;
  aseq + 1;
  if not first.avisitn then put "Check order: " usubjid= paramcd= avisitn= atptn=;
run;

data adamw.advs (label = "Vital Signs Analysis Dataset");
  retain &keepvars.;
  set final (keep = &keepvars.);

  label
    STUDYID  = "Study Identifier"
    USUBJID  = "Unique Subject Identifier"
    SUBJID   = "Subject Identifier for the Study"
    SITEID   = "Study Site Identifier"
    TRTA     = "Actual Treatment"
    TRTAN    = "Actual Treatment (N)"
    VSSTAT   = "Completion Status"
    VSLOC    = "Location of Vital Signs Measurement"
    ADT      = "Analysis Date"
    ADY      = "Analysis Relative Day"
    VISIT    = "Visit Name"
    VISITNUM = "Visit Number"
    AVISIT   = "Analysis Visit"
    AVISITN  = "Analysis Visit (N)"
    ATPT     = "Analysis Timepoint"
    ATPTN    = "Analysis Timepoint (N)"
    PARAM    = "Parameter"
    PARAMCD  = "Parameter Code"
    PARAMN   = "Parameter (N)"
    AVAL     = "Analysis Value"
    BASE     = "Baseline Value"
        BASETYPE = "Baseline Type"
    CHG      = "Change from Baseline"
    ABLFL    = "Baseline Record Flag"
    ANL01FL  = "Analysis Flag 01"
  ;
  format adt date9.;
run;

**** END OF USER DEFINED CODE **;

********;
*%s_scanlog;
********;
