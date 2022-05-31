/*****************************************************************************\
*        O                                                                    | 
*       /                                                                     |
*  O---O     _  _ _  _ _  _  _|                                               | 
*       \ \/(/_| (_|| | |(/_(_|                                               | 
*        O                                                                    | 
* ____________________________________________________________________________|
* Sponsor              : Evelo                                                |
* Study                : EDP1867-101                                          |
* Analysis             : validation                                           |
* Program              : q_process_bds_dsn_for_tfl.sas                      |
* ____________________________________________________________________________|
* Macro to add different combination of treatment groups and club different   |
* visit as per tfl reporting requirement                                      | 
*                                                                             |
* Input files:                                                                |
* Macro Parameters                                                            |
* ----------------------------------------------------------------------------|
* indata              = name of the bds dataset that requires process for tfl |
*                       reporting                                             |
* treatment_group     = name of the treament group to be reported for the     |
*                       requested population                                  |
* period              = number identifying the sequence of treatment periods  |
* debug               = logical value specifying whether debug mode is        |
*                       on or off.                                            |
*                                                                             |
* Output files:                                                               |
* Macro Parameters                                                            |
* ----------------------------------------------------------------------------|
* outdata             = name of the processed bds dataset for tfl reporting   |
*                                                                             |
* Macros: _qc_process_bds_dsn_for_tfl                                         |   
*         _qc_checkvar_create                                                 | 
*                                                                             |
* Assumptions: ADaM bds exists and required treatment as per EDP1867-101      |                                            
*                                                                             |
* ____________________________________________________________________________|
* PROGRAM HISTORY                                                             |
*  09SEP2021  |   Kaja Najumudeen | Original version of the code              |
* ----------------------------------------------------------------------------|
*  13SEP2021  |   Kaja Najumudeen | Added treatment_group macro parameter that|
*             |                   | controls the treatment group to be        |
*             |                   | considered for the subject count. Valid   |
*             |                   | values are P, A                           |
*             |                   | Added period to control the flow of treat-|
*             |                   | ment for multiple sequence                |
* ----------------------------------------------------------------------------|
*  21SEP2021  |   Kaja Najumudeen | updated the assignment flow for the macro |
*             |                   | parameter treatment_group                 |
* ----------------------------------------------------------------------------|
*  08NOV2021  |   Kaja Najumudeen | Included the avisit for percentage change |
*             |                   | from baseline                             |
* ----------------------------------------------------------------------------|
*  22NOV2021  |   Kaja Najumudeen | Included macro call _qc_checkvar_create to|
*             |                   | create treatmentgroup variable for periods|
\*****************************************************************************/
%macro q_process_bds_dsn_for_tfl(indata=,outdata=,treatment_group=,period=,debug=)/mindelimiter=' ';
option validvarname=v7 MAUTOSOURCE minoperator;
*----------------------------------------;
* Check for dataset existence            ;
* ---------------------------------------;
%if %bquote(%superq(indata))= %then %do;
  %put %str(UER)ROR: Input dataset name is missing. Macro will exit now from processing;
  %GOTO MSTOP;
%end;
%else %do;
  %if ^ %sysfunc(exist(&indata.)) %then %do;
    %put %str(UER)ROR: Dataset &indata. doesnot exist. Macro will exit now from processing;
    %GOTO MSTOP;
  %end;
  %if %index(&indata.,.) > 0 %then %let pb_data_name=%scan(&indata.,2,.);
  %else %let pb_data_name=&indata.;
%end;

%if %bquote(%superq(outdata))= %then %do;
  %put %str(UER)ROR: output dataset name is missing. Macro will exit now from processing;
  %GOTO MSTOP;
%end;

%if %bquote(%superq(period))= %then %do;
  %let period=2;
%end;

%if %bquote(&treatment_group.) eq %then %let treatment_group=a;
%if %bquote(&treatment_group.) in (a A) %then %let treatment_group=a;
%if %bquote(&treatment_group.) in (p P) %then %let treatment_group=p;
%let treatment_group=%sysfunc(lowcase(&treatment_group.));

%if %bquote(&debug.) eq %then %let debug=0;
%if %bquote(&debug.) in (y Y yes YES 1) %then %let debug=1;
%if %bquote(&debug.) in (n N no NO 0) %then %let debug=0;

%q_checkvar_create(data=&indata.
                    ,vars=trt&treatment_group.
                    ,varstype=2
                    ,create=1
                    ,outdata=_pbds_&pb_data_name.
                    ,debug=&debug.
                    );

%q_checkvar_create(data=_pbds_&pb_data_name.
                    ,vars=trt&treatment_group.n
                    ,varstype=1
                    ,create=1
                    ,outdata=_pbds_&pb_data_name.
                    ,debug=&debug.
                    );

