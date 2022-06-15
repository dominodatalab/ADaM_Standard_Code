/*****************************************************************************\
*  ____                  _
* |  _ \  ___  _ __ ___ (_)_ __   ___
* | | | |/ _ \| '_ ` _ \| | '_ \ / _ \
* | |_| | (_) | | | | | | | | | | (_) |
* |____/ \___/|_| |_| |_|_|_| |_|\___/
* ____________________________________________________________________________
* Sponsor              : Domino
* Study                : H2QMCLZZT
* Program              : adqscibi.sas
* Purpose              : Create qc ADQSCIBI dataset
* ____________________________________________________________________________
* DESCRIPTION                                                    
*                                                                   
* Input files:  SDTM.QS
*               ADaMqc.ADSL
*                                                                   
* Output files: ADaMqc.ADQSCIBI 
*                                                                 
* Macros:       None                                                       
*                                                                   
* Assumptions:                                                    
*                                                                   
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*  9JUN2022  | Jake Tombeur  | Original version 
* ---------------------------------------------------------------------------- 
\*****************************************************************************/

    
*********;
** Setup environment including libraries for this reporting effort;
%include "!DOMINO_WORKING_DIR/config/domino.sas";
*********;


**** USER CODE FOR ALL DATA PROCESSING **;

%let keepvars = STUDYID SITEID USUBJID QSSEQ ITTFL EFFFL TRTP TRTPN ADT ADY ARNDY VISIT VISITNUM AVISIT AVISITN
                PARAM PARAMCD AVAL AVALC DTYPE AWRANGE AWTARGET AWTDIFF AWLO AWHI AWU ANL01FL;

* Create dataset with visit windows;
data viswin;
  length awu awrange avisit $ 40;

  awu = "DAYS";

  awtarget = 1;     awlo = -999; awhi = 1;    awrange = "<=1";     avisitn = 3;   avisit = "Baseline";   output;
  awtarget = 56;    awlo = 2;    awhi = 84;   awrange = "2-84";    avisitn = 8;   avisit = "Week 8";     output;
  awtarget = 112;   awlo = 85;   awhi = 140;  awrange = "85-140";  avisitn = 10;  avisit = "Week 16";    output;
  awtarget = 168;   awlo = 141;  awhi = 999;  awrange = ">140";    avisitn = 12;  avisit = "Week 24";    output;
run;

* Get variables from ADSL;
data adsl (keep = studyid usubjid subjid siteid ittfl efffl trt01p trt01pn trtsdt randdt rename = (trt01p = trtp trt01pn = trtpn));
  set adamqc.adsl;
run;

* Get questionnaire data and filter on CIBIC+;
data qs (keep = usubjid visit visitnum qsseq adt paramcd param qsstresn qsorres);
  set sdtm.qs;
  if (qscat eq "CLINICIAN'S INTERVIEW-BASED IMPRESSION OF CHANGE (CIBIC+)");

  length paramcd param $ 200;

  * ADT;
  if (length(qsdtc) ge 10) then adt = input(qsdtc,e8601da.);

  * PARAMCD, PARAM;
  paramcd = trim(left(qstestcd));
  param   = trim(left(qstest));
run;

* Merge with ADSL to derive ADY;
proc sort data = qs;
  by usubjid;
run;

data qsadsl;
  merge adsl qs (in = v);
    by usubjid;
  if v;
run;

data qsadsl1;
  set qsadsl;

  * ADY;
  if (adt ne .) and (trtsdt ne .) and (adt ge trtsdt)      then ady = adt - trtsdt + 1;
  else if (adt ne .) and (trtsdt ne .) and (adt lt trtsdt) then ady = adt - trtsdt;

  * ARNDY;
  if (adt ne .) and (randdt ne .) and (adt ge randdt)      then arndy = adt - randdt + 1;
  else if (adt ne .) and (randdt ne .) and (adt lt randdt) then arndy = adt - randdt;
run;

* Merge in visit windows;
proc sql;
  create table qswin as
    select a.*, b.*
    from qsadsl1 a left join viswin b
    on awlo <= arndy <= awhi;
quit;

* Check if more than 1 observation is in a window, take the earlier assessment closest to the target window;
data qswin2;
  set qswin;

  * AWTDIFF;
  awtdiff = abs(arndy - awtarget);
run;

proc sort data = qswin2;
  by usubjid paramcd avisitn awtdiff adt;
run;

data qstarg;
  set qswin2;
    by usubjid paramcd avisitn;

  length anl01fl $ 1;

  if first.avisitn then anl01fl = "Y";
run;

data qsaval;
  set qstarg;

  length avalc $ 200;

  * AVAL, AVALC;
  aval  = qsstresn;
  avalc = trim(left(qsorres));
run;

* Get unique subjects and create a record for each visit;
data groupds (keep = studyid subjid siteid usubjid trtp trtpn randdt trtsdt ittfl efffl paramcd param anl01fl);
  set qsaval;
    by usubjid;
  if (paramcd eq "CIBIC") and (anl01fl eq "Y");
run;

data groupds2;
  set groupds;
    by usubjid;
  if first.usubjid;
run;

data groupds3;
  set groupds2;

  length avisit awu awrange $ 200;

  awu = "DAYS";

  awtarget = 112;   awlo = 85;   awhi = 140;  awrange = "85-140";  avisitn = 10;  avisit = "Week 16";    output;
  awtarget = 168;   awlo = 141;  awhi = 999;  awrange = ">140";    avisitn = 12;  avisit = "Week 24";    output;
