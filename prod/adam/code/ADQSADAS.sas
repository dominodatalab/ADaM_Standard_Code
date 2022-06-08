/*****************************************************************************\
*  ____                  _
* |  _ \  ___  _ __ ___ (_)_ __   ___
* | | | |/ _ \| '_ ` _ \| | '_ \ / _ \
* | |_| | (_) | | | | | | | | | | (_) |
* |____/ \___/|_| |_| |_|_|_| |_|\___/
* ____________________________________________________________________________
* Sponsor              : Domino
* Study                : Pilot01
* Program              : adqsadas.sas
* Purpose              : Create ADQSADAS dataset
* ____________________________________________________________________________
* DESCRIPTION
*
* Input files:  SDTM.QS
*               ADaM.ADSL
*
* Output files: ADaM.ADQSADAS
*
* Macros:       None
*
* Assumptions:
*
* ____________________________________________________________________________
* PROGRAM HISTORY
*  23MAY2022 |  Dianne Weatherall   |  Original
* ----------------------------------------------------------------------------
\*****************************************************************************/


*********;
%init;
*********;


**** USER CODE FOR ALL DATA PROCESSING **;

%let keepvars = STUDYID SITEID USUBJID ITTFL EFFFL TRTP TRTPN QSSEQ ADT ADY ARNDY VISIT VISITNUM AVISIT AVISITN
                PARAM PARAMCD PARAMN AVAL BASE CHG DTYPE AWRANGE AWTARGET AWTDIFF AWLO AWHI AWU ABLFL ANL01FL;

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
  set adamw.adsl;
run;

* Get questionnaire data and filter on ALZHEIMERS DISEASE ASSESSMENT SCALE;
data qs (keep = usubjid visit visitnum qsseq adt paramcd param paramn qsstresn);
  set sdtm.qs;
  if (qscat eq "ALZHEIMER'S DISEASE ASSESSMENT SCALE");

  length paramcd param $ 200;

  * ADT;
  if (length(qsdtc) ge 10) then adt = input(qsdtc,e8601da.);

  * PARAMCD, PARAM, PARAMN;
  paramcd = trim(left(qstestcd));

  select (paramcd);
    when ("ACITM01")       param = "Word Recall Task";
    when ("ACITM02")       param = "Naming Objects And Fingers";
    when ("ACITM03")       param = "Delayed Word Recall";
    when ("ACITM04")       param = "Commands";
    when ("ACITM05")       param = "Constructional Praxis";
    when ("ACITM06")       param = "Ideational Praxis";
    when ("ACITM07")       param = "Orientation";
    when ("ACITM08")       param = "Word Recognition";
    when ("ACITM09")       param = "Attention/Visual Search Task";
    when ("ACITM10")       param = "Maze Solution";
    when ("ACITM11")       param = "Spoken Language Ability";
    when ("ACITM12")       param = "Comprehension Of Spoken Language";
    when ("ACITM13")       param = "Word Finding Difficulty";
    when ("ACITM14")       param = "Recall of Test Instructions";
    when ("ACTOT")         param = "ADAS-Cog (11) Subscore";
    otherwise put "Check: " qstestcd=;
  end;

  select (paramcd);
    when ("ACITM01")       paramn = 1;
    when ("ACITM02")       paramn = 2;
    when ("ACITM03")       paramn = 3;
    when ("ACITM04")       paramn = 4;
    when ("ACITM05")       paramn = 5;
    when ("ACITM06")       paramn = 6;
    when ("ACITM07")       paramn = 7;
    when ("ACITM08")       paramn = 8;
    when ("ACITM09")       paramn = 9;
    when ("ACITM10")       paramn = 10;
    when ("ACITM11")       paramn = 11;
    when ("ACITM12")       paramn = 12;
    when ("ACITM13")       paramn = 13;
    when ("ACITM14")       paramn = 14;
    when ("ACTOT")         paramn = 15;
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

* Get sum of scores for targetted values in the window and merge onto the PARAMCD="ACTOT" record to check values;
proc sort data = qstarg;
  by usubjid avisitn anl01fl;
run;

* Get parameters across;
proc transpose data = qstarg out = trtarg prefix = _;
  var qsstresn;
  id  paramcd;
  by  usubjid avisitn anl01fl;
  where anl01fl eq "Y";
run;

data sum (keep = usubjid avisitn anl01fl paramcd n sum summax);
  set trtarg;

  length paramcd $ 200;

  paramcd = "ACTOT";
  sum     = sum(_acitm01,_acitm02,_acitm04,_acitm05,_acitm06,_acitm07,_acitm08,_acitm11,_acitm12,_acitm13,_acitm14);
  n       = n(_acitm01,_acitm02,_acitm04,_acitm05,_acitm06,_acitm07,_acitm08,_acitm11,_acitm12,_acitm13,_acitm14);

  * Maximum score per item;
  if (_acitm01 eq .) then _max01 = 10;
  if (_acitm02 eq .) then _max02 = 5;
  if (_acitm04 eq .) then _max04 = 5;
  if (_acitm05 eq .) then _max05 = 5;
  if (_acitm06 eq .) then _max06 = 5;
  if (_acitm07 eq .) then _max07 = 8;
  if (_acitm08 eq .) then _max08 = 12;
  if (_acitm11 eq .) then _max11 = 5;
  if (_acitm12 eq .) then _max12 = 5;
  if (_acitm13 eq .) then _max13 = 5;
  if (_acitm14 eq .) then _max14 = 5;

  * Sum maximum scores of missing items;
  if (n ne 11) then summax = sum(_max01,_max02,_max04,_max05,_max06,_max07,_max08,_max11,_max12,_max13,_max14);
