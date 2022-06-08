/*****************************************************************************\
*  ____                  _
* |  _ \  ___  _ __ ___ (_)_ __   ___
* | | | |/ _ \| '_ ` _ \| | '_ \ / _ \
* | |_| | (_) | | | | | | | | | | (_) |
* |____/ \___/|_| |_| |_|_|_| |_|\___/
* ____________________________________________________________________________
* Sponsor              : C999
* Study                : PILOT01
* Program              : t_vit1.SAS
* Purpose              : Create Summary of Vital Signs at Baseline and End of Treatment
* ____________________________________________________________________________
* DESCRIPTION                                                    
*                                                                   
* Input files: None
*              
* Output files: t_vit1.rtf and t_vit1.sas7bdat
*               
* Macros: init scanlog u_pop p_align p_mcrAddPageVar p_rtfCourier
*         
* Assumptions: 
*
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*  23MAY2022             | Ugo Anozie          | Original version
\*****************************************************************************/

*********;
%include "!DOMINO_WORKING_DIR/config/domino.sas";
*********;

**** USER CODE FOR ALL DATA PROCESSING **;
%let outname    = t_vit1;
%let tflid      = 14.7.1;

*create Big N macro variables;
data bigN_mac;
  set adamw.adsl (where = ((SAFFL = 'Y'))) end = eof;
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

*read in advs;
proc sort data = adamw.advs (where = (anl01fl='Y' and paramn in(1,2,3)))
          out = fromVS;
  by PARAMN PARAM atpt TRTAN TRTA  AVISITN AVISIT;
run;

data fromVS1;
  set fromVS;
  if ABLFL = 'Y' then do;
    AVISIT = 'Baseline';
    AVISITN = 0;
    end;
run;

*calculate stats and n counts;
proc sort data = fromVS1 out=fromVS_srt;
  by PARAMN PARAM atpt TRTAN TRTA  AVISITN AVISIT;
run;

proc means data = fromVS_srt noprint;
  var AVAL;
  by PARAMN PARAM atpt TRTAN TRTA  AVISITN AVISIT;
  output out = vs_stats (drop = _type_ _freq_) n = n mean = mean std = std median = median min = min max = max;
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

*get unique ATPT;
proc sort data=vs_stats out=atpt_unq nodupkey;
 by atpt;
run;
*create order variable;
data atpt_ord;
  set atpt_unq;
  ord3=_n_;
  keep atpt ord3;
run;
 
*merge on main stats datset;
proc sql noprint;
  create table vs_stats_ord3 as
  select a.*, b.ord3
  from vs_stats as a
  left join atpt_ord as b
  on a.atpt=b.atpt
  order by paramn, ord3, trtan, avisitn;
quit; 


*Format vars for proc report;
data Vitals;
  attrib rowlbl1   length = $200     label='Measure'
         rowlbl2   length = $200     label='Position'
         rowlbl3   length = $200     label='Treatment'
         rowlbl4   length = $200     label='Planned |n Relative time'
		 col1   length = $200     label='n'
         col2   length = $200     label='Mean'
		 col3   length = $200     label='SD'
         col4   length = $200     label='Median'
         col5   length = $200     label='Min.'
         col6   length = $200     label='Max.';
  set vs_stats_ord3(rename=(ord3=rowgrp3)) ;


  *Concatente Big Ns on treatment ;
  if TRTAN = 0 then do; rowlbl3 = strip(TRTA)||' (N='||strip(put(&npl., 8.))||')'; rowgrp2=1; end;
  else if TRTAN = 54 then do; rowlbl3 = strip(TRTA)||' (N='||strip(put(&ndum., 8.))||')'; rowgrp2=2; end;
  else if TRTAN = 81 then do; rowlbl3 = strip(TRTA)||' (N='||strip(put(&ndumax., 8.))||')'; rowgrp2=3; end;


  *format decimal places using max-decimal macro variables;
  dcount=0;
  col1  = put(n, 2.);
  col2  = strip(putn(mean,cats('12.',dcount+&dps2.)));
  col3  = strip(putn(std,cats('12.',dcount+&dps3.)));
  col4  = strip(putn(median,cats('12.',dcount+&dps2.)));
  col5  = strip(putn(min,cats('12.',dcount+&dps1.)));
  col6 = strip(putn(max,cats('12.',dcount+&dps1.)));

  rowlbl1 = param;
  rowlbl2 = atpt;
  rowlbl4= avisit;
  page=paramn;
  rowgrp1=paramn;
 

  if n < 3 then call missing(col2, col3, col4);
  else if n = 3 then call missing(col3);
 
  keep rowlbl: col: page rowgrp1 rowgrp2 rowgrp3;
