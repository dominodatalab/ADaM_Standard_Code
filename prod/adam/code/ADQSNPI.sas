/*****************************************************************************\
*  ____                  _
* |  _ \  ___  _ __ ___ (_)_ __   ___
* | | | |/ _ \| '_ ` _ \| | '_ \ / _ \
* | |_| | (_) | | | | | | | | | | (_) |
* |____/ \___/|_| |_| |_|_|_| |_|\___/
* ____________________________________________________________________________
* Sponsor              : Domino
* Study                : Pilot01
* Program              : adqsnpi.sas
* Purpose              : Create ADQSNPI dataset
* ____________________________________________________________________________
* DESCRIPTION
*
* Input files:  SDTM.QS
*               ADaM.ADSL
*
* Output files: ADaM.ADQSNPI
*
* Macros:       None
*
* Assumptions:
*
* ____________________________________________________________________________
* PROGRAM HISTORY
*  31MAY2022 |  Dianne Weatherall   |  Original
* ----------------------------------------------------------------------------
\*****************************************************************************/


*********;
%init;
*********;


**** USER CODE FOR ALL DATA PROCESSING **;

%let keepvars = STUDYID SITEID USUBJID QSSEQ ITTFL EFFFL TRTP TRTPN ADT ADY ARNDY VISIT VISITNUM AVISIT AVISITN
                PARAM PARAMCD PARAMN AVAL BASE CHG DTYPE AWRANGE AWTARGET AWTDIFF AWLO AWHI AWU ABLFL ANL01FL;

* Create dataset with visit windows;
data viswin;
  length awu awrange avisit $ 40;

  awu = "DAYS";

  awtarget = 1;     awlo = -999; awhi = 1;    awrange = "<=1";     avisitn = 3;    avisit = "Baseline";      output;
  awtarget = 14;    awlo = 2;    awhi = 21;   awrange = "2-21";    avisitn = 4;    avisit = "Week 2";        output;
  awtarget = 28;    awlo = 22;   awhi = 35;   awrange = "22-35";   avisitn = 5;    avisit = "Week 4";        output;
  awtarget = 42;    awlo = 36;   awhi = 49;   awrange = "36-49";   avisitn = 7;    avisit = "Week 6";        output;
  awtarget = 56;    awlo = 50;   awhi = 63;   awrange = "50-63";   avisitn = 8;    avisit = "Week 8";        output;
  awtarget = 70;    awlo = 64;   awhi = 77;   awrange = "64-77";   avisitn = 8.1;  avisit = "Week 10 (Tel)"; output;
  awtarget = 84;    awlo = 78;   awhi = 91;   awrange = "78-91";   avisitn = 9;    avisit = "Week 12";       output;
  awtarget = 98;    awlo = 92;   awhi = 105;  awrange = "92-105";  avisitn = 9.1;  avisit = "Week 14 (Tel)"; output;
  awtarget = 112;   awlo = 106;  awhi = 119;  awrange = "106-119"; avisitn = 10;   avisit = "Week 16";       output;
  awtarget = 126;   awlo = 120;  awhi = 133;  awrange = "120-133"; avisitn = 10.1; avisit = "Week 18 (Tel)"; output;
  awtarget = 140;   awlo = 134;  awhi = 147;  awrange = "134-147"; avisitn = 11;   avisit = "Week 20";       output;
  awtarget = 154;   awlo = 148;  awhi = 161;  awrange = "148-161"; avisitn = 11.1; avisit = "Week 22 (Tel)"; output;
  awtarget = 168;   awlo = 162;  awhi = 175;  awrange = "162-175"; avisitn = 12;   avisit = "Week 24";       output;
  awtarget = 182;   awlo = 176;  awhi = 999;  awrange = ">175";    avisitn = 13;   avisit = "Week 26";       output;
run;

* Get variables from ADSL;
data adsl (keep = studyid usubjid subjid siteid ittfl efffl trt01p trt01pn trtsdt randdt rename = (trt01p = trtp trt01pn = trtpn));
  set adamw.adsl;
