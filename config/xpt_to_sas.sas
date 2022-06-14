/*****************************************************************************\
*  ____                  _
* |  _ \  ___  _ __ ___ (_)_ __   ___
* | | | |/ _ \| '_ ` _ \| | '_ \ / _ \
* | |_| | (_) | | | | | | | | | | (_) |
* |____/ \___/|_| |_| |_|_|_| |_|\___/
* ____________________________________________________________________________
* Sponsor              : Domino
* Study                : H2QMCLZZT
* Program              : xpt_to_sas.sas
* Purpose              : Convert any xpt datasets in adam to sas7bdat and output to adam.
* ____________________________________________________________________________
* DESCRIPTION                                                    
*                                                                   
* Input files: adam:
*              
* Output files: adam:
*               
* Macros: init 
*         
* Assumptions: 
*
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*  14JUN2022    | Jake Tombeur   | Original version
\*****************************************************************************/

*********;
%include "!DOMINO_WORKING_DIR/config/domino.sas";
*********;



/* Obtain xpt file names  */
data xptnames;
	length fref $8 fname $200;
	dsnum = 1;
	tmp = filename(fref,'/mnt/data/ADAM');
	tmp = dopen(fref);
	do i = 1 to dnum(tmp);
		fname = dread(tmp,i);
		if scan(strip(fname),2,'.') = 'xpt' then do;
	 		output;
			dsnum = dsnum + 1;
		end;
	end;
	tmp = dclose(tmp);
	tmp = filename(fref);
    keep fname dsnum;
	call symputx('Nxpt',dsnum -1, 'g');
run;

/* create macro variables xpt_name_1,... and xpt_path_1,... to capture all individual xpt file names and paths */
data _NULL_;
	set xptnames;
	call symputx(cats('XPT_path_', dsnum), cats("'/mnt/data/ADAM/",fname,"'"), 'g'); 
	call symputx(cats('XPT_name_', dsnum), scan(fname,1,'.'), 'g');
run;
%put _USER_;
/* loop through all individual files and add to adam as sas7bdat */
%macro xpt_sas;
    %do i=1 %to &Nxpt.;
		%xpt2loc(filespec=&&XPT_path_&i);
		data adam.&&XPT_name_&i;
			set &&XPT_name_&i;
		run;
	%end;
%mend xpt_sas;

%xpt_sas;