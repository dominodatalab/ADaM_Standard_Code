/*****************************************************************************\
*        O                                                                      
*       /                                                                       
*  O---O     _  _ _  _ _  _  _|                                                 
*       \ \/(/_| (_|| | |(/_(_|                                                 
*        O                                                                      
* ____________________________________________________________________________
* Sponsor              :           
* Study                :          
* Program              : u_freq 
* Purpose              : Macro to create counts and percentages per treatment 
* ____________________________________________________________________________
* DESCRIPTION         
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
* James Mann  | Original             | 2022-03-22
* ----------------------------------------------------------------------------     
\*****************************************************************************/

%macro u_freq(inds=,
              outds=,
	          countvar=,
	          byvars=,
	          where=,
	          trtvarn=,
	          totval=,
	          totcond=,
	          display=,
	          denom=,
	          nonmissv=,
	          percfmt=,
	          totrowtxt=,
	          totrowpos=,
	          forcefmt=,
              order=,
              sorderfmt=,
	   		  pairvar=,
              textfmt=);

  * Bring in input dataset, subset, and create a total treatment group if required;

  data ufreq_indsp;
  set &inds;
    countvar=1;
	counttype=1;
	%IF &TRTVARN NE %THEN %DO;
	  trtvarn=&trtvarn;
	%END;
	%ELSE %DO;
	  trtvarn=1;
	%END;
    %IF &where NE %THEN %DO;
	  where &where;
	%END;
	%IF &TOTVAL NE %THEN %DO;
	  output;
	  %IF &TOTCOND NE %THEN %DO;
	    if %str(&totcond) then trtvarn=&totval;
	  %END;
	  %ELSE %DO;
	    trtvarn=&totval;
	  %END;
	  output;
	%END;
  run;

  * Put the length and the type of the variable we are counting into macro variables;

  data ufreq_types;
  set sashelp.vcolumn;
    where upcase(libname)='WORK' and upcase(memname)='UFREQ_INDSP' and upcase(name)=upcase("&countvar");
	call symput('countvar_type',strip(type));
	call symput('countvar_len',strip(put(length,8.)));
  run;

  * If the additional total row is required, create additional records with COUNTTYPE=0 or 2. COUNTTYPE=1 has already been 
    set as the normal counts, regardless of whether a total row is needed;

  %IF &TOTROWTXT NE %THEN %DO;
    data ufreq_inds;
	set ufreq_indsp;
	  output;
	  %IF &TOTROWPOS=TOP %THEN %DO;
	    counttype=0;
	  %END;
	  %ELSE %IF &TOTROWPOS=BOTTOM %THEN %DO;
	    counttype=2;
	  %END;
	  %IF &countvar_type=char %THEN %DO;
	    if &countvar ne '' then do;
          &countvar='';
          output;
		end;
	  %END;
	  %IF &countvar_type=num %THEN %DO;
	    if &countvar ne . then do;
          &countvar=.;
          output;
		end;
	  %END;
	run;
  %END;
  %ELSE %DO;
    data ufreq_inds;
	set ufreq_indsp;
	run;
  %END;

  proc sort data=ufreq_inds;
    by &byvars trtvarn counttype;
  run;

  * Perform the counts. If FORCEFMT has been specified, then use the preloadfmt option to force out all possible values;
 
  proc summary data=ufreq_inds completetypes noprint nway;
    by &byvars trtvarn counttype;
	var countvar;
	output out=ufreq_counts (drop=rename=(_freq_=count) where=(counttype=1 or sum ne .)) sum=sum;
    class &countvar
    %IF &FORCEFMT NE %THEN %DO;
      / preloadfmt missing;
      format &countvar &forcefmt..;
	%END;
	;
  run;

  * Force out all treatment groups with counts of 0 if there are no subjects within a treatment group;

  %IF &TRTVARN NE %THEN %DO;
    proc sort data=ufreq_counts out=ufreq_templ1 (drop=trtvarn) nodupkey;
      by &byvars counttype &countvar;
	run;

	data ufreq_templ2;
	set ufreq_templ1;
	  count=0;
  	  %DO I=1 %TO &NUMTRT;
	    trtvarn=&i;
		output;
	  %END;
	run;

	proc sort data=ufreq_templ2;                   by &byvars counttype &countvar trtvarn; run;
	proc sort data=ufreq_counts out=ufreq_countss; by &byvars counttype &countvar trtvarn; run;

	data ufreq_withtempl;
	merge ufreq_templ2  (keep=&byvars counttype &countvar trtvarn count)
	      ufreq_countss (in=x);
	by &byvars counttype &countvar trtvarn;
	  if not x then force=1;
	run;
  %END;	  
  %ELSE %DO;
    data ufreq_withtempl;
	set ufreq_counts;
	run;
  %END;

  * If the denominator is the population, bring in the dataset created from the U_POP macro for the denominators;

  %IF &DENOM=POP %THEN %DO;
    proc sort data=ufreq_withtempl out=ufreq_countden; by trtvarn; run;
    proc sort data=upop_counts     out=ufreq_popden;   by trtvarn; run;

    data ufreq_countpop;  
    merge ufreq_countden (in=x)
          ufreq_popden  (keep=trtvarn count rename=(count=denom));
    by trtvarn;
      if x;
    run;
  %END;
  %ELSE %IF &DENOM=NONMISS %THEN %DO;

    proc sort data=ufreq_inds out=ufreq_inds_nonmiss;
	  where &nonmissv and counttype=1;
	  by &byvars trtvarn;
	run;
  
    proc freq data=ufreq_inds_nonmiss noprint;
      by &byvars trtvarn;
	  tables countvar / out=ufreq_countnonmiss;
    run; 

	proc sort data=ufreq_withtempl out=ufreq_withtempl_nonmiss;
	  by &byvars trtvarn;
	run;

    data ufreq_countpop;  
    merge ufreq_withtempl_nonmiss    (in=x)
          ufreq_countnonmiss (rename=(count=denom));
    by &byvars trtvarn;
      if x;
    run;  
  %END; 
  %ELSE %DO;
    data ufreq_countpop;
	set ufreq_withtempl;
	run;
  %END;

  * Find out the maximum length of the count and denominator. This is then used in order to set the length
    of the transposed variables;

  data ufreq_maxlen;
  set ufreq_countpop;
    lencount=length(strip(put(count,8.)));
	retain maxcount;
	if _n_=1 then maxcount=lencount;
	else if lencount > maxcount then maxcount=lencount;
	call symput('maxcount',strip(put(maxcount,8.)));

	%IF &DENOM NE %THEN %DO;
	  lendenom=length(compress(put(denom,8.)));
	  retain maxdenom;
	  if _n_=1 then maxdenom=lendenom;
	  else if lendenom > maxdenom then maxdenom=lendenom;
	  call symput('maxdenom',strip(put(maxdenom,8.)));
	%END;
  run;
  
  * Create the DISP variable as the display of either count, count+percent, or count / denomiator + percent;

  data ufreq_disp;
  set ufreq_countpop;
    length disp $100;
	%IF &DISPLAY=COUNT %THEN %DO;
	  disp=put(count,&maxcount..);
	%END;
	%ELSE %IF &DISPLAY=COUNTPERC %THEN %DO;
	  if denom > 0 and counttype=1 then perc=(count/denom)*100;
	  disp=put(count,&maxcount..) || ' ' || right(put(perc,&percfmt..));
	  %IF &DENOM=NONMISS %THEN %DO;
	    if not(&nonmissv) and counttype=1 then disp=put(count,&maxcount..);
	  %END;
	%END;
	%ELSE %IF &DISPLAY=COUNTDENOM %THEN %DO;
	  if denom > 0 and counttype=1 then perc=(count/denom)*100;
	  if counttype=1 then disp=put(count,&maxcount..) || ' / ' || put(denom,&maxdenom..) || ' ' || right(put(perc,&percfmt..));
	  else disp=put(count,&maxcount..);
	%END;
  run;

  * Transpose the data such that treatment groups are now columns, with a variable name of TRT1, TRT2 etc.;

  proc sort data=ufreq_disp; by &byvars counttype &countvar trtvarn; run;

  proc transpose data=ufreq_disp prefix=TRT out=ufreq_tran;
    by &byvars counttype &countvar;
    id trtvarn;
	var disp;
  run;

  * If the PAIRVAR macro variable has been used, create the matched set of variables;

  %IF &PAIRVAR NE %THEN %DO;
    proc freq data=ufreq_indsp noprint;
	  tables &countvar.*&pairvar / out=ufreq_pairvars;
	run;

	data ufreq_types_pair;
    set sashelp.vcolumn;
      where upcase(libname)='WORK' and upcase(memname)='UFREQ_PAIRVARS' and upcase(name)=upcase("&countvar");
	  call symput('pairvar_type',strip(type));
    run;

	proc sort data=ufreq_tran out=ufreq_trans; by &countvar; run;

	data ufreq_ptran;
	merge ufreq_trans    (in=x)
	      ufreq_pairvars (keep=&countvar &pairvar);
	by &countvar;
	  if x;
	run;

  %END;
  %ELSE %DO;
    data ufreq_ptran;
	set ufreq_tran;
	run;
  %END;

  * Create the ORDER, SORDER and TEXT variables;

  data ufreq_ord;
  set ufreq_ptran;
  length text $200;
  text='';
  order=.;
  sorder=.;
  %IF &FORCEFMT NE %THEN %DO;
    format &countvar;
  %END;
  %IF &order NE %THEN %DO;
    order=&order;
  %END;
  %IF &sorderfmt NE %THEN %DO;
    sorder=input(&countvar,??&sorderfmt..);
  %END;
  %ELSE %IF &countvar_TYPE=num %THEN %DO;
    sorder=&countvar;
  %END;
  %IF &textfmt NE %THEN %DO;
    text=put(&countvar,&textfmt..);
  %END;
  %ELSE %IF &countvar_TYPE=char %THEN %DO;
    text=&countvar;
  %END;
  %IF &TOTROWTXT NE %THEN %DO;
    if counttype ne 1 then text="&totrowtxt";
  %END;
  %IF &PAIRVAR NE %THEN %DO;
    %IF &PAIRVAR_TYPE=num %THEN %DO;
	  if sorder=. then sorder=&pairvar;
	%END;
	%IF &PAIRVAR_TYPE=char %THEN %DO;
	  if text='' then text=&pairvar;
	%END;
  %END;
  run;

  proc sort data=ufreq_ord out=&outds;
    by order sorder;
  run;


%mend u_freq;
