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

%xpt2loc(filespec='/mnt/data/ADAM/adsl.xpt');

data adam.adsl;
	set adsl;
run;

%s_compare(base = ADAM._ALL_,
		   comp = ADAMQC._ALL_,
		   comprpt = '/mnt/artifacts/compare.pdf',
		   prefix =NULL);





/*  */
/* Obtain xpt file names  */
/* data xptnames (where = (scan(strip(fname),2,'.') = 'xpt')); */
/* 	length fref $8 fname $200; */
/* 	tmp = filename(fref,'/mnt/data/ADAM'); */
/* 	tmp = dopen(fref); */
/* 	do i = 1 to dnum(tmp); */
/* 		fname = dread(tmp,i); */
/*  		output; */
/* 	end; */
/* 	tmp = dclose(tmp); */
/* 	tmp = filename(fref); */
/*     keep fname; */
/* run; */
/*  */
/* create macro variable 'xpts' to capture all individual xpt file names */
/* proc sql noprint; */
/*     select strip(fname) into:xpts separated by ' ' */
/*     from xptnames */
/*     ; */
/* quit; */
/*  */
/* loop through all individual files and add to adam as sas7bdat */
/* %macro xpt_sas; */
/*     %do i=1 %to %sysfunc(countw(&xpts)); */
/* 		%let currnam = %scan(&xpts, &i, ' '); */
/* 		%let currpth = %bquote('/mnt/data/ADAM/)&currnam %bquote('); */
/* 		%xpt2loc(filespec=&currpth); */
/* 		data ADAM.&currnam; */
/* 			set &currnam; */
/* 		run; */
/* 	%end; */
/* %mend xpt_sas; */
/*  */
/* %xpt_sas; */
































