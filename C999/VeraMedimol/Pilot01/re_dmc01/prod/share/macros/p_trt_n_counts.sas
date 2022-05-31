/*****************************************************************************\
*        O                                                                     
*       /                                                                      
*  O---O     _  _ _  _ _  _  _|                                                
*       \ \/(/_| (_|| | |(/_(_|                                                
*        O                                                                     
* ____________________________________________________________________________
* Sponsor              :  Evelo
* Study                :  EDP1867-101
* Analysis             :
* Program              :  p_trt_N_counts.sas
* ____________________________________________________________________________
* DESCRIPTION                                                   
*                                                                   
* Input files: adam.adsl                                                  
*                                                                   
* Output files: Global Macro Variables trt1_1 trt1_2  trt1_3 trt1_4  trt1_5 trt1_6 trt1_7 trt1_8
*									   trt2_4 trt2_97 trt3_4 trt3_97 trt4_4 trt4_97
*                                                                
* Macros: None                                                        
*                                                                   
* Assumptions: Creates counts for treatment and group subsets of patient data 
*			   for each treatment period.                                            
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*  26AUG2021  |   Daniil Trunov  | Copied from 1815-201, updated for 1867-101
* ----------------------------------------------------------------------------
*  01SEP2021  |   Daniil Trunov  | Treatment variable for the second period is added.
* ----------------------------------------------------------------------------
*  30NOV2021  | Kaja Najumudeen  | updated the macro to consider the treatment
*             |                  | order as per shell
\*****************************************************************************/


%macro p_trt_N_counts(flag=, trt01var = trt01pn, trt02var = trt02pn);
proc format;
 invalue trt_prd1n
   "Placebo [HV]"              =  1
   "EDP1867 4.5 x 10^10 [HV]"  =  2
   "EDP1867 1.5 x 10^11 [HV]"  =  3
   "Placebo [AD]"              =  7
   "EDP1867 7.5 x 10^11 [AD]"  =  8
   "Placebo [Ps]"              =  9
   "EDP1867 7.5 x 10^11 [Ps]"  = 10
   "Placebo [As]"              = 11
   "EDP1867 7.5 x 10^11 [As]"  = 12
   ;
 invalue trt_prd2n
   "Placebo [HV]"              =  4
   "EDP1867 7.5 x 10^11 [HV]"  =  5
   "EDP1867 1.5 x 10^12 [HV]"  =  6
   ;
run;

%if %bquote(%upcase(&trt01var.))=TR01AG1N & %bquote(%upcase(&trt02var.))=TR02AG1N %then %do;
proc sql noprint;
  create table adsl_trt_cnt_p1 as
    select subtypn, subtyp,1 as period, TR01AG1N,TR01AG1,count(distinct usubjid) as subject_cnt_trt
	from adam.adsl
    where not missing(TR01AG1N)
	group by subtypn,subtyp,TR01AG1N,TR01AG1
	;
  create table adsl_trt_cnt_p2 as
    select subtypn, subtyp,2 as period, TR02AG1N,TR02AG1,count(distinct usubjid) as subject_cnt_trt
	from adam.adsl
    where not missing(TR02AG1N)
	group by subtypn,subtyp,TR02AG1N,TR02AG1
	;
quit;

data adsl_trt_cnt;
  set adsl_trt_cnt_p1(in=p1)
      adsl_trt_cnt_p2(in=p2)
      ;
  if period=1 then do;
    if not missing(TR01AG1) then trtan=input(TR01AG1,trt_prd1n.);
	trta=TR01AG1;
  end;
  else if period=2 then do;
    if not missing(TR02AG1) then trtan=input(TR02AG1,trt_prd2n.);
	trta=TR02AG1;
  end;
  if nmiss(subtypn,trtan)=0 then trt_mac_var=cats("trt",subtypn,"_",trtan);
  call symputx(trt_mac_var,subject_cnt_trt,"G");
