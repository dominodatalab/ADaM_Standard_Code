/*****************************************************************************\
*        O                                                                      
*       /                                                                       
*  O---O     _  _ _  _ _  _  _|                                                 
*       \ \/(/_| (_|| | |(/_(_|                                                 
*        O                                                                      
* ____________________________________________________________________________
* Sponsor              : Veramedimol
* Study                : Pilot01
* Program              : compare.SAS
* Purpose              : To compare all adam datasets
* ____________________________________________________________________________
* DESCRIPTION                                                    
*                                                                   
* Input files:  ADAM ADAMQC
*              
* Output files: ADSL
*               
* Macros:       None
*         
* Assumptions: 
*
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*  08JUN2022   | Jake Tombeur   | Original version
\*****************************************************************************/

*********;
** Setup environment including libraries for this reporting effort;
%include "!DOMINO_WORKING_DIR/config/domino.sas";
*********;

/* Obtain xpt file names */ 
data xptnames (where = (scan(strip(fname),2,'.') = 'xpt'));
	length fref $8 fname $200;
	tmp = filename(fref,'/mnt/data/ADAM');
	tmp = dopen(fref);
	do i = 1 to dnum(tmp);
		fname = dread(tmp,i);
 		output;
	end;
	tmp = dclose(tmp);
	tmp = filename(fref);
    keep fname;
run;

/* create macro variable 'xpts' to capture all individual xpt file names */
proc sql noprint;
    select fname into: xpts separated by ' '
    from xptnames
    ;
quit;

/* loop through all individual files and add tro adam as sas7bdat*/
%macro xpt_sas;
    %do i=1 %to %sysfunc(countw(&xpts));
         libname xptfile xport "/mnt/data/ADAM/%scan(&xptprgs, &i).xpt" access=readonly;

         proc copy inlib=xptfile outlib=ADAM;
         run;
	%end;
%mend xpt_sas;

%xpt_sas;