run;


/*data tflw.t_vit1;*/
/*    set vitals;*/
/*	drop page;*/
/*run;*/

/* Create rtf output */
%p_rtfCourier();
title; footnote;

options orientation = landscape nodate nonumber;
ods rtf file = "&__env_runtime.&__delim.prod&__delim.tfl&__delim.output&__delim.&outname..rtf" style = rtfCourier ;
ods escapechar = '|';

    /* Titles and footnotes for PROC REPORT */
    title1 justify=l "Protocol: CDISCPILOT01" j=r "Page |{thispage} of |{lastpage}" ;
    title2 justify=l "Population: Safety" ;
    title3 justify=c "Table &tflid. Summary of Vital Signs at Baseline and End of Treatment" ;

    footnote1 justify=l "SD = Standard deviation. BP= Blood pressure.";
    footnote2 justify=l "End of treatment is the last on-treatment visit (i.e. on or before Week 24 visit).";
    footnote3 ;
    footnote4 justify=l "Source: &__full_path, %sysfunc(date(),date9.) %sysfunc(time(),tod5.)" ;

    proc report data = vitals split = '~'
            style = rtfCourier
            style(report) = {width=100%} 
            style(column) = {asis = on just = l}
            style(header) = {just = c}
            spanrows;
  
            

            column rowgrp1 rowlbl1 rowgrp3 rowlbl2 rowgrp2  rowlbl3 rowlbl4 col1- col6 page;

            define rowgrp1         / order order = data noprint;
			define rowgrp2         / order order = data noprint;
			define rowgrp3         / order order = data noprint;
			define page         / order order = data noprint;
            define rowlbl1      / order order=data
                                    style(header) = {borderbottomcolor = black borderbottomwidth = 2 width = 15%};
            define rowlbl2    / order  order=data
                                    style(header) = {borderbottomcolor = black borderbottomwidth = 2 width = 15%} style(column) = {leftmargin = 1%};
            define rowlbl3     / order  order=data
                                    style(header) = {borderbottomcolor = black borderbottomwidth = 2 width = 15%} style(column) = {leftmargin = 1%};
            define rowlbl4   /  order = data 
                                    style(header) = {borderbottomcolor = black borderbottomwidth = 2 width = 15%} style(column) = {leftmargin = 1% vjust=bottom};
            define col1    /  order = data 
                                    style(header) = {borderbottomcolor = black borderbottomwidth = 2 width = 4%} style(column) = {leftmargin = 0.5% vjust=bottom};
            define col2  /  order = data 
                                    style(header) = {borderbottomcolor = black borderbottomwidth = 2 width = 6%} style(column) = {leftmargin = 1% vjust=bottom};
            define col3   /  order = data 
                                    style(header) = {borderbottomcolor = black borderbottomwidth = 2 width = 6%} style(column) = {leftmargin = 1% vjust=bottom just=d};
			define col4   /  order = data 
                                    style(header) = {borderbottomcolor = black borderbottomwidth = 2 width = 6%} style(column) = {leftmargin = 1% vjust=bottom};
			define col5   /  order = data 
                                    style(header) = {borderbottomcolor = black borderbottomwidth = 2 width = 7%} style(column) = {rightmargin = 2% vjust=bottom just=d};
			define col6   /  order = data 
                                    style(header) = {borderbottomcolor = black borderbottomwidth = 2 width = 6%} style(column) = {rightmargin = 2% vjust=bottom just=d};
            
            compute before rowgrp2;
                line ' ';
            endcomp;

            compute after rowgrp1 / style = {borderbottomcolor = black borderbottomwidth = 2};
                line ' ';
            endcomp;


			break after rowgrp1 / page ;

            
    run;
    
ods rtf close; 
title; footnote;

**** END OF USER DEFINED CODE **;

********;
**%scanlog;
********;
