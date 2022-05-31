/*****************************************************************************\
*        O                                                                      
*       /                                                                        
*  O---O     _  _ _  _ _  _  _|                                                 
*       \ \/(/_| (_|| | |(/_(_|                                                 
*        O                                                                      
* ____________________________________________________________________________
* Sponsor              :           
* Study                :              
* Program              : p_addtm.sas
* Purpose              : Macro which converts an SDTM date in ISO format
*                        in the form YYYY-MM-DDTHH:MM:SS into numeric SAS date, 
*                        time and datetime. Allows for imputation to earliest or 
*                        latest component for partial dates
* ____________________________________________________________________________
* DESCRIPTION                                                    
*                                                                   
* Input files: Dataset containing SDTM date variable and the name of the
*              variable to be converted            
*              
* Output files: Dataset containing the converted date/time variables
*               
*               
* Macros: None
*         
* Assumptions: None
*              
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
* 12JAN2022 | James Mann      | Original version
\*****************************************************************************/

* INDS - Name of input dataset
  OUTDS - Name of output dataset
  ISODT - Character date variable from input dataset, in format YYYY-MM-DDTHH:MM:SS
  ADAMDT - Name of numeric SAS date required
  ADAMTM - Name of numeric SAS time required
  ADAMDTM - Name of numeric SAS datetime required
  ADAMDTF - Numeric SAS date format
  ADAMTMF - Numeric SAS time format
  ADAMDTMF - Numeric SAS datetime format
  IMPUTE - If imputation is required, state either START or END. START will set all missing dates/time components to the
           first of the year/month/day/hour/minute, END will set to the last of the year/month/day/hour/minute
  IMPUTEDTP - If the imputation requires that a START imputation cannot be earlier than a certain date (e.g. TRTSDT),
              or an end date cannot be later than a certain date (e.g. TRTEDT), state the prefix of the date/time comparitor here. 
              The prefix goes up to and not including DT/TM/DTTM, so for example TRTSDT/TRTSTM/TRTSDTTM has a call of 
              IMPUTEDTP=TRTS;