run; 
%end;
%else %if %bquote(%upcase(&trt01var.))=TR01PG1N & %bquote(%upcase(&trt02var.))=TR02PG1N %then %do;
proc sql noprint;
  create table adsl_trt_cnt_p1 as
    select subtypn, subtyp,1 as period, TR01PG1N,TR01PG1,count(distinct usubjid) as subject_cnt_trt
	from adam.adsl
    where not missing(TR01PG1N)
	group by subtypn,subtyp,TR01PG1N,TR01PG1
	;
  create table adsl_trt_cnt_p2 as
    select subtypn, subtyp,2 as period, TR02PG1N,TR02PG1,count(distinct usubjid) as subject_cnt_trt
	from adam.adsl
    where not missing(TR02PG1N)
	group by subtypn,subtyp,TR02PG1N,TR02PG1
	;
quit;

data adsl_trt_cnt;
  set adsl_trt_cnt_p1(in=p1)
      adsl_trt_cnt_p2(in=p2)
      ;
  if period=1 then do;
    if not missing(TR01PG1) then trtan=input(TR01PG1,trt_prd1n.);
	trta=TR01PG1;
  end;
  else if period=2 then do;
    if not missing(TR02PG1) then trtan=input(TR02PG1,trt_prd2n.);
	trta=TR02PG1;
  end;
  if nmiss(subtypn,trtan)=0 then trt_mac_var=cats("trt",subtypn,"_",trtan);
  call symputx(trt_mac_var,subject_cnt_trt,"G");
run; 
%end;
%else %do;
/* Create global macro variables with counts for Healthy Volounteers */

/* Placebo 4.5 x 10^10 [HV] */
%global trt1_1;
/* EDP1867 4.5 x 10^10 [HV] */
%global trt1_2;
/* Placebo 1.5 x 10^11 [HV] */
%global trt1_5;
/* EDP1867 1.5 x 10^11 [HV] */
%global trt1_6;
/* Placebo 7.5 x 10^11 [HV] */
%global trt1_3;
/* EDP1867 7.5 x 10^11 [HV] */
%global trt1_4;
/* Placebo 1.5 x 10^12 [HV] */
%global trt1_7;
/* EDP1867 1.5 x 10^12 [HV] */
%global trt1_8;


proc sql noprint;

  select count(distinct usubjid) into: trt1_1
  from adam.adsl
  where cohort="COHORT 1" and &trt01var. eq 1 and &flag. = 'Y';

  select count(distinct usubjid) into: trt1_2
  from adam.adsl
  where cohort="COHORT 1" and &trt01var. eq 2 and &flag. = 'Y';

  select count(distinct usubjid) into: trt1_3
  from adam.adsl
  where cohort="COHORT 1" and &trt02var. eq 3 and &flag. = 'Y';

  select count(distinct usubjid) into: trt1_4
  from adam.adsl
  where cohort="COHORT 1" and &trt02var. eq 4 and &flag. = 'Y';

  select count(distinct usubjid) into: trt1_5
  from adam.adsl
  where cohort="COHORT 2" and &trt01var. eq 5 and &flag. = 'Y';

  select count(distinct usubjid) into: trt1_6
  from adam.adsl
  where cohort="COHORT 2" and &trt01var. eq 6 and &flag. = 'Y';

  select count(distinct usubjid) into: trt1_7
  from adam.adsl
  where cohort="COHORT 2" and &trt02var. eq 7 and &flag. = 'Y';

  select count(distinct usubjid) into: trt1_8
  from adam.adsl
  where cohort="COHORT 2" and &trt02var. eq 8 and &flag. = 'Y';

quit;

/* Iterate through other SUBTYPN values. */
%do i=2 %to 4; 
	/* Create global macro variables with counts for patients with Atopic Dermatitis, Psoriasis or Asthma */
	/* EDP1867 7.5 x 10^11 [AD]/[Ps]/[As] */
	%global trt&i._4;
	/* All Placebo [AD]/[Ps]/[As] */
	%global trt&i._97;

	proc sql;
		select count(distinct usubjid) into: trt&i._4
  		from adam.adsl
  		where cohort= "COHORT "|| put(%sysfunc(sum(&i.,1)), 1.) and &trt01var. eq 4 and &flag. = 'Y';

 		select count(distinct usubjid) into: trt&i._97
  		from adam.adsl
  		where cohort= "COHORT "|| put(%sysfunc(sum(&i.,1)), 1.) and &trt01var. in (1 3 5 7) and &flag. = 'Y';
	quit;
%end;

%end;

%mend p_trt_N_counts;
