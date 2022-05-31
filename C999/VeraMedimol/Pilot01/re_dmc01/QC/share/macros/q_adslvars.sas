/*****************************************************************************\
*        O                                                                     
*       /                                                                      
*  O---O     _  _ _  _ _  _  _|                                                
*       \ \/(/_| (_|| | |(/_(_|                                                
*        O                                                                     
* ____________________________________________________________________________
* Sponsor              :  Evelo
* Study                :  EDP1815-201
* Analysis             :  Macro to join on ADSL variables onto dataset
* Program              :  q_adslvars.sas
* ____________________________________________________________________________
* DESCRIPTION                                                   
*                                                                   
* Input files:           &dsetin                                        
*                                                                   
* Output files:          &dsetout                                         
*                                                                
* Macros:                                                         
*                                                                   
* Assumptions:                                                    
*                                                                   
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
* 16NOV2020  | Nancy Carpenter  | Copied from EDP1066-001                                    
* ----------------------------------------------------------------------------
* ddmmmyyyy  |   <<name>>       | ..description of change..         
\*****************************************************************************/

*******************************************************************************;
* Macro variables                                                              ;
*******************************************************************************;

%macro q_adslvars(dsetin=,     /* Input dataset */
                   	dsetout=,    /* Output dataset */
                   	mainvars=STUDYID USUBJID SUBJID PSUBJID SITEID SITE COHORT ENRLFL ENRLFN FASFL FASFN SAFFL SAFFN
                	ARMCD ARM ACTARMCD ACTARM TRT01P TR01PLBL TRT01PN TRT01A TR01ALBL TRT01AN TRT02P TR02PLBL
                	TRT02PN TRT02A TR02ALBL TRT02AN TR01SDT TR01STM TR01SDTM TR01EDT TR01ETM TR01EDTM
                	TR02SDT TR02STM TR02SDTM TR02EDT TR02ETM TR02EDTM TRTSDT TRTSTM TRTSDTM TRTEDT TRTETM TRTEDTM SUBTYP  SUBTYPN
					TR01AG1 TR01PG1 TR02AG1 TR02PG1 TR01AG1N TR01PG1N TR02AG1N TR02PG1N ap01SDT AP01EDT ap02SDT AP02EDT , /* main ADSL vars to be included in every data set */
					xtravars=,   /* List of additional ADSL variables required */
                   	sortby=);    /* list of additional variables (excluding SUBJID) for sorting output data set by */

* Get list of ADSL variables required  *;
proc sort data=adam.adsl out=_temp_adsl(keep=subjid &mainvars &xtravars );
   by subjid;
run;
 
proc contents data=_temp_adsl noprint out=_temp_adsl_cont;
run;

%if %length(&sortby)=0 %then %let sortlist=a.subjid;
%if %length(&sortby)>0 %then %let sortlist=a.subjid, a.%sysfunc(tranwrd(%trim(&sortby), %str( ), %str(, a.)));

* Create macro variable list *;
proc sql noprint;
  select distinct "b."!!name into : _temp_adslvars
  separated by ","
  from _temp_adsl_cont
  where upcase(name) ne "SUBJID";

  * Join on variables from ADSL *;
  create table &dsetout as
  select a.*, &_temp_adslvars
  from &dsetin a inner join adam.adsl b on a.subjid=b.subjid
  order by &sortlist;
quit;

* CHECK FOR SUBJECTS NOT IN ADSL *;
proc sql;
 create table notadsl
 as select unique a.subjid 
 from &dsetin a left join adam.adsl b on a.subjid=b.subjid
 where b.studyid=' '
 order by a.subjid;
quit;
data _null_;
   set notadsl;
 PUT "POSSIBLE DATA ISSUE: SUBJECT NOT FOUND IN ADSL " subjid=;
run;


*Tidy up *;
proc datasets lib=work nolist nodetails;
  delete _temp_adsl _temp_adsl_cont;
quit;

%mend q_adslvars;
