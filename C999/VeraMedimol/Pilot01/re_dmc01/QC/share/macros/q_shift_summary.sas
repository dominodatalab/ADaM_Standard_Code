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
* Program              : q_shift_summary.sas                                |
* ____________________________________________________________________________|
* Macro to create shift summary for the given Shift analysis variable         |                                       
*                                                                             |
* Input files:                                                                |
* Macro Parameters                                                            |
* ----------------------------------------------------------------------------|
* indata              = name of the input dataset for which Shift summary     |
*                       is to be reported for the shift variable              |
* where               = where clause to be applied to the dataset in DATA     |
*                       macro parameter                                       |
* shiftvar            = name of the shift variable for which the shift summary|
*                       is required                                           |
* classvars           = list of variable names in the dataset in DATA macro   |
*                       parameter to be used for summary classification       |
* base_value_list     = list of baseline values for which baseline range is   |
*                       reported. Values are pipe[|] delimited                |
* post_base_value_list= list of post-baseline values for which post-baseline  |
*                       range is reported. Values are pipe[|] delimited       |
* rowlabel            = variable name or static value to categorize the       |
*                       summary across different classification as applicable |
* seqid               = number to identify the order for the shift summary    |
* per_for_zero_result = logical value specifying whether percentage to be     |
*                       derived for zero results                              |
* int_for_hundred_per = logical value specifying whether percentage to be     |
*                       integer for full(100%) results                        |
* debug               = logical value specifying whether debug mode is        |
*                       on or off.                                            |
*                                                                             |
* Output files:                                                               |
* Macro Parameters                                                            |
* ----------------------------------------------------------------------------|
* outdata             = name of the output dataset with shift summary         |
*                                                                             |
* Macros: _qc_shift_summary, _qc_gen_quotetoken, _qc_checkvar_create          |                    
*                                                                             |
* Assumptions:                                                                |                                            
*                                                                             |
* ____________________________________________________________________________|
* PROGRAM HISTORY                                                             |
*  09SEP2021  |   Kaja Najumudeen | Original version of the code              |
* ----------------------------------------------------------------------------|
\*****************************************************************************/
%macro q_shift_summary(indata=,where=,shiftvar=,classvars=,base_value_list=, 
post_base_value_list=,rowlabel=,seqid=,outdata=,per_for_zero_result=,
int_for_hundred_per=,debug=)/mindelimiter=' ';
option validvarname=v7 MAUTOSOURCE minoperator;
*----------------------------------------;
* Check for dataset existence            ;
* ---------------------------------------;
%if %bquote(%superq(indata))= %then %do;
  %put %str(UER)ROR: Input dataset name is missing. Macro will exit now from processing;
  %GOTO MSTOP;
%end;
%else %do;
  %if ^ %sysfunc(exist(&indata.)) %then %do;
    %put %str(UER)ROR: Dataset &indata. doesnot exist. Macro will exit now from processing;
    %GOTO MSTOP;
  %end;
  %if %index(&indata.,.) > 0 %then %let data_name=%scan(&indata.,2,.);
  %else %let data_name=&indata.;
%end;

%if %bquote(%superq(classvars))= %then %do;
  %put %str(UER)ROR: CLASSVARS is missing. Macro will exit now from processing;
  %GOTO MSTOP;
%end;
%else %do;
  %let sql_classvars=%sysfunc(translate(&classvars.,%str(,),%str( )));
%end;

%if %bquote(%superq(shiftvar))= %then %do;
  %put %str(UER)ROR: Shift variable shiftvar is missing. Macro will exit now from processing;
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

%if %bquote(%superq(base_value_list)) ^= %then %do;
  %let base_value_list_mod=%sysfunc(translate(&base_value_list.,%str(_),%str( )));
  %q_gen_quotetoken(keyword=&base_value_list.,delim=%str(|),outmvar=bvalQ,preserve=Y);
  %q_gen_quotetoken(keyword=&base_value_list_mod.,delim=%str(|),outmvar=bvalQ_mod,preserve=Y);
  %q_gen_quotetoken(keyword=&base_value_list_mod.,delim=%str(|),outmvar=bval_mod,preserve=Y,quote=N);
  %if &bvalQ_mod_C. ne &bvalQ_C. %then %do;
    %put (UER)RROR: Baseline values list translation is not matching. Please check;
  %end;
%end;

