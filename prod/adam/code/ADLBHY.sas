/*****************************************************************************\
*  ____                  _
* |  _ \  ___  _ __ ___ (_)_ __   ___
* | | | |/ _ \| '_ ` _ \| | '_ \ / _ \
* | |_| | (_) | | | | | | | | | | (_) |
* |____/ \___/|_| |_| |_|_|_| |_|\___/
* ____________________________________________________________________________
* Sponsor              : Domino
* Study                : Pilot01
* Program              : adlbhy.sas
* Purpose              : Create ADLBHY dataset
* ____________________________________________________________________________
* DESCRIPTION                                                    
*                                                                   
* Input files:  ADaM.ADSL, ADLB
*                                                                   
* Output files: ADaM.ADLBHY
*                                                                 
* Macros:       None                                                       
*                                                                   
* Assumptions:                                                    
*                                                                   
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*  02JUN2022 |  Dianne Weatherall   |  Original  
* ---------------------------------------------------------------------------- 
\*****************************************************************************/

    
*********;
** Setup environment including libraries for this reporting effort;
%include "!DOMINO_WORKING_DIR/config/domino.sas";
*********;


**** USER CODE FOR ALL DATA PROCESSING **;

%let keepvars = STUDYID SITEID USUBJID SAFFL TRTA TRTAN ADT ADTM ADY VISIT VISITNUM AVISIT AVISITN 
                PARAM PARAMCD PARAMN AVAL AVALC BASE BASEC R2A1LO R2A1HI SHIFT1 A1LO A1HI ABLFL ANL01FL ONTRTFL LVOTFL CRIT1 CRIT1FL;

* Get variables from ADSL;
data adsl (keep = studyid usubjid subjid siteid saffl trt01a trt01an trtsdt randdt rename = (trt01a = trta trt01an = trtan));
  set adamw.adsl;
run;

* Get data from ADLB;
data adlb (keep = usubjid adt adtm atm ady visit visitnum avisit avisitn r2a1lo r2a1hi a1lo a1hi anl01fl ontrtfl lvotfl 
                  paramn paramcd param aval avalc ablfl base basec crit1 crit1fl);
  set adamw.adlb;
  if (paramcd in ("ALT","AST","BILI")) and (basetype eq "VISIT 1");

  length crit1 crit1fl $ 200;

  * PARAMN;
  select (paramcd);
    when ("ALT")    paramn = 1;
	when ("AST")    paramn = 2;
	when ("BILI")   paramn = 3;
	otherwise put "Check: " paramcd=;
  end;

  if (r2a1hi ne .) then crit1 = "R2A1HI>1.5";
  if (r2a1hi gt 1.5)                        then crit1fl = "Y";
  else if (r2a1hi ne .) and (r2a1hi le 1.5) then crit1fl = "N";
run;

* Derive TRANSHI, BILIHI and HYLAW parameters;
proc sort data = adlb;
  by usubjid avisitn;
run;

proc transpose data = adlb out = trlb prefix = hi_;
  var crit1fl;
  id  paramcd;
  by  usubjid avisitn;
run;

* Merge back onto data;
data adhi;
  merge trlb (keep = usubjid avisitn hi_alt hi_ast hi_bili) adlb;
    by usubjid avisitn;
run;

data adhy;
  set adhi;
    by usubjid avisitn;

  if last.avisitn then do;
    output;
    paramn   = 4;
	paramcd  = "TRANSHI";
	param    = "Elevated Transaminase";
	aval     = .;
	base     = .;
	basec    = "";
	r2a1lo   = .;
	r2a1hi   = .;
	a1lo     = .;
	a1hi     = .;
	visitnum = .;
	visit    = "";
	adtm     = .;
	adt      = .;
	atm      = .;
	ady      = .;
	crit1    = "";
	crit1fl  = "";
	if (hi_alt eq "Y") or (hi_ast eq "Y")    then avalc = "Y";
	else if (hi_alt ne "") or (hi_ast ne "") then avalc = "N";
	output;
	paramn   = 5;
	paramcd  = "BILIHI";
	param    = "Elevated Bilirubin";
	aval     = .;
	base     = .;
	basec    = "";
	r2a1lo   = .;
	r2a1hi   = .;
	a1lo     = .;
	a1hi     = .;
	visitnum = .;
	visit    = "";
	adtm     = .;
	adt      = .;
	atm      = .;
	ady      = .;
	crit1    = "";
	crit1fl  = "";
	if (hi_bili eq "Y")     then avalc = "Y";
	else if (hi_bili ne "") then avalc = "N";
	output;
	paramn   = 6;
	paramcd  = "HYLAW";
	param    = "Hys Law";
	aval     = .;
	base     = .;
	basec    = "";
	r2a1lo   = .;
	r2a1hi   = .;
	a1lo     = .;
	a1hi     = .;
	visitnum = .;
	visit    = "";
	adtm     = .;
	adt      = .;
	atm      = .;
	ady      = .;
	crit1    = "";
	crit1fl  = "";
	if ((hi_alt eq "Y") or (hi_ast eq "Y")) and (hi_bili eq "Y")   then avalc = "Y";
	else if ((hi_alt ne "") or (hi_ast ne "")) and (hi_bili ne "") then avalc = "N";
	output;
  end;
  else output;
