/*****************************************************************************\
*        O                                                                     
*       /                                                                      
*  O---O     _  _ _  _ _  _  _|                                                
*       \ \/(/_| (_|| | |(/_(_|                                                
*        O                                                                     
* ____________________________________________________________________________
* Sponsor              : Evelo
* Study                : EDP1815-201
* Analysis             : NA
* Program              : p_sigdec.sas   
* ____________________________________________________________________________
* Macro creates format variables for data of varying significant decimal places.                                                
*                                                                   
* Input files: datain
*                                                                            
* Output files: datain                                                   
*                                                                
* Macros:                                          
*                                                                   
* Assumptions:                                           
*                                                                   
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*  01JUN2021  | Srihari Hanumantha    | Original                                                         
* ----------------------------------------------------------------------------
*  ddmmmyyyy  |   <<name>>       | ..description of change..         
\*****************************************************************************/

%macro p_sigdec(datain=,	/*input dataset;*/
		var=,				/*variable to determine significant decimal places for;*/
		classvars=,			/*grouping variables (ie. labtype labtest)*/
		fmtname=sigfmt,		/*output variable containing complete format*/
		maxfmtlen=12,		/*maximum format length for converting numeric to character*/
		sigdecvar=sigdec,	/*output var containing significant decimal places*/
		siglenvar=siglen 	/*output var containing format length;*/
	);
	data &datain;
		set &datain;
	/*****************************
	dummy merging variable in case no class variables are defined
	*****************************/
		mergeby_ = 1;
	run;
	proc summary nway missing data=&datain;
		class mergeby_ &classvars &var;
		output out=sigvars(drop=_:);
	run;
	/**************************
	check to see if variable is	character or numeric
	**************************/
	%let dsid=%sysfunc(open(sigvars,i));
	%let varnum=%sysfunc(varnum(&dsid,&var));
	%let vartyp=%sysfunc(vartype(&dsid,&varnum));
	%let rc=%sysfunc(close(&dsid));
	%put Note: Variable &varnum is &vartyp;
	data sigvars;
		set sigvars;
	/******************************
	convert to character if numeric
	******************************/
		%if &vartyp = N %then
		%do;
			sigvar = trim(left(put(&var,best&maxfmtlen..)));
		%end;
		%else
		%do;
			sigvar = &var;
		%end;
		/* Length */
		&siglenvar = length(compress(sigvar));
		/* Decimals */
		if index(sigvar,'.')
		then &sigdecvar = length(sigvar) - index(sigvar,'.');
		else &sigdecvar = 0;
	run;
	/* Maximums */
	proc summary nway missing data=sigvars;
		class mergeby_ &classvars;
		var &sigdecvar &siglenvar;
		output out=sigvar(drop=_:) max=&sigdecvar &siglenvar;
	run;
	proc sort data=&datain;
		by mergeby_ &classvars;
	run;
	/* Merge back to original data */
	data &datain(drop=mergeby_);
		merge &datain
		sigvar;
		by mergeby_ &classvars;
	/* create format variable */
		&fmtname = compress(put(&siglenvar,&maxfmtlen..)||'.'||put(&sigdecvar,&maxfmtlen..));
	/* create format variable with decimal + 1 */
		if &sigdecvar = 0
		then &fmtname.1 = compress(put(&siglenvar+2,&maxfmtlen..)||'.'||put(&sigdecvar+1,&maxfmtlen..));
		else &fmtname.1 = compress(put(&siglenvar+1,&maxfmtlen..)||'.'||put(&sigdecvar+1,&maxfmtlen..));
	/* create format variable with decimal + 2 */
		if &sigdecvar = 0
		then &fmtname.2 = compress(put(&siglenvar+3,&maxfmtlen..)||'.'||put(&sigdecvar+2,&maxfmtlen..));
		else &fmtname.2 = compress(put(&siglenvar+2,&maxfmtlen..)||'.'||put(&sigdecvar+2,&maxfmtlen..));
	run;
%mend p_sigdec;

