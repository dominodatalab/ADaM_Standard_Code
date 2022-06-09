/*****************************************************************************\
*        O                                                                      
*       /                                                                       
*  O---O     _  _ _  _ _  _  _|                                                 
*       \ \/(/_| (_|| | |(/_(_|                                                 
*        O                                                                      
* ____________________________________________________________________________
* Sponsor              :           
* Study                :          
* Program              : p_suppadd 
* Purpose              : Macro to merge an SDTM SUPP dataset into the parent SDTM
* ____________________________________________________________________________
* DESCRIPTION         
*                                                     
*                                                                   
* Input files:                                           
*                                                                    
* Output files:                                              
*                                                                   
* Macros:        
*                                                                    
* Assumptions:                                                    
*                                                                   
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
* James Mann  | Original             | 2022-03-23
* ----------------------------------------------------------------------------     
\*****************************************************************************/

%macro p_suppadd (inds=,domain=,outds=);

* Macro will merge the QNAM variables from a SUPP domain into the parent domain
  The macro will also check to see if the QNAM variable is numeric or character. If all values of QVAL within QNAM 
  are numeric, the variable will be set to numeric in the merged dataset, otherwise it will be character;

%LET SUPPEX=N;
%IF &INDS EQ %THEN %LET INDS=%STR(SDTM.&domain);

data check_exist;
set sashelp.vtable;
  where libname='SDTM' and upcase(memname)=upcase("SUPP&domain");
  call symput('SUPPEX','Y');
run;

%IF &SUPPEX=N %THEN %DO;

  data &outds;
  set &inds;
  run;

%END;
%ELSE %DO;

* Check the type and length of each value within the QNAM;

proc sort data=sdtm.supp&domain out=supp; by idvar qnam; run;

data allsupps;
length idvar $8;
set supp;
by idvar qnam;
  retain type length;
  lenqval=length(strip(qval));
  if first.qnam then do;
    type='N';
	length=lenqval;
  end;
  if input(qval,??8.)=. and qval not in('.' ' ') then type='C';
  length=max(length,lenqval);
run;

* We want to see all values of IDVAR. Most SUPP datasets will have the IDVAR value as --SEQ, but it is possible to 
  have more than one value of IDVAR, so the macro will loop later and transpose/merge separately for each value of 
  IDVAR. The QNAM dataset will show whether the variable should be character or numeric;

data qnam idvar (rename=(idvar=name));
set allsupps;
by idvar qnam;
  if last.qnam then output qnam;
  if last.idvar then output idvar;
run;

* Find the attributes of each IDVAR value, so that we know whether to set up each IDVAR value as character or numeric;

proc contents data=&inds out=cont_parent noprint; run;

data idvar_cont;
merge cont_parent (keep=name type length
                        rename=(type=idvar_type length=idvar_length))
	  idvar       (in=x keep=name);
by name;
  if x;
run;

* Create macro variables to loop for each value of IDVAR;

data idmacs;
set idvar_cont end=last;
  call symput('idvar'||strip(put(_n_,8.)),strip(name));
  call symput('idvart'||strip(put(_n_,8.)),strip(put(idvar_type,1.)));
  call symput('idvarl'||strip(put(_n_,8.)),strip(put(idvar_length,1.)));
  if last then call symput('numidvar',strip(put(_n_,8.)));
run;

* The TYPE variable in QNAM gives the overall TYPE of the merged variable. We will create a numeric value (QVAL_NUM) 
  for the QNAMs with all numeric results, and a character value (QVAL_CHAR) for all others;

data supptypes;
merge qnam (keep=idvar qnam type length)
      allsupps (drop=type length);
by idvar qnam;
  if type='N' then qval_num=input(qval,??best.);
              else qval_char=strip(qval);
run;

* Create this as a starting point. This will be overwritten as we then merge the transposed datasets;

data all;
set &inds;
run;

* Loop for each value of IDVAR. For most cases, this will loop once per SUPP, in which case the below code
  will merge the numeric values and the character values in two separate transpose/merges. But if there are more than 
  one IDVAR, it will perform that for each value of IDVAR;

%DO I=1 %TO &NUMIDVAR;

  data supp_&&idvar&i;
  set supptypes;
    where idvar="&&idvar&i";
	%IF &&IDVART&I EQ 1 %THEN %DO;
	  &&idvar&i=input(idvarval,8.);
	%END;
	%ELSE %IF &&IDVART&I EQ 2 %THEN %DO;
	  length &&idvar&i $&&idvarl&i ;
	  &&idvar&i=strip(idvarval);
	%END;
  run;

  * Numeric values;

  proc sort data=supp_&&idvar&i out=suppn_&&idvar&i;
    by usubjid &&idvar&i;
	where type='N';
  run;

  proc transpose data=suppn_&&idvar&i out=trn_&&idvar&i (where=(usubjid ne ''));
    by usubjid &&idvar&i;
	id qnam;
	idlabel qlabel;
	var qval_num;
  run;

  * Character values;

  proc sort data=supp_&&idvar&i out=suppc_&&idvar&i;
    by usubjid &&idvar&i;
	where type='C';
  run;

  proc transpose data=suppc_&&idvar&i out=trc_&&idvar&i (where=(usubjid ne ''));
    by usubjid &&idvar&i;
	id qnam;
	idlabel qlabel;
	var qval_char;
  run;

  proc sort data=all; 
    by usubjid &&idvar&i;
  run;

  data all;
  merge all 
        trn_&&idvar&i (drop=_name_)
		trc_&&idvar&i (drop=_name_);
  by usubjid &&idvar&i;
  run;

%END;

data &outds;
set all;
run;

%END;

%mend p_suppadd;
