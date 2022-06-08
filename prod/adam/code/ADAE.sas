/*****************************************************************************\
*  ____                  _
* |  _ \  ___  _ __ ___ (_)_ __   ___
* | | | |/ _ \| '_ ` _ \| | '_ \ / _ \
* | |_| | (_) | | | | | | | | | | (_) |
* |____/ \___/|_| |_| |_|_|_| |_|\___/
* ____________________________________________________________________________
* Sponsor              : Domino
* Study                : Pilot01
* Program              : adae.sas
* Purpose              : Create ADAE dataset
* ____________________________________________________________________________
* DESCRIPTION                                                    
*                                                                   
* Input files:  SDTM.AE
*               ADaM.ADSL
*               SDTM.EX 
*                                                                   
* Output files: ADaM.ADAE                                                  
*                                                                 
* Macros:       None                                                       
*                                                                   
* Assumptions:                                                    
*                                                                   
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*  24MAR2022 |  Srihari Hanumantha  |  Original  
*  07APR2022 |  Dianne Weatherall   |  Updated u_ macro calls to p_ macro calls 
*  12APR2022 |  Dianne Weatherall   |  Updated CQ01NAM from equalling text provided to containing text provided  
* ---------------------------------------------------------------------------- 
\*****************************************************************************/

    
*********;
%init;
*********;


**** USER CODE FOR ALL DATA PROCESSING **;

%let keepvars =STUDYID  SITEID  USUBJID TRTA    TRTAN   AGE     AGEGR1  AGEGR1N RACE    RACEN   SEX     SAFFL   TRTSDT  
TRTEDT  AESTDTC AEENDTC ASTDT   ASTDTF  ASTDY   AENDT   AENDY   ADURN   ADURU   AETERM  AELLT   AELLTCD AEDECOD 
AEPTCD  AEHLT   AEHLTCD AEHLGT  AEHLGTCD        AEBODSYS        AESOC   AESOCCD AESEV   AESER   AESCAN  AESCONG AESDISAB        
AESDTH  AESHOSP AESLIFE AESOD   AEREL   AEACN   AEOUT   AESEQ   TRTEMFL AOCCFL  AOCCSFL AOCCPFL AOCC01FL        AOCC02FL
AOCC03FL        CQ01NAM;

proc sort data=sdtm.ae out=ae;
        by usubjid;
run;
%p_suppadd (inds=ae,domain=AE,outds=aeplus);
/*Merging ADSL with AE to get Key Variables from ADSL*/
proc sort data=adamw.adsl out=adsl;
        by usubjid;
run;
data ae1;
        merge adsl (in=dm) aeplus (in=ae) ;
        by usubjid;
        if ae and dm;

/* Added Actual treatment */
        TRTA=TRT01A;
        TRTAN=TRT01AN;

run;
/*Create numeric AE start/end date and Imputeing if partial dates */
%p_adttm (inds=ae1,
                outds=ae_start,
                isodt=aestdtc,
                adamdt=astdt,
                adamtm=,
                adamdtm=,
                adamdtf=date9,
                adamtmf=,
                adamdtmf=,
                impute=START,
                imputedtp=TRTS);
%p_adttm (inds=ae_start,
                outds=ae_end,
                isodt=aeendtc,
                adamdt=aendt,
                adamtm=,
                adamdtm=,
                adamdtf=date9);

proc format;
        invalue mon 'JAN'=01
                          'FEB'=02
                          'MAR'=03
                          'APR'=04
                          'MAY'=05
                          'JUN'=06
                          'JUL'=07
                          'AUG'=08
                          'SEP'=09
                          'OCT'=10
                          'NOV'=11
                          'DEC'=12
                          ;
quit;
data ae2;
        
        set ae_end;

        syear=input(substr(put(trtsdt,date9.),6,4),best.);
        smonth=input(substr(put(trtsdt,date9.),3,3),mon.);
        sday=input(substr(put(trtsdt,date9.),1,2),best.);

        if length(aestdtc)=4 then do;
                aestyear=input(aestdtc,best.);
                if aestyear lt syear  and aestyear ne .  then   do ;astdt=.; ASTDTF='';
       end;
        end;
        if length(aestdtc)=7 then do;
                aestyear=input(substr(aestdtc,1,4),best.);
                aestmon=input(substr(aestdtc,6),best.);

           if aestyear lt syear  and aestyear ne .  then do; astdt=.;ASTDTF='';
       end;
        end;
        
        
/*Analysis Duration (N)*/
        if astdt ne . and aendt ne . then ADURN=aendt-astdt+1;

        if ADURN eq . then ADURU='DAY';

/*Treatment Emergent Analysis Flag*/

        if  .<trtsdt <= astdt  then trtemfl='Y';
        else trtemfl='N';

/*Customized Query 01 Name*/

/*  If indexw (AEDECOD, 'APPLICATION  DERMATITIS  ERYTHEMA  BLISTER')>0 OR */
/*   (AEBODSYS='SKIN AND SUBC UTANEOUS TISSUE DISORDERS' and AEDECOD not in ('COLD SWEAT', 'HYPERHIDROSIS', 'ALOPECIA'))*/
/*     then CQ01NAM='DERMATOLOGIC EVENTS' ;*/
/*    else CQ01NAM='';*/

  * DW - 12APR2022 - fix CQ01NAM;
  if (index(upcase(aedecod), "APPLICATION") gt 0) or
     (index(upcase(aedecod), "DERMATITIS") gt 0) or
         (index(upcase(aedecod), "ERYTHEMA") gt 0) or
         (index(upcase(aedecod), "BLISTER") gt 0) or
         ((upcase(aebodsys) eq "SKIN AND SUBCUTANEOUS TISSUE DISORDERS") and (upcase(aedecod) not in ("COLD SWEAT","HYPERHIDROSIS","ALOPECIA")))
  then cq01nam = "DERMATOLOGIC EVENTS";