run;

proc sort data = groupds3;
  by usubjid paramcd avisitn anl01fl;
run;

proc sort data = qsaval;
  by usubjid paramcd avisitn anl01fl;
run;

data qsall;
  merge groupds3 (in = g) qsaval (in = a);
    by usubjid paramcd avisitn anl01fl;
  if g and not a then incl = 1;
run;

proc sort data = qsall;
  by usubjid paramcd avisitn adt;
run;

* LOCF;
data qslocf;
  retain avallocf avalclocf visitlocf visitnumlocf adylocf adtlocf arndylocf qsseqlocf;
  length visitlocf avalclocf $ 200;
  set qsall;
    by usubjid paramcd;

  if first.paramcd then do;
    avallocf     = .;
        avalclocf    = "";
        visitlocf    = "";
        visitnumlocf = .;
        adtlocf      = .;
        adylocf      = .;
        arndylocf    = .;
        qsseqlocf    = .;
  end;

  if (anl01fl eq "Y") then do;
    if (aval ne .)     then avallocf     = aval;
    if (avalc ne "")   then avalclocf    = avalc;
    if (visit ne "")   then visitlocf    = trim(left(visit));
    if (visitnum ne .) then visitnumlocf = visitnum;
    if (adt ne .)      then adtlocf      = adt;
    if (ady ne .)      then adylocf      = ady;
    if (arndy ne .)    then arndylocf    = arndy;
    if (qsseq ne .)    then qsseqlocf    = qsseq;
  end;
run;

data qslocf2;
  set qslocf;

  length dtype $ 200;

  if (aval eq .) and (avallocf ne .) then do;
    if (paramcd eq "CIBIC") and (aval eq .) and (avallocf ne .) then do;
      aval  = avallocf;
          dtype = "LOCF";
    end;
        if (paramcd eq "CIBIC") and (avalc eq "") and (avalclocf ne "") then do;
      avalc = avalclocf;
          dtype = "LOCF";
    end;
    if (paramcd eq "CIBIC") and (visit eq "") and (visitlocf ne "") then do;
      visit  = visitlocf;
          dtype  = "LOCF";
    end;
    if (paramcd eq "CIBIC") and (visitnum eq .) and (visitnumlocf ne .) then do;
      visitnum  = visitnumlocf;
          dtype     = "LOCF";
    end;
    if (paramcd eq "CIBIC") and (adt eq .) and (adtlocf ne .) then do;
      adt   = adtlocf;
          dtype = "LOCF";
    end;
    if (paramcd eq "CIBIC") and (ady eq .) and (adylocf ne .) then do;
      ady   = adylocf;
          dtype = "LOCF";
    end;
    if (paramcd eq "CIBIC") and (arndy eq .) and (arndylocf ne .) then do;
      arndy = arndylocf;
          dtype = "LOCF";
    end;
    if (paramcd eq "CIBIC") and (qsseq eq .) and (qsseqlocf ne .) then do;
      qsseq   = qsseqlocf;
          dtype = "LOCF";
    end;
  end;
  if (awtdiff eq .) and (arndy ne .) and (awtarget ne .) then awtdiff = abs(arndy - awtarget);
run;

data qsfin;
  set qslocf2;

  * AWLO and AWHI adjustments;
  if (awlo eq -999) then awlo = .;
  if (awhi eq 999)  then awhi = .;
run;

proc sort data = qsfin;
  by usubjid paramcd avisitn adt;
run;

* ASEQ;
data final;
  set qsfin;
    by usubjid paramcd avisitn adt;
  if first.usubjid then aseq = 0;
  aseq + 1;
  if not first.adt then put "Check order: " usubjid= paramcd= avisitn= visitnum=;
run;

data adamqc.adqscibi (label = "CIBIC+ Analysis Dataset");
  retain &keepvars.;
  set final (keep = &keepvars.);

  label
    STUDYID   = "Study Identifier"
    SITEID    = "Study Site Identifier"
    USUBJID   = "Unique Subject Identifier"
    QSSEQ     = "Sequence Number"
    ITTFL     = "Intent-To-Treat Population Flag"
    EFFFL     = "Efficacy Population Flag"
    TRTP      = "Planned Treatment"
    TRTPN     = "Planned Treatment (N)"
    ADT       = "Analysis Date"
    ADY       = "Analysis Relative Day"
    ARNDY     = "Analysis Relative to Randomization Day"
    VISIT     = "Visit Name"
    VISITNUM  = "Visit Number"
    AVISIT    = "Analysis Visit"
    AVISITN   = "Analysis Visit (N)"
    PARAM     = "Parameter"
    PARAMCD   = "Parameter Code"
    AVAL      = "Analysis Value"
    AVALC     = "Analysis Value (C)"
    DTYPE     = "Derivation Type"
    AWRANGE   = "Analysis Window Valid Relative Range"
    AWTARGET  = "Analysis Window Target"
    AWTDIFF   = "Analysis Window Diff from Target"
    AWLO      = "Analysis Window Beginning Timepoint"
    AWHI      = "Analysis Window Ending Timepoint"
    AWU       = "Analysis Window Unit"
    ANL01FL   = "Analysis Record Flag 01"
  ;
  format adt date9.;
run;

**** END OF USER DEFINED CODE **;

********;
*%s_scanlog;
********;
