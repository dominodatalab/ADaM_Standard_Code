 /*****************************************************************************\
*        O                                                                      
*       /                                                                       
*  O---O     _  _ _  _ _  _  _|                                                 
*       \ \/(/_| (_|| | |(/_(_|                                                 
*        O                                                                      
* ____________________________________________________________________________
* Sponsor              : Orchard
* Study                : OTL-103 General
* Program              : s_lenreduce.sas
* Purpose              : Reduces length to maximal for character variables (to be run before specs) 
* ____________________________________________________________________________
* DESCRIPTION                                                    
*                                                                   
* Input files: Input dataset by in
*              
* Output files: Dataset specified in OUT
*               
* Macros: None
*         
* Assumptions: 
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*  25FEB2020  | Otis Rimmer  | Original version
\*****************************************************************************/

%macro s_lenreduce(in=,out=,tidyup=Y);

%let tidyup = %upcase(&tidyup);

%* Check input dataset is provided;
%if %bquote(&in) = %then %do;
  %put %str(ERR)OR: Input dataset macro parameter IN is not populated;
  %goto leave;
%end;

%if %bquote(&out) = %then %do;
  %put %str(ERR)OR: output dataset macro parameter OUT is not populated;
  %goto leave;
%end;

%* Remove any dataset options (if applied), i.e. lib.dataset(<<options>>) to just return lib.dataset;
%* Check the input dataset actually exists;
%let _in = %scan(%bquote(&in),1,%str(%());

%if ^%sysfunc(exist(&_in)) %then %do;
  %put %str(ERR)OR: Input dataset does not exist;
  %goto leave;
%end;

data _dsin;
  set &_in.;
run;

proc contents data = _dsin out = names(where=(type=2)) noprint;
run;

proc sql noprint;

  select distinct name into :_namelper separated by ' ' from names;

  %do i = 1 %to %sysfunc(countw(&_namelper,%str( )));

    %let name&i = %scan(&_namelper,&i,%str( ));
   
    select cats( "$" , max( 1 , max(lengthn(&&name&i.)) ) ) into :maxlen&i. separated by ""
    from _dsin(keep=&&name&i.);

  %end;

quit;

data &out.;
  set _dsin;

  %do i = 1 %to %sysfunc(countw(&_namelper,%str( )));

  length __&&name&i &&maxlen&i.;
  __&&name&i. = &&name&i.;
  drop &&name&i.;
  rename __&&name&i. = %upcase(&&name&i.);

  %end;
run;

%if &tidyup = Y %then %do;
  proc delete data = _dsin;
  run;
%end;

%leave:

%mend s_lenreduce;
