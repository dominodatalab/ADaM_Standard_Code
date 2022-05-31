/*****************************************************************************\
*        O                                                                    | 
*       /                                                                     |
*  O---O     _  _ _  _ _  _  _|                                               | 
*       \ \/(/_| (_|| | |(/_(_|                                               | 
*        O                                                                    | 
* ____________________________________________________________________________|
* Sponsor              : Evelo                                                |
* Study                : EDP1867-101                                          |
* Analysis             : validation                                           |
* Program              : q_sumstat.sas                                      |
* ____________________________________________________________________________|
* Macro to create descriptive statistics for the given analysis variable      |                                       
*                                                                             |
* Input files:                                                                |
* Macro Parameters                                                            |
* ----------------------------------------------------------------------------|
* data                = name of the input dataset for which descriptive       |
*                       statistics is to be reported for analysis variable    |
* where               = where clause to be applied to the dataset in DATA     |
*                       macro parameter                                       |
* avar                = name of the analysis variable for which descriptive   |
*                       statistics is required                                |
* byvar               = list of variable names in the dataset in DATA macro   |
*                       parameter to be used in byvar statement               |
* idvar               = variable name whose formatted values is used to form  |
*                       the names of the variables in the output data set     |
* idlabelvar          = variable name whose formatted values is used to form  |
*                       the label of the variables in the output data set     |
* precvar             = variable name (numeric data type) which stores the    |
*                       precision of the decimal of the analysis variable     |
* apply_round         = logical value specifying whether to round up the      |
*                       statistical value as per precision defined in PRECVAR |
* minmax_asper_precvar= logical value specifying whether to display Statistics|
*                       of Min & max values are per precision variable or not |
* custom_stat_snippet = Full absolute path along with the file name where the |
*                       customised if-then clause code snippet resides that is|
*                       to be executed within datastep to adjust the reporting|
*                       of statistics as per tfl reporting requirement        |
* rowlabel            = variable name or static value to categorize the       |
*                       summary across different by groups as applicable      |
* seqid               = number of identify the order for the descriptive      |
*                       summary                                               |
* debug               = logical value specifying whether debug mode is        |
*                       on or off.                                            |
*                                                                             |
* Output files:                                                               |
* Macro Parameters                                                            |
* ----------------------------------------------------------------------------|
* outdata             = name of the output dataset with descriptive statistics|
*                                                                             |
* Macros: _qc_sumstat,_qc_decimal_align                                       |                    
*                                                                             |
* Assumptions:                                                                |                                            
*                                                                             |
* ____________________________________________________________________________|
* PROGRAM HISTORY                                                             |
*  09SEP2021  |   Kaja Najumudeen | Original version of the code              |
* ----------------------------------------------------------------------------|
*  21SEP2021  |   Kaja Najumudeen | updated the decimal alignment by calling  |
*             |                   | the macro _qc_decimal_align               |
* ----------------------------------------------------------------------------|
*  09NOV2021  |   Kaja Najumudeen | fixed the missing values generated note in|
*             |                   | the the log due to mimssing values        |
* ----------------------------------------------------------------------------|
*  08DEC2021  |   Kaja Najumudeen | included macro param minmax_asper_precvar |
*             |                   | to decide the precision to be applied     |
\*****************************************************************************/
%macro q_sumstat(data=, where=, avar=, byvar=, idvar=, idlabelvar=, precvar=,
apply_round=,minmax_asper_precvar=,custom_stat_snippet=,rowlabel=, seqid=, 
outdata=,debug=)/mindelimiter=' ';
option validvarname=v7 MAUTOSOURCE minoperator;
*----------------------------------------;
* Check for dataset existence ;
* ---------------------------------------;
%if %bquote(%superq(data))= %then %do;
  %put %str(UER)ROR: Input dataset name is missing. Macro will exit now from processing;
  %GOTO MSTOP;
%end;
%else %do;
  %if ^ %sysfunc(exist(&data.)) %then %do;
    %put %str(UER)ROR: Dataset &data. doesnot exist. Macro will exit now from processing;
    %GOTO MSTOP;
  %end;
%end;

%if %bquote(%superq(byvar))= %then %do;
  %put %str(UER)ROR: BYVAR is missing. Macro will exit now from processing;
  %GOTO MSTOP;
%end;

