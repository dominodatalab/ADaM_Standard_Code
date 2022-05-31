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
* Program              : q_decimal_align.sas                                |
* ____________________________________________________________________________|
* Macro to decimal align the character variables in the input dataset         | 
*                                                                             |
* Input files:                                                                |
* Macro Parameters                                                            |
* ----------------------------------------------------------------------------|
* indata              = dataset name that requires the character variables    |
*                       to be decimal aligned                                 |
* invars              = blank separated character variable list which requires|
*                       the decimal alignment                                 |
* outvars             = blank separated character variable list storing the   |
*                       decimal aligned information                           |
* delimiters          = pipe separated character list corresponding for the   |
*                       macro parameter VARS which identifies character       |
*                       separator for one or more values where decimal align- |
*                       ment required                                         | 
* debug               = logical value specifying whether debug mode is        |
*                       on or off.                                            |
*                                                                             |
* Output files:                                                               |
* Macro Parameters                                                            |
* ----------------------------------------------------------------------------|
* outdata             = name of the processed dataset for decimal alignment   |
*                                                                             |
* Macros: q_decimal_align, q_gen_quotetoken                               |                    
*                                                                             |
* Assumptions:                                                                |                                            
*                                                                             |
* ____________________________________________________________________________|
* PROGRAM HISTORY                                                             |
*  21SEP2021  |   Kaja Najumudeen | Original version of the code              |
* ----------------------------------------------------------------------------|
\*****************************************************************************/
%macro q_decimal_align(indata=,invars=,outvars=,delimiters=,outdata=,
debug=)/mindelimiter=' ';
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
  %if %index(&indata.,.) > 0 %then %let pdec_data_name=%scan(&indata.,2,.);
  %else %let pdec_data_name=&indata.;
%end;

%if %bquote(%superq(outdata))= %then %do;
  %put %str(UER)ROR: output dataset name is missing. Macro will exit now from processing;
  %GOTO MSTOP;
%end;

%if %bquote(%superq(invars))= %then %do;
  %put %str(UER)ROR: input variable list name is missing. Macro will exit now from processing;
  %GOTO MSTOP;
%end;
%else %do;
  %q_gen_quotetoken(keyword=&invars.,delim=%str( ),outmvar=bvarsQ,preserve=N);
  %q_gen_quotetoken(keyword=&invars.,delim=%str( ),outmvar=bvars,preserve=N,quote=N);
%end;

%if %bquote(%superq(outvars))= %then %do;
  %let p_invars=;
  %do i=1 %to &bvars_C.;
    %let p_invars=&p_invars. var_&i.;
  %end;
  %q_gen_quotetoken(keyword=&p_invars.,delim=%str( ),outmvar=bvarsQ,preserve=N);
  %q_gen_quotetoken(keyword=&p_invars.,delim=%str( ),outmvar=bvars,preserve=N,quote=N);

  %q_gen_quotetoken(keyword=&invars.,delim=%str( ),outmvar=ovarsQ,preserve=N);
  %q_gen_quotetoken(keyword=&invars.,delim=%str( ),outmvar=ovars,preserve=N,quote=N);
%end;
%else %do;
  %q_gen_quotetoken(keyword=&outvars.,delim=%str( ),outmvar=ovarsQ,preserve=N);
  %q_gen_quotetoken(keyword=&outvars.,delim=%str( ),outmvar=ovars,preserve=N,quote=N);
%end;

%if %bquote(%superq(delimiters))= %then %do;
  %let p_delimiters=;
  %do i=1 %to &bvars_C.;
    %let p_delimiters=&p_delimiters. %str(;)|;
  %end;
  %q_gen_quotetoken(keyword=%str(&p_delimiters.),delim=%str(|),outmvar=delQ,preserve=Y);
  %q_gen_quotetoken(keyword=%str(&p_delimiters.),delim=%str(|),outmvar=del,preserve=Y,quote=N);
%end;
%else %do;
  %let p_delimiters=&delimiters.;
  %q_gen_quotetoken(keyword=&p_delimiters.,delim=%str(|),outmvar=delQ,preserve=N);
  %q_gen_quotetoken(keyword=&p_delimiters.,delim=%str(|),outmvar=del,preserve=N,quote=N);