run;

* Get questionnaire data and filter on NPI;
data qs (keep = usubjid visit visitnum qsseq adt paramcd param paramn qsstresn);
  set sdtm.qs;
  if (qscat eq "NEUROPSYCHIATRIC INVENTORY - REVISED (NPI-X)") and ((index(qstestcd,"S") gt 0) or (qstestcd eq "NPTOT"));

  length paramcd param $ 200;

  * ADT;
  if (length(qsdtc) ge 10) then adt = input(qsdtc,e8601da.);

  * PARAMCD, PARAM, PARAMN;
  paramcd = trim(left(qstestcd));

  select (paramcd);
    when ("NPITM01S")         param = "NPI-X Item A (Delusion) Score";
    when ("NPITM02S")         param = "NPI-X Item B (Hallucination) Score";
    when ("NPITM03S")         param = "NPI-X Item C (Agitation/Aggression) Score";
    when ("NPITM04S")         param = "NPI-X Item D (Depression/Dysphoria) Score";
    when ("NPITM05S")         param = "NPI-X Item E (Anxiety) Score";
    when ("NPITM06S")         param = "NPI-X Item F (Eupohoria/Elation) Score";
    when ("NPITM07S")         param = "NPI-X Item G (Apathy/Indifference) Score";
    when ("NPITM08S")         param = "NPI-X Item H (Disinhibition) Score";
    when ("NPITM09S")         param = "NPI-X Item I (Irritability/Lability) Score";
    when ("NPITM10S")         param = "NPI-X Item J (Aberrant Motor Behavior) Score";
    when ("NPITM11S")         param = "NPI-X Item K (Night-time Behavior) Score";
    when ("NPITM12S")         param = "NPI-X Item L (Appetite/Eating Change) Score";
    when ("NPTOT")            param = "NPI-X (9) Total Score";
    otherwise put "Check: " qstestcd=;
  end;

  select (paramcd);
    when ("NPITM01S")         paramn = 1;
    when ("NPITM02S")         paramn = 2;
    when ("NPITM03S")         paramn = 3;
    when ("NPITM04S")         paramn = 4;
    when ("NPITM05S")         paramn = 5;
    when ("NPITM06S")         paramn = 6;
    when ("NPITM07S")         paramn = 7;
    when ("NPITM08S")         paramn = 8;
    when ("NPITM09S")         paramn = 9;
    when ("NPITM10S")         paramn = 10;
    when ("NPITM11S")         paramn = 11;
    when ("NPITM12S")         paramn = 12;
    when ("NPTOT")            paramn = 13;
    otherwise;
  end;
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

* Check;
data chk1;
  set qswin;
  if (upcase(visit) ne upcase(avisit));
run;

* Check if more than 1 observation is in a window, take the earlier assessment closest to the target window;
data qswin2;
  set qswin;

  * AWTDIFF;
  awtdiff = abs(arndy - awtarget);
run;

proc sort data = qswin2;
  by usubjid paramn avisitn awtdiff adt;
run;

data qstarg;
  set qswin2;
    by usubjid paramn avisitn;

  length anl01fl $ 1;

  if first.avisitn then anl01fl = "Y";
run;

* Get mean of scores for targetted values in the window from Week 4 (AVISITN=5) to Week 24 (AVISITN=12) and set onto other parameters;
proc sort data = qstarg;
  by usubjid paramcd anl01fl;
run;

proc univariate data = qstarg noprint;
  var   qsstresn;
  by    usubjid studyid subjid siteid ittfl efffl trtp trtpn trtsdt randdt paramcd param paramn anl01fl;
  where (paramcd eq "NPTOT" and anl01fl eq "Y" and avisitn ge 5 and avisitn le 12);
  output out = mean
    n    = n
        mean = mean
  ;
run;

data mean2;
  set mean;

  length dtype $ 200;

  * PARAMCD, PARAMN, PARAM;
  paramcd = "NPTOTMN";
  param   = "Mean NPI-X (9) Total (Week 4 to 24)";
  paramn  = 14;

  * AVISITN, AVISIT;
  avisitn = 98;
  avisit  = "Weeks 4-24";

  * DTYPE;
  dtype = "AVERAGE";