%if %bquote(%superq(avar))= %then %do;
  %put %str(UER)ROR: Analysis variable AVAR is missing. Macro will exit now from processing;
  %GOTO MSTOP;
%end;

%if %bquote(%superq(seqid))= %then %do;
  %let seqid=1;
%end;

%if %bquote(%superq(rowlabel))= %then %do;
  %let rowlabel=" ";
%end;

%if %bquote(%superq(outdata))= %then %do;
  %put %str(UER)ROR: output dataset name is missing. Macro will exit now from processing;
  %GOTO MSTOP;
%end;

%if %bquote(&debug.) eq %then %let debug=0;
%if %bquote(&debug.) in (y Y yes YES 1) %then %let debug=1;
%if %bquote(&debug.) in (n N no NO 0) %then %let debug=0;

%if %bquote(&apply_round.) eq %then %let apply_round=0;
%if %bquote(&apply_round.) in (y Y yes YES 1) %then %let apply_round=1;
%if %bquote(&apply_round.) in (n N no NO 0) %then %let apply_round=0;

%if %bquote(&minmax_asper_precvar.) eq %then %let minmax_asper_precvar=1;
%if %bquote(&minmax_asper_precvar.) in (y Y yes YES 1) %then %let minmax_asper_precvar=1;
%if %bquote(&minmax_asper_precvar.) in (n N no NO 0) %then %let minmax_asper_precvar=0;

%if %bquote(%superq(custom_stat_snippet)) ^= %then %do;
  filename _ss_ "&custom_stat_snippet.";
  filename _ssc_ temp;

  data _null_;
    file _ssc_;
    infile _ss_ eof=end;
    input;
    if _n_=1 then put '%macro custom_stat_snippet();';
    put _infile_;
    return;
    end:
    put '%mend custom_stat_snippet;';
  run;
  %include _ssc_;
  filename _ssc_;
  filename _ss_;
%end;

%if %bquote(%superq(precvar)) ^= %then %do; 
  %let precvar_name=&precvar.;
  proc sort data=&data. out=ss_p_&data.(keep=&byvar. &precvar_name.) nodupkey;
    by &byvar. &precvar_name.;
    %if %bquote(%superq(where)) ^= %then %do;
      where &where.;
    %end;
  run;

  data ss_p_&data.;
    set ss_p_&data.;
    by &byvar. &precvar_name.;
  run;
%end;
%if %bquote(%superq(precvar)) = %then %do;
  %let precvar_name=precvar;
%end;

proc sort data=&data. out=ss_&data.;
  by &byvar. 
  %if %bquote(%superq(idvar)) ^= %then %do; 
    &idvar. 
  %end; 
  %if %bquote(%superq(idlabelvar)) ^= %then %do; 
    &idlabelvar. 
  %end; 
  ;
  %if %bquote(%superq(where)) ^= %then %do;
    where &where.;
  %end;
run;

proc means data=ss_&data. noprint;
  var &avar.;
  by &byvar. 
  %if %bquote(%superq(idvar)) ^= %then %do; 
    &idvar. 
  %end; 
  %if %bquote(%superq(idlabelvar)) ^= %then %do; 
    &idlabelvar. 
  %end; 
  ;
  output out=ss_&data._ms n=ss_n mean=ss_mean std=ss_sd median=ss_median min=ss_min max=ss_max;
run;

%if %bquote(%superq(precvar)) ^= %then %do; 
  data ss_&data._ms;
    merge ss_&data._ms(in=main) 
	      ss_p_&data.(in=prc)
		  ;
	by &byvar.;
	if main;
  run;
%end;

data ss_&data._ms;
  set ss_&data._ms;
  by &byvar. 
  %if %bquote(%superq(idvar)) ^= %then %do; 
    &idvar. 
  %end; 
  %if %bquote(%superq(idlabelvar)) ^= %then %do; 
    &idlabelvar. 
  %end; 
  ;
  %if %bquote(%superq(precvar)) ^= %then %do;
    if missing(&precvar_name.) then &precvar_name._new=0;
    else &precvar_name._new=&precvar_name.;
  %end;
  %else %do;
    &precvar_name.=0;
	&precvar_name._new=0;
  %end;
  n=ss_n; mean=ss_mean; sd=ss_sd; median=ss_median; min=ss_min; max=ss_max;
  %if &apply_round. %then %do;
    %if &minmax_asper_precvar. %then %do;
    array orig_stat    ss_mean  ss_sd  ss_median  ss_min  ss_max;
	array rnd_val     rnd_mean rnd_sd rnd_median rnd_min rnd_max (1 2 1 0 0);
    array round_stat      mean     sd     median     min     max;
    do over orig_stat;
	  if not missing(orig_stat) then do;
        if &precvar_name._new ne 0 & round(orig_stat,10**-(&precvar_name._new+rnd_val)) ne 0
        then round_stat=round(orig_stat,10**-(&precvar_name._new+rnd_val));