%if %bquote(%superq(post_base_value_list)) ^= %then %do;
  %let post_base_value_list_mod=%sysfunc(translate(&post_base_value_list.,%str(_),%str( )));
  %q_gen_quotetoken(keyword=&post_base_value_list.,delim=%str(|),outmvar=pbvalQ);
  %q_gen_quotetoken(keyword=&post_base_value_list_mod.,delim=%str(|),outmvar=pbvalQ_mod);
  %q_gen_quotetoken(keyword=&post_base_value_list_mod.,delim=%str(|),outmvar=pbval_mod,quote=N);
  %if &pbvalQ_mod_C. ne &pbvalQ_C. %then %do;
    %put (UER)RROR: Post baseline values list translation is not matching. Please check;
  %end;
  data _sfs_pbsvars_gen;
    length _postbase_line_range _postbase_line_range_mod _postbase_line_range_mod_c /*_postbase_line_delimiter*/ $200.;
    %do k=1 %to &pbvalQ_C.;
      _postbase_line_range=&&pbvalQ&k.;
	  _postbase_line_range_mod=translate(&&pbvalQ&k.,"_"," ");
	  _postbase_line_range_mod_c="C_"||strip(_postbase_line_range_mod);
	  output;
	%end;
  run;

  proc sql noprint;
    select distinct _postbase_line_range_mod, _postbase_line_range_mod_c
           into : pbval_mod_orig separated by " ",
	            : pbval_mod_char separated by " "
    from _sfs_pbsvars_gen
    ;
  quit;
%end;

%if %bquote(&per_for_zero_result.) eq %then %let per_for_zero_result=0;
%if %bquote(&per_for_zero_result.) in (y Y yes YES 1) %then %let per_for_zero_result=1;
%if %bquote(&per_for_zero_result.) in (n N no NO 0) %then %let per_for_zero_result=0;

%if %bquote(&int_for_hundred_per.) eq %then %let int_for_hundred_per=1;
%if %bquote(&int_for_hundred_per.) in (y Y yes YES 1) %then %let int_for_hundred_per=1;
%if %bquote(&int_for_hundred_per.) in (n N no NO 0) %then %let int_for_hundred_per=0;

%if %bquote(&debug.) eq %then %let debug=0;
%if %bquote(&debug.) in (y Y yes YES 1) %then %let debug=1;
%if %bquote(&debug.) in (n N no NO 0) %then %let debug=0;

data _sfs_&data_name.;
  set &indata.(where=(not missing(&shiftvar.)));
  new_&shiftvar.=tranwrd(&shiftvar.,"to","#");
run;

proc sql noprint;
  create table _sfs_subject_cnt_for_cvars as
    select &sql_classvars. , count(distinct usubjid) as n
	from _sfs_&data_name.
	where &where.
	group by &sql_classvars.
	order by &sql_classvars.
	;
  create table _sfs_shift_count as
    select &sql_classvars., new_&shiftvar., count(usubjid) as shift_count
	from _sfs_&data_name.
	where &where.
	group by &sql_classvars. , new_&shiftvar.
	order by &sql_classvars.
	;
quit;

data _sfs_subject_cnt_for_cvars;
  %if %bquote(%superq(base_value_list)) ^= %then %do;
    length _base_line_range $200.;
  %end;
  set _sfs_subject_cnt_for_cvars;
  by &classvars.;
  %if %bquote(%superq(base_value_list)) ^= %then %do;
    %do _i_=1 %to &bvalQ_C.;
      _base_line_range_order=&_i_.;
      _base_line_range=&&bvalQ&_i_.;
	  output;
	%end;
  %end;
run;

proc sort data=_sfs_subject_cnt_for_cvars;
  by &classvars. 
  %if %bquote(%superq(base_value_list)) ^= %then %do;
    _base_line_range _base_line_range_order
  %end;
  ;
run;

data _sfs_shift_count;
  length _base_line_range _postbase_line_range $200.;
  set _sfs_shift_count;
  by &classvars.;
  _base_line_range=strip(scan(new_&shiftvar.,1,"#"));
  _postbase_line_range=strip(scan(new_&shiftvar.,2,"#"));
  _postbase_line_range=strip(_postbase_line_range);
  _postbase_line_range_mod=translate(strip(scan(new_&shiftvar.,2,"#")),"_"," ");
  _postbase_line_range_mod_c="C_"||strip(_postbase_line_range_mod);
run;

proc sql noprint;
  select distinct _postbase_line_range_mod, _postbase_line_range_mod_c
         into : pbvars_orig separated by " ",
		      : pbvars_char separated by " "
  from _sfs_shift_count
  ;
quit;

proc sort data=_sfs_shift_count;
  by &classvars. _base_line_range;
run;

proc transpose data=_sfs_shift_count out=_sfs_shift_count_tp let;
  by &classvars. _base_line_range;
  var shift_count;
  id _postbase_line_range;
run;

