/*****************************************************************************\
*  ____                  _
* |  _ \  ___  _ __ ___ (_)_ __   ___
* | | | |/ _ \| '_ ` _ \| | '_ \ / _ \
* | |_| | (_) | | | | | | | | | | (_) |
* |____/ \___/|_| |_| |_|_|_| |_|\___/
* ____________________________________________________________________________
* Sponsor              : Domino
* Study                : H2QMCLZZT
* Program              : adae.sas
* Purpose              : Create qc ADCM dataset
* ____________________________________________________________________________
* DESCRIPTION
*
* Input files:  SDTM.CM
*               ADaMqc.ADSL
*
*
* Output files: ADaMqc.ADCM
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

%let keepvars =STUDYID  SITEID  USUBJID TRTA    TRTAN   AGE     AGEGR1  AGEGR1N RACE    RACEN   SEX     SAFFL   TRTSDT
TRTEDT  CMSTDTC CMENDTC ASTDT   ASTDY   AENDT   AENDY   CMTRT   CMDECOD CMCLAS  CMINDC  CMDOSE  CMDOSU  CMDOSFRQ
CMROUTE CMSEQ   CONCOMFL        PREFL   AOCC01FL        AOCC02FL        AOCC03FL;

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

proc sort data=sdtm.cm out=cm;
        by usubjid;
run;

/*Merging suppcm with cm*/
%p_suppadd (inds=cm,domain=cm,outds=cmplus);

/*Merging ADSL with CM to get Key Variables from ADSL*/
proc sort data=adamqc.adsl out=adsl;
        by usubjid;
run;
data cm1;
        merge adsl (in=dm) cmplus (in=cm) ;
        by usubjid;
        if cm and dm;

/* Added Actual treatment */
        TRTA=TRT01A;
        TRTAN=TRT01AN;

run;
/*Create numeric CM start/end date  */
%p_adttm (inds=cm1,
                outds=cm_start,
                isodt=cmstdtc,
                adamdt=astdt,
                adamtm=,
                adamdtm=,
                adamdtf=date9);
%p_adttm (inds=cm_start,
                outds=cm_end,
                isodt=cmendtc,
                adamdt=aendt,
                adamtm=,
                adamdtm=,
                adamdtf=date9);

data cm2;

        set cm_end;
/*Analysis Start Relative Day*/
        if astdt ne . and  trtsdt ne . and astdt<trtsdt then astdy = astdt - trtsdt ;
        else if astdt ne . and  trtsdt ne . then astdy = astdt - trtsdt +1;

/*Analysis End Relative Day*/
        if aendt ne . and  trtsdt ne . and aendt<trtsdt then aendy = aendt - trtsdt;
        else if aendt ne . and  trtsdt ne . then aendy = aendt - trtsdt +1;

/*Concomitant Medication Flag*/

        syear=input(substr(put(trtsdt,date9.),6,4),best.);
        smonth=input(substr(put(trtsdt,date9.),3,3),mon.);
        sday=input(substr(put(trtsdt,date9.),1,2),best.);

        if length(CMENDTC)=4 then cmenyear=input(cmendtc,best.);

        if length(cmendtc)=7 then do;
                cmenyear=input(substr(cmendtc,1,4),best.);
                cmenmon=input(substr(cmendtc,6),best.);
        end;

        if cmendtc ='' or aendy>=1 then CONCOMFL = 'Y';
        else if cmenyear>=syear and cmenmon >=smonth and cmenmon ne . then CONCOMFL = 'Y';
        else if cmenyear>=syear and cmenmon =. and cmenyear ne . then CONCOMFL = 'Y';
        else CONCOMFL='N';

        if CONCOMFL='N' then PREFL ='Y';
        else PREFL='N';

run;
/*Deriving 1st Occurrence of CM Flags*/

%p_occflag (inds = cm2, newflg = AOCC01FL,  sortby =  concomfl usubjid cmclas cmdecod cmseq, byvar =  concomfl usubjid cmclas cmdecod, firstvar = usubjid,  wherecls =  concomfl eq "Y");
%p_occflag (inds = cm2, newflg = AOCC02FL, sortby =  concomfl usubjid cmclas cmdecod cmseq, byvar =  concomfl usubjid cmclas cmdecod, firstvar = cmclas, wherecls =  concomfl eq "Y");
%p_occflag (inds = cm2, newflg = AOCC03FL, sortby =  concomfl usubjid cmclas cmdecod cmseq, byvar =  concomfl usubjid cmclas cmdecod, firstvar = cmdecod,  wherecls =  concomfl eq "Y");


proc sort data=cm2 out=final;
        by studyid usubjid cmtrt astdt cmseq;
run;


data adamqc.adcm (label = "Concomitant Medications Analysis Dataset");
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
        CMSTDTC ="Start Date/Time of Medication"
        CMENDTC ="End Date/Time of Medication"
        ASTDT ="Analysis Start Date"
        ASTDY ="Analysis Start Relative Day"
        AENDT ="Analysis End Date"
        AENDY ="Analysis End Relative Day"
        CMTRT ="Reported Name of Drug, Med, or Therapy"
        CMDECOD ="Standardized Medication Name"
        CMCLAS ="Medication Class"
        CMINDC ="Indication"
        CMDOSE ="Dose per Administration"
        CMDOSU ="Dose Units"
        CMDOSFRQ ="Dosing Frequency per Interval"
        CMROUTE ="Route of Administration"
        CMSEQ ="Sequence Number"
        CONCOMFL ="Concomitant Medication Flag"
        PREFL ="Prior Medication Flag"
        AOCC01FL ="1st Occurrence of Any Con Med Flag"
        AOCC02FL ="1st Occurrence of Ther Class Flag"
        AOCC03FL ="1st Occurrence of Ingredient Flag"


  ;

  ;
run;

**** END OF USER DEFINED CODE **;

********;
*%s_scanlog;
********;
