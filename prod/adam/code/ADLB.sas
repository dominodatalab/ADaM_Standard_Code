/*****************************************************************************\
*  ____                  _
* |  _ \  ___  _ __ ___ (_)_ __   ___
* | | | |/ _ \| '_ ` _ \| | '_ \ / _ \
* | |_| | (_) | | | | | | | | | | (_) |
* |____/ \___/|_| |_| |_|_|_| |_|\___/
* ____________________________________________________________________________
* Sponsor              : Domino
* Study                : Pilot01
* Program              : adlb.sas
* Purpose              : Create ADLB dataset
* ____________________________________________________________________________
* DESCRIPTION
*
* Input files:  SDTM.LB
*               ADaM.ADSL
*
* Output files: ADaM.ADLB
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

%let keepvars = STUDYID SITEID USUBJID SAFFL TRTA TRTAN LBDTC ADT ATM ADTM ADY ARNDY VISIT VISITNUM AVISIT AVISITN
                PARAM PARAMCD PARAMN PARCAT1 PARCAT1N AVAL AVALC BASE BASEC BASETYPE CHG R2A1LO R2A1HI R2A1DIFF
                CHGIND THRIND BTHRIND DTYPE ALBTRVAL LBNRIND ANRIND BNRIND A1LO A1HI A1DIFF ABLFL ANL01FL ANL02FL ONTRTFL LVOTFL;

* Get variables from ADSL;
data adsl (keep = studyid usubjid subjid siteid saffl trt01a trt01an trtsdt randdt rename = (trt01a = trta trt01an = trtan));
  set adamw.adsl;
run;

* Get unique tests and units for derivation of PARAM;
data tests (keep = lbcat _lbcat lbtestcd lbtest lbstresu);
  set sdtm.lb;

  * Force the missing LBCAT for HBA1C to get the largest PARAMN by forcing LBCAT to be last;
  if (lbcat eq "") then _lbcat = "ZZZ";
  else _lbcat = trim(left(lbcat));
run;

proc sort data = tests;
  by _lbcat lbcat lbtestcd lbtest lbstresu;
run;

data tests;
  set tests;
    by _lbcat lbcat lbtestcd;
  * Choose the last one so that non-missing units take preference over missing units;
  if last.lbtestcd;
run;

data tests;
  set tests;

  length param $ 200;

  * PARAM;
  if (lbstresu eq "")      then param = trim(left(lbtest));
  else if (lbstresu ne "") then param = trim(left(lbtest)) || " (" || trim(left(lbstresu)) || ")";
run;

* Derive PARAMN by sorting on LBCAT and PARAM;
proc sort data = tests;
  by _lbcat lbcat param;
run;

data tests;
  set tests;

  * PARAMN;
  paramn = _n_;
run;

* Merge PARAM onto SDTM.LB;
proc sort data = tests;
  by lbcat lbtestcd;
run;

proc sort data = sdtm.lb out = lb;
  by lbcat lbtestcd;
run;

data lb2;
  merge tests lb;
    by lbcat lbtestcd;
run;

* Derive date/times, parameters;
data lb3 (keep = usubjid visit visitnum lbseq lbdtc adt atm adtm paramcd param paramn parcat1 parcat1n lborres lbstresn lbstresc
                 lbnrind lbornrlo lbornrhi lbstnrlo lbstnrhi);
  set lb2;

  length paramcd parcat1 $ 200;

  * ADT, ATM, ADTM;
  if (length(lbdtc) ge 10) then adt  = input(substr(lbdtc,1,10),e8601da.);
  if (length(lbdtc) ge 16) then adtm = input(substr(lbdtc,1,16),e8601dt.);
  if (adtm ne .)           then atm  = timepart(adtm);

  * PARAMCD, PARCAT1, PARCAT1N;
  paramcd = trim(left(lbtestcd));
  parcat1 = trim(left(lbcat));
  select (upcase(parcat1));
    when ("CHEMISTRY")         parcat1n = 1;
        when ("HEMATOLOGY")        parcat1n = 2;
        when ("OTHER")             parcat1n = 3;
        when ("URINALYSIS")        parcat1n = 4;
        when ("")                  parcat1n = .;
        otherwise put "Check: " parcat1=;
  end;
run;

* Merge with ADSL to derive ADY;
proc sort data = lb3;
  by usubjid;
run;

data lbadsl;
  merge adsl lb3 (in = v);
    by usubjid;
  if v;
run;

* Anlysable flag;
proc sort data = lbadsl;
  by usubjid parcat1n paramn visitnum adt;
run;

data lbanal;
  set lbadsl;
    by usubjid parcat1n paramn visitnum;

  length anl01fl $ 200;

  * ANL01FL;
  if (visitnum in (1,4,5,7,8,9,10,11,12,13)) and last.visitnum then anl01fl = "Y";
run;

data lbaval;
  set lbanal;

  length avalc ontrtfl $ 200;

  * ADY;
  if (adt ne .) and (trtsdt ne .) and (adt ge trtsdt)      then ady = adt - trtsdt + 1;
  else if (adt ne .) and (trtsdt ne .) and (adt lt trtsdt) then ady = adt - trtsdt;

  * ARNDY;
  if (adt ne .) and (randdt ne .) and (adt ge randdt)      then arndy = adt - randdt + 1;
  else if (adt ne .) and (randdt ne .) and (adt lt randdt) then arndy = adt - randdt;

  * AVAL, AVALC;
  if (lbstresn ne .)                                     then aval = lbstresn;
  else if (lbstresn eq .) and (index(lbstresc,"<") gt 0) then aval = input(compress(tranwrd(lbstresc,"<","")),8.);
  else if (lbstresn eq .) and (index(lbstresc,">") gt 0) then aval = input(compress(tranwrd(lbstresc,">","")),8.);

  if (lbstresc ne "") then avalc = trim(left(lbstresc));

  * ANRIND;
  if (lbnrind ne "") then anrind = trim(left(lbnrind));
  if (lborres eq "<0.2") and (lbornrlo = "0.2") then anrind = "LOW";

  * A1LO, A1HI, A1DIFF;
  if (lbstnrlo ne .)             then a1lo = lbstnrlo;
  if (lbstnrhi ne .)             then a1hi = lbstnrhi;
  if (a1lo ne .) and (a1hi ne .) then a1diff = a1hi - a1lo;

  * R2A1LO, R2A1HI;
  if (aval ne .) and (a1lo not in (.,0)) then r2a1lo = aval / a1lo;
  if (aval ne .) and (a1hi not in (.,0)) then r2a1hi = aval / a1hi;

  * ONTRTFL;
  if (visitnum gt 1) and (visitnum le 12) and (anl01fl eq "Y") then ontrtfl = "Y";
run;

* Flag last on-treatment record;
proc sort data = lbaval;
  by ontrtfl usubjid parcat1n paramn adt adtm;
run;

data lblast;
  set lbaval;
    by ontrtfl usubjid parcat1n paramn adt adtm;

  length lvotfl $ 200;

  if last.paramn and (ontrtfl eq "Y") then lvotfl = "Y";
run;

* Baseline (Visit 1);
data lb1base;
  set lblast;

  if (visitnum eq 1) and (aval ne .) then baserec = 1;
run;

proc sort data = lb1base;
  by baserec usubjid parcat1n paramn adt;
run;

data lb1base1;
  set lb1base;
    by baserec usubjid parcat1n paramn;

  length ablfl basetype avisit $ 200;

  * ABLFL, BASETYPE;
  if last.paramn and (baserec eq 1) then ablfl = "Y";
  basetype = "VISIT 1";

  * AVISITN, AVISIT;
  if (ablfl eq "Y") then do;
    avisitn = 3;
    avisit  = "Baseline";
  end;
  else do;
    avisitn = visitnum;
    avisit  = trim(left(propcase(visit)));
  end;
  avisit = tranwrd(avisit,"Ecg","ECG");
run;

proc sort data = lb1base1;
  by usubjid parcat1n paramn adt adtm;
run;

data lb1base2;
  retain base basec bnrind;
  set lb1base1;
    by usubjid parcat1n paramn;

  length basec bnrind $ 200;

  * BASE, BASEC, BNRIND;
  if first.paramn then base = .;
  if (ablfl eq "Y") then base = aval;

  if first.paramn then basec = "";
  if (ablfl eq "Y") then basec = avalc;

  if first.paramn then bnrind = "";
  if (ablfl eq "Y") then bnrind = anrind;
run;

data lbtrval;
  set lb1base2;

  * ALBTRVAL;
  if (aval ne .) and (a1hi ne .) then albtrval1 = aval - (1.5 * a1hi);
  if (aval ne .) and (a1lo ne .) then albtrval2 = (0.5 * a1lo) - aval;
  if (albtrval1 ne .) and (albtrval2 eq .) then albtrval = albtrval1;
  else if (albtrval1 eq .) and (albtrval2 ne .) then albtrval = albtrval2;
  else if (albtrval1 ne .) and (albtrval2 ne .) then albtrval = max(albtrval1, albtrval2);
run;

* Flag the largest LBTRVAL value on-treatment;
proc sort data = lbtrval;
  by ontrtfl usubjid parcat1n paramn albtrval;
run;

data lbtrval2;
  set lbtrval;
    by ontrtfl usubjid parcat1n paramn;

  length anl02fl $ 200;

  if last.paramn and (ontrtfl eq "Y") then anl02fl = "Y";
run;

* Output visit for last on treatment;
data lb1base3;
  set lbtrval2;

  length dtype $ 200;

  if (lvotfl eq "Y") then do;
    output;
        avisitn = 601;
        avisit  = "End of treatment";
        dtype   = "LONTRT";
        anl02fl = "";
        output;
  end;
  else output;
run;

* Baseline (previous visit);
data lb2base;
  set lblast;
  if (anl01fl eq "Y");
run;

proc sort data = lb2base;
  by usubjid parcat1n paramn visitnum;
run;

data lb2base1;
  set lb2base;
    by usubjid parcat1n paramn;

  * Assign a record number within each subject / parameter;
  if first.paramn then rec = 0;
  rec + 1;
run;

* Get post-baseline records;
data post;
  set lb2base1;
    by usubjid parcat1n paramn;
  if first.paramn then delete;

  length basetyp $ 200;

  * BASETYP;
  basetyp = "WEEK " || trim(left(put(input(substr(visit,6),8.),z2.)));
run;

* Get baseline records;
data base;
  set lb2base1;
    by usubjid parcat1n paramn;
  if last.paramn then delete;

  length ablfl $ 200;

  ablfl = "Y";
  rec = rec + 1;
run;

* Set post and baseline together;
data lb2base2;
  set base post;
run;

* Sort so that the post-baseline record appears before the baseline record so that BASETYP can be retained;
proc sort data = lb2base2;
  by usubjid parcat1n paramn rec ablfl;
run;

data lb2base3;
  retain basetype;
  set lb2base2;
    by usubjid parcat1n paramn rec;

  length basetype $ 200;
  if first.rec then basetype = "";
  if (basetyp ne "") then basetype = trim(left(basetyp));
run;

data lb2base4;
  set lb2base3;

  length avisit $ 200;

  * AVISITN, AVISIT;
  if (ablfl eq "Y") then do;
    avisitn = 3;
    avisit  = "Baseline";
  end;
  else do;
    avisitn = visitnum;
    avisit  = trim(left(propcase(visit)));
  end;
  avisit = tranwrd(avisit,"Ecg","ECG");
run;

proc sort data = lb2base4;
  by usubjid parcat1n paramn basetype descending ablfl;
run;

data lb2base5;
  retain base basec bnrind;
  set lb2base4;
    by usubjid parcat1n paramn basetype;

  length basec bnrind $ 200;

  * BASE, BASEC, BNRIND;
  if first.basetype then base = .;
  if (ablfl eq "Y") then base = aval;

  if first.basetype then basec = "";
  if (ablfl eq "Y") then basec = avalc;

  if first.basetype then bnrind = "";
  if (ablfl eq "Y") then bnrind = anrind;
run;

proc sort data = lb2base5;
  by usubjid parcat1n paramn visitnum rec;
run;

* Set different basetypes together;
data lbbase;
  set lb1base3 lb2base5;
run;

data lbchg;
  set lbbase;

  length chgind thrind $ 200;

  * CHG;
  if (aval ne .) and (base ne .) and (ablfl ne "Y") then chg = aval - base;

  * R2A1DIFF;
  if (chg ne .) and (a1diff not in (.,0)) and (basetype ne "VISIT 1") then r2a1diff = chg / a1diff;

  * CHGIND;
  if (basetype ne "VISIT 1") then do;
    if (r2a1diff ne .) and (r2a1diff lt -0.5) then chgind = "LOW";
    else if (r2a1diff gt 0.5)                 then chgind = "HIGH";
        else if (r2a1diff ne .)                   then chgind = "NORMAL";
  end;

  * THRIND;
  if (basetype eq "VISIT 1") then do;
    if (r2a1lo ne .) and (r2a1lo lt 0.5)   then thrind = "LOW";
        else if (r2a1hi gt 1.5)                then thrind = "HIGH";
        else if (r2a1lo ne .) or (r2a1hi ne .) then thrind = "NORMAL";
  end;
run;

proc sort data = lbchg;
  by usubjid parcat1n paramn basetype visitnum;
run;

data lbchg2;
  retain bthrind;
  set lbchg;
    by usubjid parcat1n paramn basetype;

  length bthrind $ 200;

  * BTHRIND;
  if first.basetype then bthrind = "";
  if (ablfl eq "Y") and (basetype eq "VISIT 1") then bthrind = thrind;
run;

proc sort data = lbchg2;
  by usubjid parcat1n paramn basetype avisitn adt;
run;

* ASEQ;
data final;
  set lbchg2;
    by usubjid parcat1n paramn basetype avisitn adt;
  if first.usubjid then aseq = 0;
  aseq + 1;
  if not first.adt then put "Check order: " usubjid= paramcd= avisitn= basetype=;
run;

data adamw.adlb (label = "Laboratory Analysis Dataset");
  retain &keepvars.;
  set final (keep = &keepvars.);

  label
    STUDYID  = "Study Identifier"
    SITEID   = "Study Site Identifier"
    USUBJID  = "Unique Subject Identifier"
    SAFFL    = "Safety Population Flag"
    TRTA     = "Actual Treatment"
    TRTAN    = "Actual Treatment (N)"
    LBDTC    = "Date/Time of Specimen Collection"
    ADT      = "Analysis Date"
    ATM      = "Analysis Time"
    ADTM     = "Analysis Date/Time"
    ADY      = "Analysis Relative Day"
    ARNDY    = "Analysis Relative to Randomization Day"
    VISIT    = "Visit Name"
    VISITNUM = "Visit Number"
    AVISIT   = "Analysis Visit"
    AVISITN  = "Analysis Visit (N)"
    PARAM    = "Parameter"
    PARAMCD  = "Parameter Code"
    PARAMN   = "Parameter (N)"
    PARCAT1  = "Parameter Category 1"
    PARCAT1N = "Parameter Category 1 (N)"
    AVAL     = "Analysis Value"
    AVALC    = "Analysis Value (C)"
    BASE     = "Baseline Value"
    BASEC    = "Baseline Value (C)"
    BASETYPE = "Baseline Type"
    CHG      = "Change from Baseline"
    R2A1LO   = "Ratio to Analysis Range 1 Lower Limit"
    R2A1HI   = "Ratio to Analysis Range 1 Upper Limit"
    R2A1DIFF = "Ratio Change to Analysis Range 1"
    CHGIND   = "Change to Range Indicator"
    THRIND   = "Threshold Indicator"
    BTHRIND  = "Baseline Threshold Indicator"
    DTYPE    = "Derivation Type"
        ALBTRVAL = "Amount Threshold Range"
    LBNRIND  = "Reference Range Indicator"
    ANRIND   = "Analysis Reference Range Indicator"
    BNRIND   = "Baseline Reference Range Indicator"
    A1LO     = "Analysis Range 1 Lower Limit"
    A1HI     = "Analysis Range 1 Upper Limit"
    A1DIFF   = "Analysis Range 1"
    ABLFL    = "Baseline Record Flag"
    ANL01FL  = "Analysis Record Flag 01"
        ANL02FL  = "Analysis Record Flag 02"
    ONTRTFL  = "On Treatment Record Flag"
    LVOTFL   = "Last Value On Treatment Record Flag"
  ;
  format
    adt  date9.
        atm  time5.
        adtm datetime21.
  ;
run;

**** END OF USER DEFINED CODE **;

********;
%s_scanlog;
********;