%end;

%if &ovars_C. ne &bvars_C. %then %do;
  %put (UER)RROR: Input and output variable name count not matching. Please check;
  %GOTO MSTOP;
%end;

%if &del_C. ne &bvars_C. %then %do;
  %put (UER)RROR: Input variable name and delimiter count not matching. Please check;
  %GOTO MSTOP;
%end;

%if %bquote(&debug.) eq %then %let debug=0;
%if %bquote(&debug.) in (y Y yes YES 1) %then %let debug=1;
%if %bquote(&debug.) in (n N no NO 0) %then %let debug=0;

%if %bquote(%superq(outvars))= %then %do;
/*  proc format;*/
/*    value $varname*/
/*    %do i=1 %to &bvarsQ_C.;*/
/*      &&bvarsQ&i.    =  "VAR_&i."   */
/*    %end;*/
/*    ;*/
/*  run;*/
  proc contents data=&indata. noprint out=_pdec_contents;
  run;

  proc sort data=_pdec_contents;
    by memname varnum;
  run;

  data _pdec_contents;
    length new_name $32. re_name $100.;
    set _pdec_contents;
    by memname varnum;
    name=upcase(name);
	%do i=1 %to &ovarsQ_C.;
      if strip(name)=strip(&&ovarsQ&i.) then new_name="VAR_&i.";
	%end;
    if cmiss(name,new_name)=0 then re_name=catx("=",name,new_name);
  run;

  data _pdec_contents_meta;
    length renames $32767.;
    set _pdec_contents;
    by memname varnum;
    if cmiss(libname,memname)=0 then indata=catx(".",libname,memname);
    retain renames;
    if first.memname then renames=strip(re_name);
    else renames=strip(renames)||" "||strip(re_name);
    if last.memname then output;
  run;

  filename _pdec_ temp;
  data _null_;
    set _pdec_contents_meta end=eof;
    file _pdec_;
    put "data _pdec_&indata.;";  
    put '  set ' indata '(rename=(' renames '));' ;  
    put 'run;';  
  run;

  %include _pdec_;
  filename _pdec_;
%end;
%else %do;
  data _pdec_&indata.;
    set &indata.;
  run;
%end;

