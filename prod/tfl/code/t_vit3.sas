/*****************************************************************************\
*  ____                  _
* |  _ \  ___  _ __ ___ (_)_ __   ___
* | | | |/ _ \| '_ ` _ \| | '_ \ / _ \
* | |_| | (_) | | | | | | | | | | (_) |
* |____/ \___/|_| |_| |_|_|_| |_|\___/
* ____________________________________________________________________________
* Sponsor              : Domino
* Study                : H2QMCLZZT
* Program              : t_vit3.SAS
* Purpose              : Create Summary of Weight Change from Baseline at End of Treatment
* ____________________________________________________________________________
* DESCRIPTION                                                    
*                                                                   
* Input files: None
*              
* Output files: t_vit3.rtf and t_vit3.sas7bdat
*               
* Macros: init scanlog, p_rtfCourier
*         
* Assumptions: 
*
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*  24MAY2022  | Jake Tombeur  | Original version
\*****************************************************************************/

*********;
%include "!DOMINO_WORKING_DIR/config/domino.sas";
*********;

**** USER CODE FOR ALL DATA PROCESSING **;

%let outname    = t_vit3;
%let tflid      = t_wt_sumchg;
%let tflnum      = 14.7.3;

*create Big N macro variables;
data bigN_mac;
  set adam.adsl (where = ((SAFFL = 'Y'))) end = eof;
  retain npl ndum ndumax;
  if _N_ = 1 then do;
    npl = 0;
	ndum = 0;
    ndumax=0;
	end;
  if TRT01AN = 0 then npl = npl + 1;
  if TRT01AN = 54 then ndum = ndum + 1;
  if TRT01AN = 81 then ndumax = ndumax + 1;
  if eof then do;
    call symput('npl', strip(put(npl, 8.)));
    call symput('ndum', strip(put(ndum, 8.)));
	call symput('ndumax', strip(put(ndumax, 8.)));
	end;
run;

*read in advs(weight obs only);
proc sort data = adam.advs (where = (anl01fl='Y' and paramn =5))
          out = fromVS;
  by PARAMN PARAM TRTAN TRTA  AVISITN AVISIT;
run;

data fromVS1;
  set fromVS;
  if ABLFL = 'Y' then do;
    AVISIT = 'Baseline';
    AVISITN = 0;
    end;
run;

*calculate stats;
proc sort data = fromVS1 out=fromVS_srt;
  by paramn param trtan trta  avisitn avisit;
run;

proc means data = fromVS_srt noprint;
  var aval chg;
  by paramn param trtan trta  avisitn avisit;
  output out = vs_stats (drop = _type_ _freq_) 
               mean(aval)= 
               std(aval) = median(aval)=
               min(aval) = max(aval)=
               mean(chg)= 
               std(chg) = median(chg)= 
               min(chg) = max(chg)=/autoname;
run;

*derive small n counts;
proc sort data = fromVS1 out=fromVS_sn nodupkey;
  by paramn param trtan trta  avisitn avisit subjid;
run;

proc means data = fromVS_sn noprint;
  var aval chg;
  by paramn param trtan trta  avisitn avisit;
  output out = vs_ncount (drop = _type_ _freq_) 
               n(aval) = n(chg)=/autoname;
run;


*extract maximum decimal place from AVAL variable;
data maxdp;
  set fromVS_srt;
  if int(aval)^=aval then 
    do;
      lvar= length(substr(strip(put(aval,best.)),index(strip(put(aval,best.)),".")+1));
      lvar1=lvar+1;
      lvar2=lvar+2;
	  if lvar2>3 then delete;
	  output;
	end;

  else if int(aval)=aval then 
  do;
      lvar=0;
      lvar1=lvar+1;
      lvar2=lvar+2;
	  output;
	end;
run;

proc sql noprint;
  select max(lvar),max(lvar1),max(lvar2)
  into:dps1 trimmed,
      :dps2 trimmed,
      :dps3 trimmed
  from maxdp;
quit;
%put x=&dps1.;
%put x=&dps2.;
%put x=&dps3.;

*get unique avisit;
proc sort data=vs_stats out=avisit_unq nodupkey;
 by avisitn avisit;
run;
*create order variable;
data avisit_ord;
  set avisit_unq;
  ord3=_n_;
  keep avisit ord3;
run;

*merge on main stats datset;
proc sql noprint;

  *merge small n dataset on vs_stats dataset;
  create table vs_stats_main as
  select a.*, b.aval_n, b.chg_n
  from vs_stats as a
  left join vs_ncount as b
  on a.paramn=b.paramn and a.trtan=b.trtan and a.avisitn=b.avisitn;

  *merge dataset containing order variable on main dataset;
  create table vs_stats_ord3 as
  select a.*, b.ord3
  from vs_stats_main as a
  left join avisit_ord as b
  on a.avisit=b.avisit
  order by paramn, ord3, trtan, avisitn;
quit; 