run;
/*Deriving 1st Occurrence of AE Flags*/

%p_occflag (inds = ae2, newflg = aoccfl,  sortby = trtemfl usubjid aebodsys aedecod aeseq, byvar = trtemfl usubjid aebodsys aedecod, firstvar = usubjid,  wherecls = trtemfl eq "Y");
%p_occflag (inds = ae2, newflg = aoccsfl, sortby = trtemfl usubjid aebodsys aedecod aeseq, byvar = trtemfl usubjid aebodsys aedecod, firstvar = aebodsys, wherecls = trtemfl eq "Y");
%p_occflag (inds = ae2, newflg = aoccpfl, sortby = trtemfl usubjid aebodsys aedecod aeseq, byvar = trtemfl usubjid aebodsys aedecod, firstvar = aedecod,  wherecls = trtemfl eq "Y");

/*Deriving 1st Occurrence of SAE Flags*/

%p_occflag (inds = ae2, newflg = aocc01fl,  sortby = trtemfl AESER usubjid  aebodsys aedecod aeseq, byvar = trtemfl AESER usubjid aebodsys aedecod, firstvar = usubjid,  wherecls = trtemfl eq "Y" and AESER eq 'Y');
%p_occflag (inds = ae2, newflg = aocc02fl, sortby = trtemfl AESER usubjid  aebodsys aedecod aeseq, byvar = trtemfl AESER usubjid aebodsys aedecod, firstvar = aebodsys, wherecls = trtemfl eq "Y"  and AESER eq 'Y');
%p_occflag (inds = ae2, newflg = aocc03fl, sortby = trtemfl AESER usubjid  aebodsys aedecod aeseq, byvar = trtemfl AESER usubjid aebodsys aedecod, firstvar = aedecod,  wherecls = trtemfl eq "Y"  and AESER eq 'Y');

proc sort data=ae2;
        by       usubjid aeterm astdt aeseq;
run;

data final;
        set ae2 ;
        by usubjid aeterm astdt aeseq;

/*Analysis Start Relative Day*/
        if astdt ne . and  trtsdt ne . and astdt<trtsdt then astdy = astdt - trtsdt ;
        else if astdt ne . and  trtsdt ne . then astdy = astdt - trtsdt +1;

/*Analysis End Relative Day*/
        if aendt ne . and  trtsdt ne . and aendt<trtsdt then aendy = aendt - trtsdt;
        else if aendt ne . and  trtsdt ne . then aendy = aendt - trtsdt +1;
run;


data adamw.adae (label = "Adverse Event Analysis Dataset");
  retain &keepvars.;
  set final (keep = &keepvars.);

  label
    STUDYID ="Study Identifier"
        SITEID ="Study Site Identifier"
        USUBJID ="Unique Subject Identifier"
        TRTA ="Actual Treatment"
        TRTAN ="Actual Treatment (N)"
        AGE ="Age"
        AGEGR1 ="Pooled Age Group 1"
        AGEGR1N ="Pooled Age Group 1 (N)"
        RACE ="Race"
        RACEN ="Race (N)"
        SEX ="Sex"
        SAFFL ="Safety Population Flag"
        TRTSDT ="Date of First Exposure to Treatment"
        TRTEDT ="Date of Last Exposure to Treatment"
        AESTDTC ="Start Date/Time of Adverse Event"
        AEENDTC ="End Date/Time of Adverse Event"
        ASTDT ="Analysis Start Date"
        ASTDTF ="Analysis Start Date Imputation Flag"
        ASTDY ="Analysis Start Relative Day"
        AENDT ="Analysis End Date"
        AENDY ="Analysis End Relative Day"
        ADURN ="AE Duration (N)"
        ADURU ="AE Duration Units"
        AETERM ="Reported Term for the Adverse Event"
        AELLT ="Lowest Level Term"
        AELLTCD ="Lowest Level Term Code"
        AEDECOD ="Dictionary-Derived Term"
        AEPTCD ="Preferred Term Code"
        AEHLT ="High Level Term"
        AEHLTCD ="High Level Term Code"
        AEHLGT ="High Level Group Term"
        AEHLGTCD ="High Level Group Term Code"
        AEBODSYS ="Body System or Organ Class"
        AESOC ="Primary System Organ Class"
        AESOCCD ="Primary System Organ Class Code"
        AESEV ="Severity/Intensity"
        AESER ="Serious Event"
        AESCAN ="Involves Cancer"
        AESCONG ="Congenital Anomaly or Birth Defect"
        AESDISAB ="Persist or Signif Disability/Incapacity"
        AESDTH ="Results in Death"
        AESHOSP ="Requires or Prolongs Hospitalization"
        AESLIFE ="Is Life Threatening"
        AESOD ="Occurred with Overdose"
        AEREL ="Causality"
        AEACN ="Action Taken with Study Treatment"
        AEOUT ="Outcome of Adverse Event"
        AESEQ ="Sequence Number"
        TRTEMFL ="Treatment Emergent Analysis Flag"
        AOCCFL ="1st Occurrence of Any AE Flag"
        AOCCSFL ="1st Occurrence of SOC Flag"
        AOCCPFL ="1st Occurrence of Preferred Term Flag"
        AOCC01FL ="1st Occurrence of Any SAE Flag"
        AOCC02FL ="1st Occurrence of SAE SOC Flag"
        AOCC03FL ="1st Occurrence of SAE PT Flag"
        CQ01NAM ="Customized Query 01 Name"

  ;

  ;
run;

**** END OF USER DEFINED CODE **;

********;
*%s_scanlog;
********;
