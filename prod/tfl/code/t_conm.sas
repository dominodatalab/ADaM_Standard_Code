 /*****************************************************************************\
*  ____                  _
* |  _ \  ___  _ __ ___ (_)_ __   ___
* | | | |/ _ \| '_ ` _ \| | '_ \ / _ \
* | |_| | (_) | | | | | | | | | | (_) |
* |____/ \___/|_| |_| |_|_|_| |_|\___/
* ____________________________________________________________________________
* Sponsor              : Domino
* Study                : H2QMCLZZT
* Program              : t_conm.sas
* Purpose              : Create Summary of Concomitant Medications
* ____________________________________________________________________________
* DESCRIPTION                                                    
*                                                                   
* Input files: None
*              
* Output files: t_conm.rtf and t_conm.sas7bdat
*               
* Macros: init scanlog, p_rtfCourier
*         
* Assumptions: 
*
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*  24MAY2022  | Jake Tombeur |  Original version
\*****************************************************************************/

*********;
%include "!DOMINO_WORKING_DIR/config/domino.sas";
*********;

**** USER CODE FOR ALL DATA PROCESSING **;

%let outname    = t_conm;
%let tflid      = t_conm;
%let tflnum      = 14.7.4;

*create Big N macro variables;
data bigN_mac;
  set adam.adsl (where = ((SAFFL = 'Y'))) end = eof;
  retain npl ndum ndumax;
  if _N_ = 1 then do;
    npl = 0;
	ndum = 0;
    ndumax=0;
	end;
  if trt01an = 0 then npl = npl + 1;
  if trt01an = 54 then ndum = ndum + 1;
  if trt01an = 81 then ndumax = ndumax + 1;
  if eof then do;
    call symput('npl', strip(put(npl, 8.)));
    call symput('ndum', strip(put(ndum, 8.)));
	call symput('ndumax', strip(put(ndumax, 8.)));
	end;
run;
*dataset containing big N counts;
proc freq data = adam.adsl (where = ((saffl = 'Y'))) noprint;
  table studyid*trt01an / out= BigN (rename = (count = n trt01an=trtan) drop=percent where = (trtan ne .));
run;

*read in adcm;
proc sort data = adam.adcm (where = (CONCOMFL='Y'))
          out = fromCM;
  by cmdecod cmclas cmstdtc astdt;
run;

*get counts using CMCLAS and CMDECOD. Both variables will need confirmation;
proc sql noprint;
  create table row1_db as
  select TRTaN, count(distinct(usubjid)) as CNT, "Any medication" as rowlbl1 LENGTH = 100, 0 as rowgrp1 
  from fromCM
  group by TRTaN;

  create table db_atc1 as  
  select TRTaN, cmclas, count(distinct(usubjid)) as CNT, "Any medication" as rowlbl1 LENGTH = 100 
  from fromCM
  group by TRTaN, cmclas;

  create table db_pts as  
  select TRTaN, cmclas, cmdecod, count(distinct(usubjid)) as CNT, cmdecod as rowlbl1 LENGTH = 100 
  from fromCM
  group by TRTaN, cmclas, cmdecod;

quit;

*create order variable for CMCLAS terms;
proc sort data = db_atc1 out = db_atc1_unq (keep = cmclas) nodupkey ;
  by cmclas;
run;

*order variable;
data db_soc_ord;
	length cmclas $100;
  set db_atc1_unq;
  rowgrp1 = _n_;
run;

*merge order variable on the db_atc1 and  db_pts datasets;
proc sql noprint;
  create table atc1_fin as
  select a.*, b.rowgrp1
  from db_atc1 as a
  left join db_soc_ord as b
  on a.cmclas=b.cmclas;

  create table pts_fin as
  select a.*, b.rowgrp1
  from db_pts as a
  left join db_soc_ord as b
  on a.cmclas=b.cmclas;
quit;

*set all 3 main datasets;
data all_cm;
	length cmclas $100;
  set row1_db atc1_fin pts_fin;
run;

*calculate percent values;
proc sort data = all_cm out= all_cm_srt;
   by trtan;
run;

data allcm_percent;
   length pct $20 rowlbl1 $100;
   merge all_cm_srt (in=a ) bign (in=b);
   by trtan;
   if a ;

   if cnt ne . and cnt = n then pct  = put(cnt, 3.) ||" ("|| put(cnt/n*100, 3.)||"%)";
   else if (int(log10(round(cnt/n*100, 0.1)))+1) >=2 and cnt ne . and cnt ne n then pct  = put(cnt, 3.) ||" ("|| strip(put(round(cnt/n*100, 0.1), 4.1))||"%)";
   else if (int(log10(round(cnt/n*100, 0.1)))+1) <2 and cnt ne . and cnt ne n then pct  = put(cnt, 3.) ||"  ("|| strip(put(round(cnt/n*100, 0.1), 4.1))||"%)";
   else pct = " 0";

   if index(pct, ".00") > 0 then pct = tranwrd (pct, ".00", "");
run;

proc sort data = allcm_percent out = allcm_percent_srt;
  by rowgrp1 cmdecod rowlbl1  cmclas trtan pct;