run;

data qstargmn;
  set qstarg mean2;
run;

data qsaval;
  set qstargmn;

  * AVAL;
  if (paramcd ne "NPTOTMN")      then aval = qsstresn;
  else if (paramcd eq "NPTOTMN") then aval = mean;
run;

* Baseline;
data qsbase;
  set qsaval;

  if (adt ne .) and (trtsdt ne .) and (adt le trtsdt) and (aval ne .) then baserec = 1;
run;

proc sort data = qsbase;
  by baserec usubjid paramcd adt avisitn;
run;

data qsbase1;
  set qsbase;
    by baserec usubjid paramcd;

  length ablfl $ 200;

  if last.paramcd and (baserec eq 1) then ablfl = "Y";
run;

* Create baseline record for PARAMCD=NPTOTMN;
data qsbase2;
  set qsbase1;
  if (paramcd eq "NPTOT") and (ablfl eq "Y") then do;
    output;
        paramcd = "NPTOTMN";
        param   = "Mean NPI-X (9) Total (Week 4 to 24)";
        paramn  = 14;
        dtype   = "AVERAGE";
        output;
  end;
  else output;
run;

proc sort data = qsbase2;
  by usubjid paramcd avisitn adt visitnum;
run;

data qsbase3;
  retain base;
  set qsbase2;
    by usubjid paramcd;
  if first.paramcd then base = .;
  if (ablfl eq "Y") then base = aval;
run;

data qschg;
  set qsbase3;

  * CHG;
  if (aval ne .) and (base ne .) and (ablfl ne "Y") then chg = aval - base;

  * AWLO and AWHI adjustments;
  if (awlo eq -999) then awlo = .;
  if (awhi eq 999)  then awhi = .;
run;

proc sort data = qschg;
  by usubjid paramcd avisitn adt visitnum;
run;

* ASEQ;
data final;
  set qschg;
    by usubjid paramcd avisitn adt visitnum;
  if first.usubjid then aseq = 0;
  aseq + 1;
  if not first.visitnum then put "Check order: " usubjid= paramcd= avisitn= visitnum=;
run;

data adamw.adqsnpi (label = "NPI-X Item Analysis Dataset");
  retain &keepvars.;
  set final (keep = &keepvars.);

  label
    STUDYID  = "Study Identifier"
    SITEID   = "Study Site Identifier"
    USUBJID  = "Unique Subject Identifier"
    QSSEQ    = "Sequence Number"
    ITTFL    = "Intent-To-Treat Population Flag"
    EFFFL    = "Efficacy Population Flag"
    TRTP     = "Planned Treatment"
    TRTPN    = "Planned Treatment (N)"
    ADT      = "Analysis Date"
    ADY      = "Analysis Relative Day"
    ARNDY    = "Analysis Relative to Randomization Day"
    VISIT    = "Visit Name"
    VISITNUM = "Visit Number"
    AVISIT   = "Analysis Visit"
    AVISITN  = "Analysis Visit (N)"
    PARAM    = "Parameter"
    PARAMCD  = "Parameter Code"
    PARAMN   = "Parameter (N)"
    AVAL     = "Analysis Value"
    BASE     = "Baseline Value"
    CHG      = "Change from Baseline"
    DTYPE    = "Derivation Type"
    AWRANGE  = "Analysis Window Valid Relative Range"
    AWTARGET = "Analysis Window Target"
    AWTDIFF  = "Analysis Window Diff from Target"
    AWLO     = "Analysis Window Beginning Timepoint"
    AWHI     = "Analysis Window Ending Timepoint"
    AWU      = "Analysis Window Unit"
    ABLFL    = "Baseline Record Flag"
    ANL01FL  = "Analysis Record Flag 01"
  ;
  format adt date9.;
run;

**** END OF USER DEFINED CODE **;

********;
*%s_scanlog;
********;
