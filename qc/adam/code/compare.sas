/*****************************************************************************\
*        O                                                                      
*       /                                                                       
*  O---O     _  _ _  _ _  _  _|                                                 
*       \ \/(/_| (_|| | |(/_(_|                                                 
*        O                                                                      
* ____________________________________________________________________________
* Sponsor              : Domino
* Study                : H2QMCLZZT
* Program              : compare.SAS
* Purpose              : To compare all adam datasets
* ____________________________________________________________________________
* DESCRIPTION                                                    
*                                                                   
* Input files:  ADAM ADAMQC
*              
* Output files: compare.pdf, adsl.sas7bdat
*               
* Macros:       s_compare
*         
* Assumptions: 
*
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*  08JUN2022   | Jake Tombeur   | Original version
\*****************************************************************************/

%let _STUDYID = H2QMCLZZT;

*********;
** Setup environment including libraries for this reporting effort;
%include "!DOMINO_WORKING_DIR/config/domino.sas";
*********;

%xpt2loc(filespec='/mnt/data/ADAM/adsl.xpt');

data adam.adsl;
	set adsl;
run;
/* Compare all */
%s_compare(base = ADAM._ALL_,
		   comp = ADAMQC._ALL_,
		   comprpt = '/mnt/artifacts/compare.pdf',
		   prefix =,
		   tidyup = N);

/* json file from results */
proc sql noprint;
	select count(distinct base) into: all_ds
	from ___LIBALLCOMP;

	select  count(*), count(distinct base) into :all_issues, :ds_issues 
	from ___LIBALLCOMP (where = (compstatus = 'Issues'));

	select count(distinct base) into: ds_clean
	from ___LIBALLCOMP (where = (compstatus = 'Clean'));
quit;

proc json out = "/mnt/artifacts/dominostats.json" pretty;
	write values "Number of Datasets" &all_ds;
    write values "Clean Datasets" &ds_clean;
    write values "Datasets with Issues" &ds_issues;
    write values "Total number of Issues" &all_issues;
run;

/* Output results dataset */
libname compare '/mnt/data/COMPARE';
data compare.summary;
	set ___LIBALLCOMP;
run;