%if %bquote(%superq(post_base_value_list)) ^= %then %do;
  %q_checkvar_create(data=_sfs_shift_count_tp
                      ,vars=&pbval_mod.
                      ,varstype=1
                      ,create=1
                      ,outdata=_sfs_shift_count_tp1
                      ,debug=&debug.
                      );
%end;
%else %do;
  data _sfs_shift_count_tp1;
    set _sfs_shift_count_tp;
  run;
%end;

data _sfs_shift_data;
  merge _sfs_subject_cnt_for_cvars(in=a)
        _sfs_shift_count_tp1(in=b)
		;
  by &classvars.
  %if %bquote(%superq(base_value_list)) ^= %then %do;
    _base_line_range
  %end;
  ;
  if a and b then _sfs_check="ab";
  if a and not b then _sfs_check="a ";
  if b and not a then _sfs_check="b ";
/*  if avisitn not in (1 2);*/
  %if %bquote(%superq(post_base_value_list)) ^= %then %do;
    array pbval $30 &pbval_mod_orig.;
    array pbvar $30 &pbval_mod_char.;
  %end;
  %else %do;
    array pbval $30 &pbvars_orig.;
    array pbvar $30 &pbvars_char.;
  %end;

  do over pbvar;
    %if &int_for_hundred_per. %then %do;
      if nmiss(pbval,n)=0 then do;
        if pbval=n then pbvar=(put(pbval,5.))||" ("||(put((pbval/n)*100,5.))||"%)";
	    else pbvar=(put(pbval,5.))||" ("||(put((pbval/n)*100,5.1))||"%)";
      end;
	  %if &per_for_zero_result. %then %do;
	    if missing(pbvar) then pbvar=(put(0,5.))||" ("||(put((0/n)*100,5.))||"%)";
	  %end;
	  %else %do;
	    if missing(pbvar) then pbvar=(put(0,5.));
	  %end;
	%end;
	%else %do;
      if nmiss(pbval,n)=0 then pbvar=(put(pbval,5.))||" ("||(put((pbval/n)*100,5.1))||"%)";
	  %if &per_for_zero_result. %then %do;
	    if missing(pbvar) then pbvar=(put(0,5.))||" ("||(put((0/n)*100,5.1))||"%)";
	  %end;
	  %else %do;
	    if missing(pbvar) then pbvar=(put(0,5.));
	  %end;
	%end;
  end;
run;
/*
%if %bquote(%superq(post_base_value_list)) ^= %then %do;
  %let _sfs_cnt_=%sysfunc(countw(&pbval_mod_char.,%str( )));
  %do j=1 %to &_sfs_cnt_.;
    %let _tmp&j=%scan(&pbval_mod_char.,&j,%str());
    %_qc_decimal_align(indata=_sfs_shift_data
                      ,invars=&&_tmp&j
                      ,outvars=
                      ,delimiters=%str(%%%()
                      ,outdata=_sfs_shift_data
                      ,debug=&debug.);
  %end;
%end;
%else %do;
  %let _sfs_cnt_=%sysfunc(countw(&pbvars_char.,%str( )));
  %do j=1 %to &_sfs_cnt_.;
    %let _tmp&j=%scan(&pbvars_char.,&j,%str());
    %_qc_decimal_align(indata=_sfs_shift_data
                      ,invars=&&_tmp&j
                      ,outvars=
                      ,delimiters=%str(%%%()
                      ,outdata=_sfs_shift_data
                      ,debug=&debug.);
  %end;
%end;
*/
data _sfs_scoped_data;
  retain &classvars. n 
  %if %bquote(%superq(base_value_list)) ^= %then %do; 
    _base_line_range_order
  %end;
  _base_line_range
  %if %bquote(%superq(post_base_value_list)) ^= %then %do;
    &pbval_mod_char.
  %end; 
  %else %do;
    &pbvars_char.
  %end;
  ;
  set _sfs_shift_data(in=a)
	  ;
  rowgroup=&rowlabel.;
  seqid=&seqid;
  drop _sfs_check _name_;
run;

proc sort data=_sfs_scoped_data out=_sfs_scoped_data_sort;
  by seqid rowgroup &classvars. 
  %if %bquote(%superq(base_value_list)) ^= %then %do; 
    _base_line_range_order
  %end;
  ;
run;

data &outdata.;
  set _sfs_scoped_data_sort;
  by seqid rowgroup &classvars. 
  %if %bquote(%superq(base_value_list)) ^= %then %do; 
    _base_line_range_order
  %end;
  ;
run;

*------------------------------------------;
* clean the datastep processing            ; 
* -----------------------------------------;
%if ^ &debug. %then %do;
  proc datasets lib=work nodetails noprint;
    delete _sfs_: ;
  quit;
%end;

%MSTOP: ;
%mend q_shift_summary;