/*	    if round_stat eq 0 then round_stat=orig_stat;*/
	  end;
	end;
    %end;
    %else %do;
    array orig_stat    ss_mean  ss_sd  ss_median ;
	array rnd_val     rnd_mean rnd_sd rnd_median (1 2 1);
    array round_stat      mean     sd     median ;
    do over orig_stat;
	  if not missing(orig_stat) then do;
        if &precvar_name._new ne 0 & round(orig_stat,10**-(&precvar_name._new+rnd_val)) ne 0
        then round_stat=round(orig_stat,10**-(&precvar_name._new+rnd_val));
	  end;
	end;
    %end;
	if &precvar_name._new ne 0 then n=round(ss_n,1);
  %end;
  %if %bquote(%superq(custom_stat_snippet)) ^= %then %do;
    %custom_stat_snippet();
  %end;
run;

data ss_&data._ms1;
  length res $20 col1 $404;
  set ss_&data._ms;
  seqid=&seqid.;
  ord2=0;  col1=&rowlabel.; call missing(res);                                                                  output;
  ord2=1;  col1='n';	    if nmiss(n)=0      then res=putn(n,"4.0");	                                           else call missing(res);  output;
  ord2=2;  col1='Mean';		if nmiss(mean)=0   then res=putn(mean,"8."||strip(put(&precvar_name._new+1,best.)));   else call missing(res);	output;
  ord2=3;  col1='SD';		if nmiss(sd)=0     then res=putn(sd,"8."||strip(put(&precvar_name._new+2,best.)));     else call missing(res);	output;
  ord2=4;  col1='Median';	if nmiss(median)=0 then res=putn(median,"8."||strip(put(&precvar_name._new+1,best.))); else call missing(res);	output;
  %if &minmax_asper_precvar. %then %do;
  ord2=5;  col1='Min.';		if nmiss(min)=0    then res=putn(Min,"8."||strip(put(&precvar_name._new,best.)));      else call missing(res);	output;
  ord2=6;  col1='Max.';		if nmiss(max)=0    then res=putn(max,"8."||strip(put(&precvar_name._new,best.)));      else call missing(res);	output;
  %end;
  %else %do;
  ord2=5;  col1='Min.';		if nmiss(min)=0    then res=put(Min,best.);      else call missing(res);	output;
  ord2=6;  col1='Max.';		if nmiss(max)=0    then res=put(max,best.);      else call missing(res);	output;
  %end;
run;

%q_decimal_align(indata=ss_&data._ms1
                  ,invars=res
                  ,outvars=
                  ,delimiters=
                  ,outdata=ss_&data._ms1
                  ,debug=&debug.);

proc sort data=ss_&data._ms1;
  by &byvar. seqid ord2 col1;
run;

%if %bquote(%superq(idvar)) ^= %then %do; 
  proc transpose data=ss_&data._ms1 out=ss_&data._mstp;
    by &byvar. seqid ord2 col1;
    var res;
    id &idvar.;
	%if %bquote(%superq(idlabelvar)) ^= %then %do;
      idlabel &idlabelvar.;
	%end;
  run;
%end;
%else %do;
  proc sort data=ss_&data._ms1 out=ss_&data._mstp(drop=ss_: );
    by &byvar. seqid ord2 col1;
  run;
%end;

data &outdata.;
  set ss_&data._mstp;
  by &byvar. seqid ord2 col1;
  %if %bquote(%superq(idvar)) ^= %then %do; 
    drop _name_;
  %end;
run;

*------------------------------------------;
* clean the datastep processing            ; 
* -----------------------------------------;
%if ^ &debug. %then %do;
  proc datasets lib=work nodetails noprint;
    delete ss_: ;
  quit;
%end;

%MSTOP: ;
%mend q_sumstat;
