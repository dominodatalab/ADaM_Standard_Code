/*****************************************************************************\
*        O                                                                      
*       /                                                                       
*  O---O     _  _ _  _ _  _  _|                                                 
*       \ \/(/_| (_|| | |(/_(_|                                                 
*        O                                                                      
* ____________________________________________________________________________
* Sponsor              : Evelo
* Study                : EDP1867-101
* Analysis             : 
* Program              : q_gen_quotetoken.sas
* Purpose              : QC macro for creating quoted token for the input keyowords
*                        passed in a macro variable
* ____________________________________________________________________________
* DESCRIPTION                                                    
*                                                                   
* Input files:  Keyword  = macro parameter which accepts the delimited keywords
*                          for which quotation is inserted and stored in a macro
*                          array variables
*               delim    = delimiter used to separate the keywords. Default is space
*               preserve = logical value specifying whether to preserve the case of
*                          the keywords
*                                                                   
* Output files:    
*               outmvar  = stem name of the array macro variable to store quote tokens
*                                                                 
* Macros:        None                                                 
*                                                                   
* Assumptions:    
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*  09AUG2021  |   Kaja Najumudeen   | Original
* ----------------------------------------------------------------------------  
\*****************************************************************************/
%macro q_gen_quotetoken(keyword=,delim=%str( ),outmvar=,preserve=,quote=Y);
%global &outmvar. &outmvar._c;
%if %bquote(&quote.) eq %then %let quote=Y;
%if %nrbquote(%superq(preserve))= %then %let preserve=N;
%local count;
%let &outmvar=;
%let str1=%quote(%sysfunc(compbl(&keyword)));
%let count=1;
%do %while(%length(%scan(&str1.,&count.,&delim.))>0);
  %let count=%eval(&count.+1);
%end;
%let count=%eval(&count.-1);
%do _lp=1 %to &count.;
  %global &outmvar&_lp.;
  %let str=%scan(&str1.,&_lp.,&delim);
  %if &preserve.=N %then %do;
    %let str=%upcase(&str.);
  %end;
  %if &quote.=Y %then %do;
    %let &outmvar=&&&outmvar %quote(%sysfunc(quote(&str)));
    %let &outmvar&_lp.=%quote(%sysfunc(quote(&str)));
  %end;
  %else %do;
    %let &outmvar=&&&outmvar &str.;
    %let &outmvar&_lp.=&str.;
  %end;
/*  %put o=&&&outmvar&_lp.;*/
/*  %let count=%eval(&count.-1);*/
%end;
%let &outmvar._c=&count.;
%mend;