*Format vars for proc report;
data Vitals;
  attrib rowlbl1   length = $100     label='Measure'
         rowlbl2   length = $100     label='Treatment'
		 rowlbl3   length = $100     label='Planned |n Relative time'
		 col1   length = $100     label='n'
         col2   length = $100     label='Mean'
		 col3   length = $100     label='SD'
         col4   length = $100     label='Median'
         col5   length = $100     label='Min.'
         col6   length = $100     label='Max.'
         col7   length = $100     label='n'
         col8   length = $100     label='Mean'
		 col9   length = $100     label='SD'
         col10   length = $100     label='Median'
         col11  length = $100     label='Min.'
         col12   length = $100     label='Max.';
  set vs_stats_ord3(rename=(ord3=rowgrp3)) ;


  *Concatente Big Ns on treatment ;
  if TRTAN = 0 then do; rowlbl2 = strip(TRTA)||' (N='||strip(put(&npl., 8.))||')'; rowgrp2=1; end;
  else if TRTAN = 54 then do; rowlbl2 = strip(TRTA)||' (N='||strip(put(&ndum., 8.))||')'; rowgrp2=2; end;
  else if TRTAN = 81 then do; rowlbl2 = strip(TRTA)||' (N='||strip(put(&ndumax., 8.))||')'; rowgrp2=3; end;


  *format decimal places using max-decimal macro variables;
  dcount=0;
  col1  = put(aval_n, 2.);
  col2  = strip(putn(aval_mean,cats('12.',dcount+&dps2.)));
  col3  = strip(putn(aval_stddev,cats('12.',dcount+&dps3.)));
  col4  = strip(putn(aval_median,cats('12.',dcount+&dps2.)));
  col5  = strip(putn(aval_min,cats('12.',dcount+&dps1.)));
  col6 = strip(putn(aval_max,cats('12.',dcount+&dps1.)));

  if avisitn>0 then col7  = put(chg_n, 2.);*chg should be missing for baseline records;
  col8  = strip(putn(chg_mean,cats('12.',dcount+&dps2.)));
  col9  = strip(putn(chg_stddev,cats('12.',dcount+&dps3.)));
  col10  = strip(putn(chg_median,cats('12.',dcount+&dps2.)));
  col11  = strip(putn(chg_min,cats('12.',dcount+&dps1.)));
  col12 = strip(putn(chg_max,cats('12.',dcount+&dps1.)));

  rowlbl1 = param;
  rowlbl3= avisit;
  page=paramn;
  rowgrp1=paramn;
 

  if aval_n < 3 then call missing(col2, col3, col4);
  else if aval_n = 3 then call missing(col3);

  if chg_n < 3 then call missing(col8, col9, col10);
  else if chg_n = 3 then call missing(col9);
 
  keep rowlbl: col: page rowgrp1 rowgrp2 rowgrp3;
run;

*rename chg variables and set under aval values;
proc sort data=vitals(drop=col1-col6) out=vitals_chg(rename=(col7=col1 col8=col2 col9=col3 col10=col4 col11=col5 col12=col6));
  by rowlbl1 rowlbl2;
run;

*set both datasets;
data Vitals1;
  set vitals(in=a drop=col7-col12)
      vitals_chg(in=b);

	  *order both sections(aval and chg) according to shell; 
	  if b then do; rowgrp4=2; rowlbl1="Weight change from Baseline"; end;
	  else if a then rowgrp4=1;

	  proc sort;
	  by rowgrp1 rowgrp4 rowgrp2 rowgrp3;
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
	title4 justify=c "Summary of Weight Change from Baseline at End of Treatment" ;

    footnote1 justify=l "SD = Standard deviation.";
    footnote2 justify=l "End of treatment is the last on-treatment visit (i.e. on or before Week 24 visit).";
    footnote3 ;
    footnote4 justify=l "Project: &__PROJECT_NAME. Datacut: &__DCUTDTC. File: &__prog_path/&__prog_name..&__prog_ext , %sysfunc(date(),date9.) %sysfunc(time(),tod5.)" ;

    proc report data = vitals1 split = '~'
            style = pdfstyle
            style(report) = {width=100%} 
            style(column) = {asis = on just = l}
            style(header) = {bordertopcolor = black bordertopwidth = 3 just = c}
            spanrows;
  
            

            column rowgrp1 rowgrp4 rowlbl1 rowgrp2 rowlbl2  rowgrp3 rowlbl3 col1- col6 page;

            define rowgrp1         / order order = data noprint;
			define rowgrp2         / order order = data noprint;
			define rowgrp3         / order order = data noprint;
			define rowgrp4         / order order = data noprint;
			define page         / order order = data noprint;
            define rowlbl1      / order order=data
                                    style(header) = {borderbottomcolor = black borderbottomwidth = 3 width = 10%};
            define rowlbl2    / order  order=data
                                    style(header) = {borderbottomcolor = black borderbottomwidth = 3 width = 20%} style(column) = {leftmargin = 5%};
            define rowlbl3     / order  order=data
                                    style(header) = {borderbottomcolor = black borderbottomwidth = 3 width = 14%} style(column) = {leftmargin = 3.5%};
            define col1    /  order = data 
                                    style(header) = {borderbottomcolor = black borderbottomwidth = 3 width = 4%} style(column) = {leftmargin = 1% };
            define col2  /  order = data 
                                    style(header) = {borderbottomcolor = black borderbottomwidth = 3 width = 6%} style(column) = {rightmargin = 1% just=d};
            define col3   /  order = data 
                                    style(header) = {borderbottomcolor = black borderbottomwidth = 3 width = 6%} style(column) = {leftmargin = 1%  just=d};
			define col4   /  order = data 
                                    style(header) = {borderbottomcolor = black borderbottomwidth = 3 width = 6%} style(column) = {rightmargin = 1%  just=d};
			define col5   /  order = data 
                                    style(header) = {borderbottomcolor = black borderbottomwidth = 3 width = 7%} style(column) = {rightmargin = 2%  just=d};
			define col6   /  order = data 
                                    style(header) = {borderbottomcolor = black borderbottomwidth = 3 width = 6%} style(column) = {rightmargin = 2%  just=d};
            
            compute before rowgrp2;
                line ' ';
            endcomp;

            compute after rowgrp1 / style = {borderbottomcolor = black borderbottomwidth = 3};
                line ' ';
            endcomp;


			break after rowgrp1 / page ;

            
    run;
    
ods pdf close; 
title; footnote;

**** END OF USER DEFINED CODE **;

********;
**%scanlog;
********;
