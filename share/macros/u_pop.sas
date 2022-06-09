/*****************************************************************************\
*        O                                                                      
*       /                                                                       
*  O---O     _  _ _  _ _  _  _|                                                 
*       \ \/(/_| (_|| | |(/_(_|                                                 
*        O                                                                      
* ____________________________________________________________________________
* Sponsor              :           
* Study                :          
* Program              : u_pop 
* Purpose              : Macro to put population counts into macro variables
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
* James Mann  | Original             | 2022-03-22
* ----------------------------------------------------------------------------     
\*****************************************************************************/

%macro u_pop (inds=adam.adsl,
              trtvarn=trt01pn,
              mvpre=POP,
              where=,
              totval=,
              totcond=);

* Bring in input dataset, subset, and create a total treatment group if required;

  data upop_inds;
  set &inds;
    %IF &TRTVARN NE %THEN %DO;
      where &trtvarn ne .;
	  trtvarn=&trtvarn;
	%END;
	%ELSE %DO;
	  trtvarn=1;
	%END;
    %IF &where NE %THEN %DO;
	  where also &where;
	%END;
	%IF &TOTVAL NE %THEN %DO;
	  output;
	  %IF &TOTCOND NE %THEN %DO;
	    if %str(&totcond) then do; 
          trtvarn=&totval;
		  output;
		end;
	  %END;
	  %ELSE %DO;
	    trtvarn=&totval;
		output;
	  %END;
	%END;
  run;

  * Perform the frequency counts by treatment group;

  proc freq data=upop_inds noprint;
    tables trtvarn / out=upop_counts;
  run;

  * Count the number of treatment groups we have, then create the required number of macro variables;

  data upop_macvar;
  set upop_counts;
    call symput('mptrtvar'||strip(put(_n_,8.)),strip(put(trtvarn,8.)));
	call symput('totn',strip(put(_n_,8.)));
  run;

  %DO I=1 %TO &totn;
    %global &mvpre.&&mptrtvar&i;
  %END;

  data upop_macvar2;
  set upop_counts;
    call symput(strip("&mvpre")||strip(put(trtvarn,8.)),strip(put(count,8.)));
  run;

%mend u_pop;
