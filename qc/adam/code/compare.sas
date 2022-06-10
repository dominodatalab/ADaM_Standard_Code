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

%s_compare(base = ADAM._ALL_,
		   comp = ADAMQC._ALL_,
		   comprpt = '/mnt/artifacts/compare.pdf',
		   prefix =,
		   tidyup = N);

proc sql;
	create table diags1 as	
	select count(distinct base) as N_dset
	from ___LIBALLCOMP;

	create table diags2 as	
	select  count(*) as N_allissues, count(distinct base) as N_dissues 
	from ___LIBALLCOMP (where = (compstatus = 'Issues'));

	create table diags3 as	
	select count(distinct base) as N_dclean
	from ___LIBALLCOMP (where = (compstatus = 'Clean'));
quit;

data diags;
	merge diags1-diags3;
run;

proc json out = '/mnt/code/dominostats.json' pretty;
	export diags / nosastags;
run;


 






%s_compare(base = ADAM.ADSL,
		   comp = ADAMQC.ADSL,
		   options = outbase outcomp outnoequal transpose);
data gaps;
	set _COMPY_DIFFS;
	


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
