%do j=1 %to &bvars_C.;
  %let var=&&bvars&j.;
  %let newvar=&&ovars&j.;
  %let dlm=&&delQ&j.;
  %if %nrbquote(%superq(dlm)) eq %then %let dlm=" ";
  proc sql noprint;
    select max(countw(&var.,&dlm)) into: dlmcnt
    from _pdec_&indata.;
  quit;

  %let dlmcnt=&dlmcnt;
  %put Delimiter count=&dlmcnt;

  data _pdec_check&j.;
    set _pdec_&indata.;
    bck_&var.=&var.;
    delim=strip(compress(compress(&var.,"1234567890."),&dlm.,"k"))||repeat(" ",&dlmcnt.);
    %do _delop=1 %to &dlmcnt.;
      length delim_&_delop. $1.;
      _temp_var_&_delop.=scan(&var.,&_delop.,&dlm.);
      if index(strip(_temp_var_&_delop.),".") and index(strip(_temp_var_&_delop.),";") eq 0 then do;
        _pdec_frnt_&_delop.=scan(strip(_temp_var_&_delop.),1,".");
        _pdec_trail_&_delop.=scan(strip(_temp_var_&_delop.),2,".");
      end;
      else if index(strip(_temp_var_&_delop.),";") > 0 then do;
        if index(scan(strip(_temp_var_&_delop.),1,";"),".") then do;
          _pdec_frnt_&_delop.=scan(strip(_temp_var_&_delop.),1,".");
          _pdec_trail_&_delop.=scan(strip(_temp_var_&_delop.),2,"."); 
        end;
        else if index(scan(strip(_temp_var_&_delop.),1,";"),".") eq 0 then do;
          _pdec_frnt_&_delop.=scan(scan(strip(_temp_var_&_delop.),1,";"),1,".");
          _pdec_trail_&_delop.=scan(scan(strip(_temp_var_&_delop.),1,";"),2,".");                
        end; 
      end;
      else if index(strip(_temp_var_&_delop.),".") eq 0 then do;
        _pdec_frnt_&_delop.=scan(strip(_temp_var_&_delop.),1,".");
        _pdec_trail_&_delop.=scan(strip(_temp_var_&_delop.),2,".");      
      end;
      array varlst_&_delop. _pdec_frnt_&_delop. _pdec_trail_&_delop.;
      array nvarlst_&_delop. _pdec_len_frnt_&_delop. _pdec_len_trial_&_delop.;
      do over varlst_&_delop.;
        if varlst_&_delop. ne '' then nvarlst_&_delop.=length(strip(varlst_&_delop.));
        else nvarlst_&_delop.=0;
      end;
      delim_&_delop.= substr(delim,&_delop.,1);
    %end;
  run;

  %do _delop=1 %to &dlmcnt.;
    %if &_delop. eq 1 %then %let fullval=n_temp_var_1||delim_&_delop;
    %else %let fullval=&fullval || n_temp_var_&_delop. ||delim_&_delop.;
  %end;
  %put fullval= &fullval;

  proc sql noprint;
    create table _pdec_check&j.1 as 
      select * 
        %do _delop=1 %to &dlmcnt.;
          ,max(_pdec_len_frnt_&_delop.) as maxf_&_delop., max(_pdec_len_trial_&_delop.) as maxt_&_delop.
        %end;
      from _pdec_check&j.;
  quit;

  proc sql noprint;
    select max(length(&var.)) into :maxlen from _pdec_check&j.1;
      %do _delop=1 %to &dlmcnt.;
        select max(maxf_&_delop.-_pdec_len_frnt_&_delop.),max(length(_temp_var_&_delop.))
        into: maxre_&_delop.
        ,: maxtemp_&_delop.
        from _pdec_check&j.1;
      %end;
  quit;

  %do _delop=1 %to &dlmcnt.;
    %if &_delop. eq 1 %then %let lenvaltxt=&&maxre_&_delop;
    %else %let lenvaltxt=&lenvaltxt + &&maxre_&_delop;
  %end;
  %put lenval text= &lenvaltxt;

  %let lenval=%eval(&maxlen. +&lenvaltxt.+1);
  %put Length of &newvar = &lenval. Oldvalue=&maxlen.;

  data _pdec_&indata.(drop=maxf: maxt: _pdec_: n_temp_var: _temp_var: delim:);
    length &newvar. $&lenval..;
    %do _delop=1 %to &dlmcnt.;
      length n_temp_var_&_delop. $%eval(&&maxre_&_delop.+&&maxtemp_&_delop.);
    %end;
    set _pdec_check&j.1;
    %do _delop=1 %to &dlmcnt.;
      n_temp_var_&_delop.=repeat("",(maxf_&_delop.-_pdec_len_frnt_&_delop.))||strip(_temp_var_&_delop.);
    %end;
    &newvar.=&fullval.;
  run;

  data _pdec_dec_chk&j.;
    set _pdec_&indata.;
    length dec_adj_status $10.;
    if compress(&var.) eq compress(bck_&var.) then dec_adj_status="OK"; 
    else dec_adj_status="Not OK"; 
    val=compare(compress(&var.),compress(bck_&var.));
  run;

  proc sql noprint;
    select count(dec_adj_status) into : noobs_dec
      from _pdec_dec_chk&j.
      where upcase(dec_adj_status) eq "NOT OK";
  quit;

  %if %nrbquote(&noobs_dec) eq 0 %then %do;
    %put %str(UN)OTE: Decimal alignment success- no truncation in value;
  %end;
  %else %do;
    %put No of obs failing the check=&noobs_dec;
    %put %str(UE)RROR: Decimal alignment Not success- might have truncation in values;
  %end;
%end;

data &outdata.;
  set _pdec_&indata.;
  drop bck_: ;
  %if %bquote(%superq(outvars))= %then %do;
    drop var_: ;
  %end;
run;
*------------------------------------------;
* clean the datastep processing            ; 
* -----------------------------------------;
%if ^ &debug. %then %do;
  proc datasets lib=work nodetails noprint;
    delete _pdec_: ;
  quit;
%end;

%MSTOP: ;
%mend q_decimal_align;