%do i=1 %to &period.;
  %let newi = %sysfunc(putn(&i., z2));
  %q_checkvar_create(data=_pbds_&pb_data_name.
                      ,vars=trt&newi.&treatment_group
                      ,varstype=2
                      ,create=1
                      ,outdata=_pbds_&pb_data_name.
                      ,debug=&debug.
                      );
%end;

data _pbds_&pb_data_name.;
  length trt&treatment_group._new $100.;
  set _pbds_&pb_data_name.;
  if subtyp='Healthy Volunteers' then subtyp_text="[HV]";
  else if subtyp='Atopic Dermatitis' then subtyp_text="[AD]";
  else if subtyp='Psoriasis' then subtyp_text="[Ps]";
  else if subtyp='Asthma' then subtyp_text="[As]";
  %do i=1 %to &period.;
    %let newi = %sysfunc(putn(&i., z2));
	if trt&treatment_group.=trt&newi.&treatment_group then do;
      trt&treatment_group._new=catx(" ","P&i.",trt&treatment_group.,subtyp_text); 
	  trt&treatment_group.n_new=trt&treatment_group.n;
	end;
  %end;
run;

data _pbds_&pb_data_name._1;
  set _pbds_&pb_data_name.;
  output;
  if index(lowcase(trt&treatment_group.),"placebo") > 0 then do;
    trt&treatment_group._new=catx(" ","All Placebo",subtyp_text);
	trt&treatment_group.n_new=0;
	output;
  end;
  else if index(lowcase(trt&treatment_group.),"edp1867") > 0 then do;
    trt&treatment_group._new=catx(" ","All EDP1867",subtyp_text);
	trt&treatment_group.n_new=99;
	output;
  end;
  if index(lowcase(trt&treatment_group.),"placebo") > 0 then do;
    %do i=1 %to &period.;
      %let newi = %sysfunc(putn(&i., z2));
	  if trt&treatment_group.=trt&newi.&treatment_group then do;
        trt&treatment_group._new=catx(" ","P&i. Placebo",subtyp_text); 
	    trt&treatment_group.n_new=%eval(&newi.*100);
		output;
	  end;
    %end;
  end;
  if index(lowcase(trt&treatment_group.),"edp1867") > 0 then do;
    %do i=1 %to &period.;
      %let newi = %sysfunc(putn(&i., z2));
	  if trt&treatment_group.=trt&newi.&treatment_group then do;
        trt&treatment_group._new=catx(" ","P&i. EDP1867",subtyp_text); 
	    trt&treatment_group.n_new=%eval((&newi.*100)+99);
		output;
	  end;
    %end;
  end;
run;

%q_checkvar_create(data=_pbds_&pb_data_name._1
                    ,vars=ABLFL avisit
                    ,varstype=2
                    ,create=1
                    ,outdata=_pbds_&pb_data_name._1
                    ,debug=&debug.
                    );

%q_checkvar_create(data=_pbds_&pb_data_name._1
                    ,vars=avisitn
                    ,varstype=1
                    ,create=1
                    ,outdata=_pbds_&pb_data_name._1
                    ,debug=&debug.
                    );

data _pbds_&pb_data_name._tot;
  length avisit_base avisit_chg avisit_sched avisit_pchg $200.;
  set _pbds_&pb_data_name._1;
  if nmiss(trt&treatment_group.n_new)=0 then do;
    trt&treatment_group.n_new_id="trt_"||strip(compress(subtyp_text,"[]"))||"_"||strip(put(trt&treatment_group.n_new,best.));
    trtcnt=resolve("&"||strip(trt&treatment_group.n_new_id));
  end;
  if not missing(trt&treatment_group._new) then do;
    seqord=1*(scan(trt&treatment_group._new,1," ")="P1")+2*(scan(trt&treatment_group._new,1," ")="P2")+
           99*(scan(trt&treatment_group._new,1," ")="All")+100*(scan(trt&treatment_group._new,1," ")="Total");
    trt&treatment_group._new=strip(trt&treatment_group._new)||"|(N="||strip(trtcnt)||")";
	trt&treatment_group._new_txt=substr(trt&treatment_group._new,index(trt&treatment_group._new," ")+1);
  end;
  avisitn_new=avisitn;
  if ABLFL="Y" then do; avisitn_new=2; avisit_base="Baseline";end;
  avisit_chg=strip(avisit)||" Change from Baseline";
  if avisit not in ("Screening" "Baseline" "Unscheduled") then avisit_sched=avisit;
  avisit_pchg=strip(avisit)||" Percentage Change from Baseline";
run;

data &outdata.;
  set _pbds_&pb_data_name._tot;
run;

*------------------------------------------;
* clean the datastep processing            ; 
* -----------------------------------------;
%if ^ &debug. %then %do;
  proc datasets lib=work nodetails noprint;
    delete _pbds_: ;
  quit;
%end;

%MSTOP: ;
%mend q_process_bds_dsn_for_tfl;