run;

* Merge with ADSL;
proc sort data = adhy;
  by usubjid;
run;

data adhyadsl;
  merge adsl adhy (in = v);
    by usubjid;
  if v;
run;

* Baseline;
proc sort data = adhyadsl;
  by usubjid paramn avisitn;
run;

data hybase1;
  retain hybasec;
  set adhyadsl;
    by usubjid paramn;

  length hybasec $ 200;

  if first.paramn then hybasec = "";
  if (ablfl eq "Y") then hybasec = avalc;
run;

data hybase2;
  set hybase1;

  * BASEC;
  if (hybasec ne "") then basec = trim(left(hybasec));
run;

data hyshift;
  set hybase2;

  length shift1 $ 200;

  * SHIFT1;
  if (ablfl ne "Y") and (paramcd in ("TRANSHI","BILIHI","HYLAW")) then do;
    if (avalc ne "") and (basec eq avalc)      then shift1 = "No Change";
    else if (avalc ne "") and (basec ne avalc) then shift1 = "Change";
  end;
run;

proc sort data = hyshift;
  by usubjid paramn avisitn;
run;

* ASEQ;
data final;
  set hyshift;
    by usubjid paramn avisitn;
  if first.usubjid then aseq = 0;
  aseq + 1;
  if not first.avisitn then put "Check order: " usubjid= paramn= avisitn=;
run;

data adamw.adlbhy (label = "Laboratory Hy Law Analysis Dataset");
  retain &keepvars.;
  set final (keep = &keepvars.);

  label
    STUDYID  = "Study Identifier"
    SITEID   = "Study Site Identifier"
    USUBJID  = "Unique Subject Identifier"
    SAFFL    = "Safety Population Flag"
    TRTA     = "Actual Treatment"
    TRTAN    = "Actual Treatment (N)"
    ADT      = "Analysis Date"
    ADTM     = "Analysis Date/Time"
    ADY      = "Analysis Relative Day"
    VISIT    = "Visit Name"
    VISITNUM = "Visit Number"
    AVISIT   = "Analysis Visit"
    AVISITN  = "Analysis Visit (N)"
    PARAM    = "Parameter"
    PARAMCD  = "Parameter Code"
    PARAMN   = "Parameter (N)"
    AVAL     = "Analysis Value"
    AVALC    = "Analysis Value (C)"
    BASE     = "Baseline Value"
    BASEC    = "Baseline Value (C)"
    R2A1LO   = "Ratio to Analysis Range 1 Lower Limit"
    R2A1HI   = "Ratio to Analysis Range 1 Upper Limit"
    SHIFT1   = "Shift 1"
    A1LO     = "Analysis Range 1 Lower Limit"
    A1HI     = "Analysis Range 1 Upper Limit"
    ABLFL    = "Baseline Record Flag"
    ANL01FL  = "Analysis Record Flag 01"
    ONTRTFL  = "On Treatment Record Flag"
    LVOTFL   = "Last Value On Treatment Record Flag"
    CRIT1    = "Analysis Criterion 1"
    CRIT1FL  = "Criterion 1 Evaluation Result Flag"
  ;
  format 
    adt  date9.
	adtm datetime21.
  ;
run;

**** END OF USER DEFINED CODE **;

********;
*%s_scanlog;
********;
