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
* Program              : q_data_combine.sas                                 |
* ____________________________________________________________________________|
* Macro to combine the input dataset                                          | 
*                                                                             |
* Input files:                                                                |
* Macro Parameters                                                            |
* ----------------------------------------------------------------------------|
* inlib               = library name that contains the dataset to be combined |
* datas               = blank separated dataset name. Can be one or two level |
*                       dataset name. Can also support like clause operator   |
* byvars              = list of primary key variables in DATAS. Used when     |
*                       comb_type is setby mergeby                            |
* comb_type           = set     --> concatenate the dataset                   |
*                       setby   --> interleaf the data sets                   |
*                       mergeby --> merge the data sets by byvars             |
* debug               = logical value specifying whether debug mode is        |
*                       on or off.                                            |
*                                                                             |
* Output files:                                                               |
* Macro Parameters                                                            |
* ----------------------------------------------------------------------------|
* outdata             = name of the processed combined dataset                |
*                                                                             |
* Macros: q_data_combine, q_gen_quotetoken                                |                    
*                                                                             |
* Assumptions:                                                                |                                            
*                                                                             |
* ____________________________________________________________________________|
* PROGRAM HISTORY                                                             |
*  21SEP2021  |   Kaja Najumudeen | Original version of the code              |
* ----------------------------------------------------------------------------|
\*****************************************************************************/
%macro q_data_combine(inlib=,datas=,byvars=,comb_type=,outdata=,
debug=)/mindelimiter=' ';
option validvarname=v7 MAUTOSOURCE minoperator;

*----------------------------------------;
* Check for dataset existence            ;
* ---------------------------------------;
%if %bquote(%superq(outdata))= %then %do;
  %put %str(UER)ROR: output dataset name is missing. Macro will exit now from processing;
  %GOTO MSTOP;
%end;

%if %bquote(&comb_type.) eq %then %let comb_type=1;
%if %bquote(&comb_type.) ne %then %let comb_type=%sysfunc(lowcase(&comb_type.));
%if %bquote(&comb_type.) in (set 1) %then %let comb_type=1;
%if %bquote(&comb_type.) in (setby 2) %then %let comb_type=2;
%if %bquote(&comb_type.) in (mergeby 3) %then %let comb_type=3;

%if &comb_type. in (2 3) and %bquote(%superq(byvars))= %then %let comb_type=1;
%if &comb_type. in (1) and %bquote(%superq(byvars))^= %then %let comb_type=2;

%if %bquote(&debug.) eq %then %let debug=0;
%if %bquote(&debug.) in (y Y yes YES 1) %then %let debug=1;
%if %bquote(&debug.) in (n N no NO 0) %then %let debug=0;

%let datas=%sysfunc(strip(&datas.));
%if %bquote(%superq(inlib))= & %bquote(%superq(datas))= %then %do;
  %put %str(UER)ROR: Input dataset name and input library is missing. Macro will exit now from processing;
  %GOTO MSTOP;
%end;
%else %if %bquote(%superq(inlib))= & %bquote(%superq(datas)) ^= %then %do;
  %let inlib=work;
%end;
%if %bquote(%superq(inlib)) ^= & %bquote(%superq(datas)) ^= %then %do;
  %let inlib=%upcase(&inlib.);
  %if %sysfunc(substr(lowcase(&datas.),1,4))=like %then %do;
    proc sql noprint;
	  create table _dtc_tablemeta as
      select * from from dictionary.tables
      where upcase(libname)=%upcase("&inlib.") and upcase(MEMNAME) %upcase(&datas.)
      ;
	  create table _dtc_columnmeta as
      select * from from dictionary.columns
      where upcase(libname)=%upcase("&inlib.") and upcase(MEMNAME) %upcase(&datas.)
      ;
    quit;
  %end;
  %else %do;
    %q_gen_quotetoken(keyword=&datas.,delim=%str( ),outmvar=idatasQ,preserve=N);
    %q_gen_quotetoken(keyword=&datas.,delim=%str( ),outmvar=idatas,preserve=N,quote=N);
    proc sql noprint;
	  create table _dtc_tablemeta as
      select * from dictionary.tables
      where
	    %do p=1 %to &idatasQ_C.;
            %if &p.^=1 %then %do;
              or
			%end;
              (upcase(libname)="%sysfunc(ifc(%index(&&idatas&p.,.)>0,%upcase(%scan(&&idatas&p.,1,.)),&inlib.))" and 
              upcase(memname)="%sysfunc(ifc(%index(&&idatas&p.,.)>0,%upcase(%scan(&&idatas&p.,2,.)),&&idatas&p.))")
		%end;
      ;
	  create table _dtc_columnmeta as
      select * from dictionary.columns
      where
	    %do p=1 %to &idatasQ_C.;
            %if &p.^=1 %then %do;
              or
			%end;
              (upcase(libname)="%sysfunc(ifc(%index(&&idatas&p.,.)>0,%upcase(%scan(&&idatas&p.,1,.)),&inlib.))" and 
              upcase(memname)="%sysfunc(ifc(%index(&&idatas&p.,.)>0,%upcase(%scan(&&idatas&p.,2,.)),&&idatas&p.))")
		%end;
      ;
	quit;
  %end;
