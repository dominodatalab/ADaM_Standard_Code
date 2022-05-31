/*****************************************************************************\
*        O                                                                      
*       /                                                                        
*  O---O     _  _ _  _ _  _  _|                                                 
*       \ \/(/_| (_|| | |(/_(_|                                                 
*        O                                                                      
* ____________________________________________________________________________
* Sponsor              :          
* Study                :            
* Program              : p_ady.sas
* Purpose              : Macro which creates the relative day for ADaM datasets
*				
* ____________________________________________________________________________
* DESCRIPTION                                                    
*                                                                   
* Input files:                                                        
*              
* Output files:                                                         
*               
* Macros: None
*         
* Assumptions:                                               
*              
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
* 29MAR2022 | James Mann       | Original version 
\*****************************************************************************/

* 
INDS - Input dataset
OUTDS - Output dataset
DATEVAR - Numeric SAS date to base relative day from (e.g. ADT)
DAYVAR - Name of the numeric relative day variable to create (e.g. ADY)
REFVAR - Numeric SAS date to compare DATEVAR to
REFDSET - Dataset to merge REFVAR from. If REFDSET is blank, it will assume that REFVAR is in the input dataset (INDS).
          If REFDSET is not blank, it will merge ADAM.&REFDSET into the input dataset, so REFDSET always needs to be 
          one record per STUDYID USUBJID, hence it is assumed that REFDSET will either be blank or ADSL in the vast 
          majority of calls;

%macro p_ady (inds=,                                                 
			 outds=,                                                 
			 datevar=,          
			 dayvar=,
             refvar=TRTSDT,
			 refdset=ADSL
		    );

* If REFDSET is specified, merge it into the input dataset by STUDYID and USUBJID;

%IF &REFDSET NE %THEN %DO;

  proc sort data=&inds         out=datain_sort; by studyid usubjid; run;
  proc sort data=adam.&refdset out=ref_sort;    by studyid usubjid; run;

  data ady;
  merge datain_sort (in=x)
        ref_sort    (keep=studyid usubjid &refvar);
  by studyid usubjid;
    if x;
  
%END;
%ELSE %DO;

  data ady;
  set &inds;

%END;

    * Derive relative day. Add 1 if the date is on or after the reference, such that we do not have a day 0;

    if nmiss(&datevar,&refvar)=0 then do;
      if &datevar < &refvar then &dayvar=&datevar-&refvar;
	  else &dayvar=&datevar-&refvar+1;
    end;
  run;

  data &outds;
  set ady;
    %IF &REFDSET NE %THEN %DO;
	  drop &refvar;
	%END;
  run;
  
%mend p_ady;