run;

data qssum;
  merge sum qstarg;
    by usubjid avisitn anl01fl paramcd;
run;

* Check if >30% of items (>=4) are missing and assign total to the sum, adjusted to maintain the full scale;
data qsaval;
  set qssum;

  * AVAL;
  if (paramcd ne "ACTOT") then aval = qsstresn;
  else if (paramcd eq "ACTOT") then do;
    if (n eq 11)     then aval = sum;
        else if (n ge 8) then aval = sum * 70 / (70 - summax);
  end;
run;

* Check differences in SDTM QSSTRESN and ADaM AVAL for QSSTRESN;
data chk2;
  set qsaval;
  if (qsstresn ne aval);
run;

* Get unique subjects and create a record for each visit;
data groupds (keep = studyid subjid siteid usubjid trtp trtpn randdt trtsdt ittfl efffl paramcd param paramn anl01fl);
  set qsaval;
    by usubjid;
  if (paramcd eq "ACTOT") and (anl01fl eq "Y");
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

  awtarget = 1;     awlo = -999; awhi = 1;    awrange = "<=1";     avisitn = 3;   avisit = "Baseline";   output;
  awtarget = 56;    awlo = 2;    awhi = 84;   awrange = "2-84";    avisitn = 8;   avisit = "Week 8";     output;
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

* Baseline;
data qsbase;
  set qsall;

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

proc sort data = qsbase1;
  by usubjid paramcd avisitn adt;
run;

data qsbase2;
  retain base;
  set qsbase1;
    by usubjid paramcd;
  if first.paramcd then base = .;
  if (ablfl eq "Y") then base = aval;
run;

* LOCF;
data qslocf;
  retain avallocf visitlocf visitnumlocf adylocf adtlocf arndylocf qsseqlocf;
  length visitlocf $ 200;
  set qsbase2;
    by usubjid paramcd;

  if first.paramcd then do;
    avallocf     = .;
        visitlocf    = "";
        visitnumlocf = .;
        adtlocf      = .;
        adylocf      = .;
        arndylocf    = .;
        qsseqlocf    = .;
  end;

  if (anl01fl eq "Y") then do;
    if (aval ne .)     then avallocf     = aval;
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
    if (paramcd eq "ACTOT") and (aval eq .) and (avallocf ne .) then do;
      aval  = avallocf;
          dtype = "LOCF";
    end;
    if (paramcd eq "ACTOT") and (visit eq "") and (visitlocf ne "") then do;
      visit  = visitlocf;
          dtype  = "LOCF";
    end;
    if (paramcd eq "ACTOT") and (visitnum eq .) and (visitnumlocf ne .) then do;
      visitnum  = visitnumlocf;
          dtype     = "LOCF";
    end;
    if (paramcd eq "ACTOT") and (adt eq .) and (adtlocf ne .) then do;
      adt   = adtlocf;
          dtype = "LOCF";
    end;
    if (paramcd eq "ACTOT") and (ady eq .) and (adylocf ne .) then do;
      ady   = adylocf;
          dtype = "LOCF";
    end;
    if (paramcd eq "ACTOT") and (arndy eq .) and (arndylocf ne .) then do;
      arndy = arndylocf;
          dtype = "LOCF";
    end;
    if (paramcd eq "ACTOT") and (qsseq eq .) and (qsseqlocf ne .) then do;
      qsseq   = qsseqlocf;
          dtype = "LOCF";
    end;
  end;
  if (awtdiff eq .) and (arndy ne .) and (awtarget ne .) then awtdiff = abs(arndy - awtarget);
run;

data qschg;
  set qslocf2;

  * CHG;
  if (aval ne .) and (base ne .) and (ablfl ne "Y") then chg = aval - base;

  * AWLO and AWHI adjustments;
  if (awlo eq -999) then awlo = .;
  if (awhi eq 999)  then awhi = .;
run;

proc sort data = qschg;
  by usubjid paramcd avisitn adt;
run;

* ASEQ;
data final;
  set qschg;
    by usubjid paramcd avisitn adt;
  if first.usubjid then aseq = 0;
  aseq + 1;
  if not first.adt then put "Check order: " usubjid= paramcd= avisitn= visitnum=;
run;

data adamw.adqsadas (label = "ADAS-Cog Analysis Dataset");
  retain &keepvars.;
  set final (keep = &keepvars.);

  label
    STUDYID  = "Study Identifier"
        SITEID   = "Study Site Identifier"
    USUBJID  = "Unique Subject Identifier"
    ITTFL    = "Intent-To-Treat Population Flag"
    EFFFL    = "Efficacy Population Flag"
    TRTP     = "Planned Treatment"
    TRTPN    = "Planned Treatment (N)"
        QSSEQ    = "Analysis Date"
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
