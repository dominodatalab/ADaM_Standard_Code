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
* Program              : q_checkvar_create.sas                              |
* ____________________________________________________________________________|
* Macro to verify the existence of a list of variables in a data set and to   |
* create them if required. Macro will output the status of the variable(s)    |
* existence in a macro variable(s) under the same name of the variable(s)     |
*                                                                             |
* Input files:                                                                |
* Macro Parameters                                                            |
* ----------------------------------------------------------------------------|
* data                = name of the input dataset for variable verification is|
*                       performed                                             |
* vars                = list of blank delimited variable names in the input   |
*                       dataset referred through DATA macro parameter         |
* varstype            = numeric or character data type of the variable names  |
*                       in the input dataset to be used when initialised      |
* create              = logical value specifying whether to initialise the    |
*                       variable(s) in the dataset.                           |
* debug               = logical value specifying whether debug mode is        |
*                       on or off.                                            |
*                                                                             |
* Output files:                                                               |
* Macro Parameters                                                            |
* ----------------------------------------------------------------------------|
* <variable_names>    = macro variable created under the same names as listed |
*                       by the macro parameter VARS                           |
*                                                                             |
* outdata             = name of the processed bds dataset for tfl reporting   |
*                                                                             |
* Macros: _qc_checkvar_create                                                 |                    
*                                                                             |
* Assumptions:                                                                |                                            
*                                                                             |
* ____________________________________________________________________________|
* PROGRAM HISTORY                                                             |
*  09SEP2021  |   Kaja Najumudeen | Original version of the code              |
* ----------------------------------------------------------------------------|
\*****************************************************************************/
%macro q_checkvar_create(data=,vars=,varstype=,create=,outdata=,debug=)/mindelimiter=' ';
option validvarname=v7 MAUTOSOURCE minoperator;
*----------------------------------------;
* Check for dataset existence            ;
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
  %if %index(&data.,.) > 0 %then %let cv_data_name=%scan(&data.,2,.);
  %else %let cv_data_name=&data.;
%end;

%if %bquote(%superq(vars))= %then %do;
  %put %str(UER)ROR: Variable list in the dataset name is missing. Macro will exit now from processing;
  %GOTO MSTOP;
%end;
%else %if %bquote(%superq(vars)) ^= %then %do;
  %if %bquote(%superq(varstype))= %then %let varstype=2;
  %if %bquote(&varstype.) in (c C char CHAR 2) %then %let varstype=2;
  %if %bquote(&varstype.) in (n N num NUM 1) %then %let varstype=1;
  %q_gen_quotetoken(keyword=&vars.,delim=%str( ),outmvar=varsQ);
%end;

%if %bquote(%superq(outdata))= %then %do;
  %let outdata=&data.;
%end;

%if %bquote(&create.) eq %then %let create=0;
%if %bquote(&create.) in (y Y yes YES 1) %then %let create=1;
%if %bquote(&create.) in (n N no NO 0) %then %let create=0;

%if %bquote(&debug.) eq %then %let debug=0;
%if %bquote(&debug.) in (y Y yes YES 1) %then %let debug=1;
%if %bquote(&debug.) in (n N no NO 0) %then %let debug=0;

%let dsid = %sysfunc(open(&data.));
%if %nrbquote(%superq(vars))^= %then %do;
  %do _km_=1 %to &varsQ_C.;
    %let var=%sysfunc(scan(&vars.,&_km_.,%str( )));
	%global &var.;
    %if &dsid. %then %do;
	  %if &debug. %then %do;
        %put (UNOTE): Checking variable &var. for its existence in the data &data.;
	  %end;
      %if %sysfunc(varnum(&dsid.,&var.)) %then %let &var.=1;
      %else %let &var.=0;
	  %if &debug. %then %do;
        %if &&&var. %then %put (UNOTE): Variable &var. exists;
		%else %if ^ &&&var. %then %put (UNOTE): Variable &var. does not exist;
	  %end;
    %end;
    %else %do;
      %let &var.=0;
	  %if &debug. %then %do;
        %if &&&var. %then %put (UNOTE): Variable &var. exists;
		%else %if ^ &&&var. %then %put (UNOTE): Variable &var. does not exist;
	  %end;
	%end;
  %end;
  %let rc=%sysfunc(close(&dsid.));
%end;

data &outdata.;
  set &data.;
  %if &create. %then %do;
    %do _km_=1 %to &varsQ_C.;
	  %let rvar=%sysfunc(scan(&vars.,&_km_.,%str( )));
      %if ^ &&&rvar. %then %do;
	    %if &varstype.=2 %then %do; length &rvar. $200.; %end; 
        call missing(&rvar.);
      %end;
	%end;
  %end;
run;

*------------------------------------------;
* clean the datastep processing            ; 
* -----------------------------------------;
%if ^ &debug. %then %do;

%end;

%MSTOP: ;
%mend q_checkvar_create;
