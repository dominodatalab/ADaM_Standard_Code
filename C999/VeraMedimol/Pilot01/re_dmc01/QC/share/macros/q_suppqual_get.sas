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
* Program              : q_suppqual_get.sas
* Purpose              : QC macro for adding supplemental variables to the parent
*                        dataset
* ____________________________________________________________________________
* DESCRIPTION                                                    
*                                                                   
* Input files:  inlib    = input libref where parent and supplemental datasets exist
*               select   = name of the dataset(s) to be processed for adding suppqual
*                          variables to the parent datasets. Multiple datasets are 
*                          space delimited
*               debug    = logical value specifying whether debug mode is on or off
*                                   
*                                                                   
* Output files: 
*               outlib   = output libref where dataset will be saved with the parent 
*                          dataset name but with supplemental variables added to it
*                          if one exists
*                                                                 
* Macros:       q_gen_quotetoken                                                 
*                                                                   
* Assumptions:   
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*  09AUG2021  |   Kaja Najumudeen   | Original
* ----------------------------------------------------------------------------  
\*****************************************************************************/
%macro q_suppqual_get(inlib=,outlib=,select=,debug=0)/mindelimiter=' ';
option validvarname=v7 MAUTOSOURCE minoperator;
%let workpath=%sysfunc(pathname(work));
options dlcreatedir;
libname _work1 "&workpath.\sg";
options nodlcreatedir;
%if %nrbquote(%superq(select)) ^= %then %do;
  %q_gen_quotetoken(keyword=&select.,delim=%str( ),outmvar=selectQ);
%end;
%else %do;
  proc sql noprint;
    create table _work1._sel_dsn as
      select a.memname 
      from dictionary.tables as a
      where upcase(libname)=upcase("&inlib.") and (^ upcase(memname) like upcase("SUPP%"));
      select distinct memname into: select_chose separated by " "
      from _work1._sel_dsn
      ;
    quit;
  %put SELECT_CHOSE= &select_chose.;
  %let select=&select_chose.;
  %q_gen_quotetoken(keyword=&select.,delim=%str( ),outmvar=selectQ);
%end;
%if %nrbquote(&outlib.) eq %then %let outlib=work;
*----------------------------------------;
* Check for debug macro parameter   ;
* ---------------------------------------;
%if %bquote(&debug.) eq %then %let debug=0;
%if %bquote(&debug.) in (y Y yes YES 1) %then %let debug=1;
%if %bquote(&debug.) in (n N no NO 0) %then %let debug=0;

%if %nrbquote(%superq(select))^= %then %do;
  %do _km_=1 %to &selectQ_C.;
    *parent dataset;
    %if %sysfunc(exist(&inlib..%sysfunc(scan(&select.,&_km_.,%str( ))))) %then %do;
      %let idvar_vars=;

      %if %sysfunc(exist(&inlib..supp%sysfunc(scan(&select.,&_km_.,%str( ))))) %then %do;
        *suppqual dataset;
        proc sort data=&inlib..supp%sysfunc(scan(&select.,&_km_.,%str( )))
                  out=_work1.supp&_km_.;
          by usubjid idvarval idvar
          ; 
        run;
	    proc transpose data=_work1.supp&_km_.
                       out=_work1.supptp&_km_.;
          by usubjid idvarval idvar;
          id qnam;
          idlabel qlabel; 
          var qval;
        run;
        
		%let idvar_vars=;
		proc sql noprint;
          select distinct idvar into: idvar_vars separated by " "
		  from _work1.supptp&_km_.
		  ;
		quit;
	  %end;*suppparent do;

      *parent dataset;
	  data _work1.parent&_km_.;
	    set &inlib..%sysfunc(scan(&select.,&_km_.,%str( ))); 
      run;

	  proc contents data=_work1.parent&_km_. out=_work1.parent&_km_._contents noprint; run;
     
	  %if %bquote(&idvar_vars.) ne %then %do;
        %q_gen_quotetoken(keyword=&idvar_vars.,delim=%str( ),outmvar=idvarsQ);

		data _work1.parent&_km_._contents;
		  length newvar_stmt $2000.;
		  set _work1.parent&_km_._contents;
		  fullpath=catx(".",libname,memname);
          %do _i_=1 %to &idvarsQ_C.;
            if upcase(strip(name))=&&idvarsQ&_i_. and type=1 then do;
              _retype_=1;
			  newvar_stmt='  if upcase(strip(idvar))=strip("'|| &&idvarsQ&_i_. ||'") and not missing(idvarval) then '||strip(name)||"="||"input(idvarval,best.);";
			end;
			else if upcase(strip(name))=&&idvarsQ&_i_. and type=2 then do;
              _retype_=0;
			  newvar_stmt='  if upcase(strip(idvar))=strip("'|| &&idvarsQ&_i_. ||'") and not missing(idvarval) then '||strip(name)||"="||"strip(idvarval));";
			end; 
		  %end;
		run;

        filename kms temp;
        data _null_;
          set _work1.parent&_km_._contents(where=(not missing(_retype_))) end=eof;
          file kms;
            put "data _work1.supptp&_km_.;";  
            put "  set _work1.supptp&_km_.;" ;  
            put " " newvar_stmt;
            put 'run;';  

			put "proc sort data=_work1.supptp&_km_.;";
			put "  by usubjid " name ";";
			put "run;";

			put "proc sort data=_work1.parent&_km_.;";
			put "  by usubjid " name ";";
			put "run;";

			put "data _work1.parent&_km_.;";
			put "  merge _work1.parent&_km_.(in=a)";
			put "        _work1.supptp&_km_.(in=b);";
 			put "  by usubjid " name ";";
            put "  if a;";
			put "run;";
        run;

        %include kms;
        filename kms;
/*	    %if %bquote(&outlib.) ne %then %do;*/
/*	    %end;*/
	  %end;%*idvar_vars do;
	  %if %bquote(&outlib.) ne %then %do;
		  data &outlib..%sysfunc(scan(&select.,&_km_.,%str( )));
		    set _work1.parent&_km_.;
		  run; 
	  %end;
	%end;%*parent do;
  %end;%*_km_ do;
%end;%*select do;
*------------------------------------------;
* clean the datastep processing            ; 
* -----------------------------------------;

%if ^ &debug. %then %do;
  proc datasets lib=_work1 kill nodetails noprint;
  quit;
  libname _work1 clear;
%end;
%mend;