%end;
%else %if %bquote(%superq(inlib)) ^= & %bquote(%superq(datas)) = %then %do;
  %let inlib=%upcase(&inlib.);
  proc sql noprint;
    create table _dtc_tablemeta as
    select * from from dictionary.tables
    where upcase(libname)=%upcase("&inlib.") 
    ;
	create table _dtc_columnmeta as
    select * from from dictionary.columns
    where upcase(libname)=%upcase("&inlib.")
    ;
  quit;
%end;

data _dtc_tablemeta;
  length memid $32.;
  set _dtc_tablemeta;
  indata=catx(".",libname,memname);
  memid="_DTC_MEM"||strip(put(_n_,best.));
run;

proc sort data=_dtc_columnmeta;
  by name type length memname;
run;

data _dtc_columnmeta;
  set _dtc_columnmeta;
  by name type length memname;
  retain difference 0;
  if first.name then difference=0;
  if first.type then difference=difference+1;
run;

proc sql noprint;
  create table _dtc_diff_dtype as
    select distinct name,type,memname
    from _dtc_columnmeta 
    where name in (select distinct name from _dtc_columnmeta where difference ne 1)
    ;
  select strip(put(nobs,best.)) into : _difobs_
    from dictionary.tables 
    where upcase(libname)="WORK" and lowcase(memname)=lowcase("_dtc_diff_dtype")
    ;
quit;

%if &_difobs_. ne 0 %then %do;
  %put %str(UER)ROR: Difference in data type in the input datasets. Macro will exit now from processing;
  %GOTO MSTOP;
%end;

proc sql noprint;
  create table _dtc_varattrib as
    select distinct name,varnum,type,max(length) as namelen
    from _dtc_columnmeta
    group by name
    order by varnum
    ;
quit;

data _dtc_varattrib;
  length attrib $32767.;
  set _dtc_varattrib;
  attrib=strip(name)||" "||"length=" ||ifc(type='char','$',' ')||strip(put(namelen,best.))||" "  ; 
run;

filename _dtc_ temp;
data _null_;
  set _dtc_tablemeta end=eof;
  file _dtc_ ;
  put " ";
  %if &comb_type. in (2 3) %then %do;
    put "proc sort data=" indata "out=" memid ";";
    put "  by &byvars. ;";
    put "run;";
  %end;
run;

data _null_;
  set _dtc_varattrib end=eof;
  file _dtc_ mod;
  if _n_=1 then do;
    put "data &outdata.;";
    put '  attrib ';
  end;
  put '    ' attrib;
  if eof then do;
    put '    ;';
  end; 
run;

data _null_;
  set _dtc_tablemeta end=eof;
  file _dtc_ mod;
  if _n_=1 then do;
    %if &comb_type. in (1 2) %then %do;
      put '  set ';
	%end;
	%else %if &comb_type. in (3) %then %do;
      put '  merge ';
	%end;
  end;
  %if &comb_type. in (2 3) %then %do;
    put '    ' memid '(in=' memid ')';
  %end;
  %else %do;
    put '    ' indata '(in=' memid ')';
  %end;
  if eof then do;
    put '    ;';
    %if &comb_type. in (2 3) %then %do;
	  put "  by &byvars.;";
    %end;
  end; 
run;

data _null_;
  set _dtc_tablemeta end=eof;
  file _dtc_ mod;
  put " ";
  %if &comb_type. in (1 2) %then %do;
  if _n_=1 then do;
    put '  length _DATSRC_ $200.;';
  end;
  put '  if ' memid ' then _DATSRC_="' indata '";';
  if eof then do;
    put '  _DATSRC_=strip(_DATSRC_);';
  end; 
  %end;
  if eof then do;
    put 'run;';
  end; 
run;

%include _dtc_;
filename _dtc_;

*------------------------------------------;
* clean the datastep processing            ; 
* -----------------------------------------;
%if ^ &debug. %then %do;
  proc datasets lib=work nodetails noprint;
    delete _dtc_: ;
  quit;
%end;

%MSTOP: ;
%mend q_data_combine;