%macro p_adttm (inds=,
                outds=,
                isodt=,
                adamdt=,
                adamtm=,
                adamdtm=,
                adamdtf=e8601da,
                adamtmf=time5,
                adamdtmf=e8601dt16,
                impute=,
                imputedtp=);

  %LET IMPUTE=%UPCASE(&IMPUTE);

  * Find out the lowest component time level based on the length of the input date/time;

  data z_adttm;
  set &inds;
    zzlen=length(&isodt);
  run;

  proc sort data=z_adttm; by zzlen; run;

  data z_macvar;
  set z_adttm end=last;
    if last then do;
	  if zzlen = 19 then zzlowest='SECONDS';
	  else if zzlen >= 16 then zzlowest='MINUTES';
	  else if zzlen >= 13 then zzlowest='HOURS';
	  else zzlowest='NOTIME';
      call symput('zzlowest',strip(zzlowest));
	end;
  run;

  * Create a numeric variable of each component from the input data;

  data z_adttm_in;
  set &inds;

  zz_day=.;
  zz_month=.;
  zz_year=.;
  zz_hour=.;
  zz_minute=.;
  zz_seconds=.;

  if length(&isodt) ge 4 then zz_year=input(substr(&isodt,1,4),??8.);
  if length(&isodt) ge 7 then zz_month=input(substr(&isodt,6,2),??8.);
  if length(&isodt) ge 10 then zz_day=input(substr(&isodt,9,2),??8.);

  if length(&isodt) ge 13 then zz_hour=input(substr(&isodt,12,2),??8.);
  if length(&isodt) ge 16 then zz_minute=input(substr(&isodt,15,2),??8.);
  if length(&isodt) ge 19 then zz_seconds=input(substr(&isodt,18,2),??8.);

  * If imputation is required and is the start, set to the earliest component of the date/time;

  %IF &IMPUTE=START %THEN %DO;
    length zz_flag $20;
    if zz_month=. then do;
	  zz_month=1; zz_day=1; zz_hour=0; zz_minute=0; zz_seconds=0; zz_flag='MONTH'; 
	end;
	if zz_day=. then do;
	              zz_day=1; zz_hour=0; zz_minute=0; zz_seconds=0; zz_flag='DAY';

	end;
	if zz_hour=. then do;
	                        zz_hour=0; zz_minute=0; zz_seconds=0; zz_flag='HOUR';
	end;
	if zz_minute=. then do;
	                                   zz_minute=0; zz_seconds=0; zz_flag='MINUTE';
	end;
	if zz_seconds=. then do;
	                                                zz_seconds=0; zz_flag='SECOND';
	end;
  %END;

  * Similar code if the end is required, but set to the latest for each component;

  %IF &IMPUTE=END %THEN %DO;
    length zz_flag $20;
    if zz_month=. then do;
	  zz_month=12; zz_day=31; zz_hour=23; zz_minute=59; zz_seconds=59; zz_flag='MONTH';
	end;
	if zz_day=. then do;
	       if zz_year ne . and 1 <= zz_month <= 11 then zz_day=day(( mdy((zz_month+1),1,zz_year) - 1));
	  else if zz_year ne . and      zz_month =  12 then zz_day=31;
	                         zz_hour=23; zz_minute=59; zz_seconds=59; zz_flag='DAY';
	end;
	if zz_hour=. then do;
	                         zz_hour=23; zz_minute=59; zz_seconds=59; zz_flag='HOUR';
	end;
	if zz_minute=. then do;
	                                     zz_minute=59; zz_seconds=59; zz_flag='MINUTE';
	end;
	if zz_seconds=. then do;
	                                                   zz_seconds=59; zz_flag='SECOND';
	end;
  %END;

  

  %IF &ADAMDT NE %THEN %DO;
    if zz_year ne . and zz_month ne . and zz_day ne . then &adamdt=mdy(zz_month,zz_day,zz_year);
	format &adamdt &adamdtf..;
  %END;
  %IF &ADAMTM NE %THEN %DO;
    %IF &ZZLOWEST=MINUTES %THEN %DO;
	  zz_seconds=0;
	%END;
	if nmiss(zz_hour,zz_minute,zz_seconds)=0 then &adamtm=hms(zz_hour,zz_minute,zz_seconds);
	format &adamtm &adamtmf..;
  %END;
  %IF &ADAMDTM NE %THEN %DO;
    %IF &ZZLOWEST=MINUTES %THEN %DO;
	  zz_seconds=0;
	%END;
	if nmiss(zz_year,zz_month,zz_day,zz_hour,zz_minute,zz_seconds)=0
    then &adamdtm=dhms(mdy(zz_month,zz_day,zz_year),zz_hour,zz_minute,zz_seconds);
    format &adamdtm &adamdtmf..; 
  %END;
  run;

  * If a date comparator is required, check to see if it requires a merge with ADSL or not, by checking for the existence of 
    a . in the macro variable name;

  %IF &IMPUTEDTP NE %THEN %DO;

    %LET DTNAME=;
	%LET TMNAME=;
	%LET DTMNAME=;

    data z_imp_macvars;
	  length LIBNAME $8 MEMNAME NAME $32 imputedtp $50;
	  imputedtp=upcase("&imputedtp");
	  if index(imputedtp,'.')=0 then do;
        libname='WORK';
        memname='Z_ADTTM_IN';
		imputedtp='XXX.' || strip(imputedtp);
      end;
      else do;
        libname='ADAM';
        memname=scan(imputedtp,1,'.');
	  end;
	  dtname=strip(scan(imputedtp,2,'.')) || 'DT';
	  tmname=strip(scan(imputedtp,2,'.')) || 'TM';
	  dtmname=strip(scan(imputedtp,2,'.')) || 'DTM';

	  if libname='ADAM' then call symput('ADAMYN','Y');
	                    else call symput('ADAMYN','N');
	  call execute('proc contents data=' || strip(libname) || '.' || strip(memname) || ' noprint out=z_imp_cont; run;');

	  NAME=dtname;   SEQ=1; output;
      NAME=dtmname; SEQ=2; output;
	  NAME=tmname;   SEQ=3; output;
	run;

	proc sort data=z_imp_cont; by name; run;

	data z_imp_checkdts;
	merge z_imp_macvars (in=x keep=memname name seq)
	      z_imp_cont    (in=y keep=memname name);
	by memname name;
	  if x and y;
	  if seq=1 then call symput('DTNAME',strip(name));
	  if seq=2 then call symput('DTMNAME',strip(name));
	  if seq=3 then call symput('TMNAME',strip(name));
	run;

    * If a merge with ADSL is required, do this now, otherwise just bring in the required dataset;

    %IF &ADAMYN=Y %THEN %DO;
	  proc sort data=adam.adsl out=z_adsl;        by studyid usubjid; run;
	  proc sort data=z_adttm_in out=z_addtm_sort; by studyid usubjid; run;

	  data z_adttm_comp;
	  merge z_adsl (keep=studyid usubjid &DTNAME &TMNAME &DTMNAME
	                rename=(&dtname=z_comp_dtname
					%IF &TMNAME NE %THEN %DO;
					  &tmname=z_comp_tmname
					%END;
					%IF &DTMNAME NE %THEN %DO;
					  &dtmname=z_comp_dtmname
					%END;

					))
	        z_adttm_in (in=x);
	  by studyid usubjid;
	    if x;
	  run;
	%END;
	%ELSE %DO;
	  data z_adttm_comp;
	  set z_adttm_in (rename=(&dtname=z_comp_dtname
					%IF &TMNAME NE %THEN %DO;
					  &tmname=z_comp_tmname
					%END;
					%IF &DTMNAME NE %THEN %DO;
					  &dtmname=z_comp_dtmname
					%END;
                       ));
	  run;
	%END;

	* Perform the date/time comparator checks. If IMPUTE=START and we have imputed to earlier than the comparator variable
	  in &IMPUTEDTP, then set to &IMPUTEDTP.DT/TM/DTTM. If IMPUTE=END and we have imputed to later than the comparator variable
	  in &IMPUTEDTP, then set to &IMPUTEDTP.DT/TM/DTTM;

	  data z_adttm_comp2;
	  set z_adttm_comp;
	  %IF &IMPUTE=START %THEN %DO;
	    if
		(. < &adamdt < z_comp_dtname and zz_flag='MONTH' and zz_year=year(z_comp_dtname))
         or 
		(. < &adamdt < z_comp_dtname and zz_flag='DAY' and zz_year=year(z_comp_dtname) and zz_month=month(z_comp_dtname))
		
		%IF ADAMTM NE AND &TMNAME NE %THEN %DO;
		or 
		(. < &adamdt = z_comp_dtname and . < &adamtm < z_comp_tmname and zz_flag='HOUR')
		or 
	    (. < &adamdt = z_comp_dtname and . < &adamtm < z_comp_tmname and zz_flag='MINUTE' and zz_hour=hour(z_comp_tmname))
		or
		(. < &adamdt = z_comp_dtname and . < &adamtm < z_comp_tmname and zz_flag='SECOND' and zz_hour=hour(z_comp_tmname) and zz_minute=minute(z_comp_tmname))
		%END;
	  %END; 
	  %ELSE %IF &IMPUTE=END %THEN %DO;
	    if
		(. < z_comp_dtname < &adamdt and zz_flag='MONTH' and zz_year=year(z_comp_dtname))
         or 
		(. < z_comp_dtname < &adamdt and zz_flag='DAY' and zz_year=year(z_comp_dtname) and zz_month=month(z_comp_dtname))
		
		%IF ADAMTM NE AND &TMNAME NE %THEN %DO;
		or 
		(. < &adamdt = z_comp_dtname and . < z_comp_tmname < &adamtm and zz_flag='HOUR')
		or 
	    (. < &adamdt = z_comp_dtname and . < z_comp_tmname < &adamtm and zz_flag='MINUTE' and zz_hour=hour(z_comp_tmname))
		or
		(. < &adamdt = z_comp_dtname and . < z_comp_tmname < &adamtm and zz_flag='SECOND' and zz_hour=hour(z_comp_tmname) and zz_minute=minute(z_comp_tmname))
		%END;
	  %END; 

		then do;
		  &adamdt=z_comp_dtname;
		  %IF ADAMTM NE AND &TMNAME NE %THEN %DO;
		    &adamtm=z_comp_tmname;
		  %END;
		  %IF ADAMDTM NE AND &DTMNAME NE %THEN %DO;
		    &adamdtm=z_comp_dtmname;
		  %END;
		end;
	run;
  %END;

  data &outds;
  set 
  %IF &imputedtp NE %THEN %DO;
    z_adttm_comp2
	%IF &ADAMYN EQ Y %THEN %DO;
	  (drop=z_comp_dtname
	  %IF &TMNAME NE %THEN %DO;
	    z_comp_tmname
	  %END;
	  %IF &DTMNAME NE %THEN %DO;
	    z_comp_dtmname
	  %END;
	%END;
	%ELSE %DO;
	  (rename=(z_comp_dtname=&DTNAME
      %IF &TMNAME NE %THEN %DO;
	    z_comp_tmname=&TMNAME
	  %END;
	  %IF &DTMNAME NE %THEN %DO;
	    z_comp_dtmname=&DTMNAME
	  %END;
	           )
	%END;
	)
  %END;
  %ELSE %DO;
    z_adttm_in
  %END;;
  
  %IF &IMPUTE NE %THEN %DO;
        length &adamdt.f $1;
		if zz_flag in('MONTH' 'DAY') then &adamdt.f=substr(zz_flag,1,1);
		%IF &ADAMTM NE %THEN %DO;
		length &adamtm.f $1;
		  if &adamdt.f ne '' or zz_flag='HOUR' then &adamtm.f='H';
		  else if zz_flag ne '' then &adamtm.f=substr(zz_flag,1,1);
		  %IF &ZZLOWEST EQ MINUTES %THEN %DO;
		    if &adamtm.f='S' then &adamtm.f='';
		  %END;
		%END;
  %END;

  drop zz_:;
  run;

%mend p_adttm;
