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

/* create macro variables xpt_1,... to capture all individual xpt file names */
data _NULL_;
	set xptnames;
	call symputx(cats('XPT_', dsnum), cats("'/mnt/data/ADAM/",fname,"'"), 'g'); 
run;
%put _USER_;
/* loop through all individual files and add to adam as sas7bdat */
%macro xpt_sas;
    %do i=1 %to &Nxpt.;
		%xpt2loc(filespec=&&XPT_&i);
	%end;
%mend xpt_sas;

%xpt_sas;