run;

proc transpose data = allcm_percent_srt out= alltransp;
  by rowgrp1 cmdecod rowlbl1  cmclas;
  id trtan;
  var PCT;
run;

*include another order variable and create col1-col vars;
data cm_final;
	length cmclas $100;
  attrib rowlbl1   length = $130     label='ATC Level 1 |n Ingredient'
		 col1   length = $100     label="Placebo |n (N=&npl.)   |n n(%)"
         col2   length = $100     label="Xanomeline Low Dose |n (N=&ndum.)   |n n(%)"
		 col3   length = $100     label="Xanomeline High Dose |n (N=&ndumax.)   |n n(%)";
  set alltransp
      db_soc_ord(in=a);

	  rowgrp2=rowgrp1;

	  if a then do; rowlbl1=cmclas; rowgrp2= rowgrp2-0.5; end;

	  if not a and rowgrp1^=0 then rowlbl1="  "!!rowlbl1;

	  col1=_0;
	  col2=_54;
	  col3=_81;

	  *force in zeros where values are missing;
	  array zero {*} col1-col3;
		   do i =1 to dim(zero) ;
		      if zero {i} eq '' and rowgrp1=rowgrp2 then zero {i} = "  0";
			end;

	 *create page variable;
			if rowgrp1<=5 then rowgrp3=1;
			else rowgrp3=2;

	  drop _name_ i _:;
run;
   
*sort before proc report; 

proc sort data=cm_final out=t_conm;
  by rowgrp1 rowgrp2 cmdecod rowlbl1  cmclas;
run;


proc template;
	define style styles.pdfstyle;
		parent = styles.journal;
		replace fonts /
			'TitleFont' = ("Courier new",9pt) /* Titles from TITLE statements */
			'TitleFont2' = ("Courier new",9pt) /* Procedure titles ("The _____ Procedure")*/
			'StrongFont' = ("Courier new",9pt)
			'EmphasisFont' = ("Courier new",9pt)
			'headingEmphasisFont' = ("Courier new",9pt)
			'headingFont' = ("Courier new",9pt) /* Table column and row headings */
			'docFont' = ("Courier new",9pt) /* Data in table cells */
			'footFont' = ("Courier new",9pt) /* Footnotes from FOOTNOTE statements */
			'FixedEmphasisFont' = ("Courier new",9pt)
			'FixedStrongFont' = ("Courier new",9pt)
			'FixedHeadingFont' = ("Courier new",9pt)
			'BatchFixedFont' = ("Courier new",9pt)
			'FixedFont' = ("Courier new",9pt);
	end;
run;



title; footnote;

options orientation = landscape nodate nonumber;
ods pdf file = "/mnt/artifacts/results/&outname..pdf" style = pdfstyle;
ods escapechar = '|';

    /* Titles and footnotes for PROC REPORT */
    title1 justify=l "Protocol: &__PROTOCOL." j=r "Page |{thispage} of |{lastpage}" ;
    title2 justify=l "Population: Safety" ;
    title3 justify=c "Table &tflnum." ;
	title4 justify=c "Summary of Concomitant Medications" ;

    footnote1 justify=l "A medication may be included in more than one ATC level category and appear more than once.";
    footnote2 justify=l "Percentages are based on the number of subjects in the safety population within each treatment group.";
    footnote3 ;
    footnote4 justify=l "Project: &__PROJECT_NAME. Datacut: &__DCUTDTC. File: &__prog_path/&__prog_name..&__prog_ext , %sysfunc(date(),date9.) %sysfunc(time(),tod5.)" ;

    proc report data = t_conm split = '~'
            style = pdfstyle
            style(report) = {width=100%} 
            style(column) = {asis = on just = l}
            style(header) = {bordertopcolor = black bordertopwidth = 3 just = c}
            spanrows;
  
            

            column rowgrp3 rowgrp1 rowgrp2 cmdecod rowlbl1 col1-col3 ;

            define rowgrp1         / order order = data noprint;
			define rowgrp2         / order order = data noprint;
			define rowgrp3         / order order = data noprint;
			define cmdecod         / order = data noprint;

            define rowlbl1      /  order=data
                                    style(header) = {borderbottomcolor = black borderbottomwidth = 3 width = 60% just = l};
            define col1    /  order = data 
                                    style(header) = {borderbottomcolor = black borderbottomwidth = 3 width = 13%} style(column) = {leftmargin = 1% };
            define col2  /  order = data 
                                    style(header) = {borderbottomcolor = black borderbottomwidth = 3 width = 13%} style(column) = {rightmargin = 1%};
            define col3   /  order = data 
                                    style(header) = {borderbottomcolor = black borderbottomwidth = 3 width = 13%} style(column) = {leftmargin = 1% };
            
            compute before rowgrp1;
                line ' ';
            endcomp;

            compute after rowgrp3 / style = {borderbottomcolor = black borderbottomwidth = 3};
                line ' ';
            endcomp;


			break after rowgrp3 / page ;

            
    run;
    
ods pdf close; 
title; footnote;

**** END OF USER DEFINED CODE **;

********;
**%scanlog;
********;
