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
* Program              : _qc_subject_counts.sas                               |
* ____________________________________________________________________________|
* Macro to create subject count for different treatment group for different   |  
* cohort/groups for differnt types of population                              | 
*                                                                             |
* Input files:                                                                |
* Macro Parameters                                                            |
* ----------------------------------------------------------------------------|
* population          = name of the variable that defines the subject         |
*                       population                                            |
* treatment_group     = name of the treament group to be reported for the     |
*                       requested population                                  |
* period              = number identifying the sequence of treatment periods  |
* debug               = logical value specifying whether debug mode is        |
*                       on or off.                                            |
*                                                                             |
* Output files:                                                               |
* Macro Parameters                                                            |
* ----------------------------------------------------------------------------|
* trt_<cohort_initial>_<treatment_sequence>                                   |
*                     = name of the macro variable which gives the subject    |
*                       count for different treatment group and cohort        |
*                                                                             |
* Macros: _qc_subject_counts                                                  |                    
*                                                                             |
* Assumptions: ADaM.ADSL exists and required treatment as per EDP1867-101     |                                            
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
\*****************************************************************************/
%macro _qc_subject_counts(population=,treatment_group=,period=,debug=)/mindelimiter=' ';
option validvarname=v7 MAUTOSOURCE minoperator;
*----------------------------------------;
* Check for libref and dataset existence ;
* ---------------------------------------;
%if %sysfunc(libref(adam)) ne 0 %then %do;
  %put %str(UER)ROR: Library adam does not exist. Macro will exit now from processing;
  %GOTO MSTOP;
%end;
%else %do;
  %if ^ %sysfunc(exist(adam.adsl)) %then %do;
    %put %str(UER)ROR: Dataset ADSL doesnot exist in adam library. Macro will exit now from processing;
    %GOTO MSTOP;
  %end;
%end;

%if %bquote(%superq(population))= %then %do;
  %let population=SAFFL;
%end;

%if %bquote(%superq(period))= %then %do;
  %let period=2;
%end;

%if %bquote(&treatment_group.) eq %then %let treatment_group=a;
%if %bquote(&treatment_group.) in (a A) %then %let treatment_group=a;
%if %bquote(&treatment_group.) in (p P) %then %let treatment_group=p;
%let treatment_group=%sysfunc(lowcase(&treatment_group.));

%if %bquote(%superq(treatment_group))= a %then %do;
  %do i=1 %to &period.;
    %let newi = %sysfunc(putn(&i., z2));
    %let trt_grp_&newi.  = trt&newi.a;
    %let trt_grp_&newi.n = trt&newi.an;
  %end;
%end;
%else %if %bquote(%superq(treatment_group))= p %then %do;
  %do i=1 %to &period.;
    %let newi = %sysfunc(putn(&i., z2));
    %let trt_grp_&newi.  = trt&newi.p;
    %let trt_grp_&newi.n = trt&newi.pn;
  %end;
%end;

%if %bquote(&debug.) eq %then %let debug=0;
%if %bquote(&debug.) in (y Y yes YES 1) %then %let debug=1;
%if %bquote(&debug.) in (n N no NO 0) %then %let debug=0;

data _sc_adsl;
  set adam.adsl(where=(&population.='Y'));
  if subtyp='Healthy Volunteers' then subtyp_text="[HV]";
  else if subtyp='Atopic Dermatitis' then subtyp_text="[AD]";
  else if subtyp='Psoriasis' then subtyp_text="[Ps]";
  else if subtyp='Asthma' then subtyp_text="[As]";
  %do i=1 %to &period.;
    %let newi = %sysfunc(putn(&i., z2));
    if not missing(&&&trt_grp_&newi.) then do;
      trt&treatment_group.=catx(" ","P&i.",&&&trt_grp_&newi.,subtyp_text); 
      trt&treatment_group.n=&&&trt_grp_&newi.n; 
	  output;
    end; 
  %end;
run;

proc sort data=_sc_adsl;
  by usubjid;
run;

data _sc_adsl_tot(keep=usubjid subjid subtypn subtyp subtyp_text trt&treatment_group. trt&treatment_group.n 
                       trt&treatment_group._new trt&treatment_group.n_new 
                  where=(trt&treatment_group.n_new ne .)
                  );
  length trt&treatment_group._new $100.;
  set _sc_adsl;
  by usubjid;
  if first.usubjid then do;
    trt&treatment_group.n_new=999;		*Create Total column;
    trt&treatment_group._new="Total";
    output;
  end;
  trt&treatment_group._new=trt&treatment_group.;
  trt&treatment_group.n_new=trt&treatment_group.n;
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
  %do i=1 %to &period.;
    %let newi = %sysfunc(putn(&i., z2));
    if index(lowcase(&&&trt_grp_&newi.),"placebo") > 0 then do;
      trt&treatment_group._new=catx(" ","P&i. Placebo",subtyp_text); 
      trt&treatment_group.n_new=%eval(&i.*100); 
	  output;
    end; 

    if index(lowcase(&&&trt_grp_&newi.),"edp1867") > 0 then do;
      trt&treatment_group._new=catx(" ","P&i. EDP1867",subtyp_text); 
      trt&treatment_group.n_new=%eval((&i.*100)+99); 
	  output;
    end; 
  %end;
run;

proc sql noprint;
  create table _sc_subj_count as 
    select subtypn, subtyp, subtyp_text, trt&treatment_group.n_new, trt&treatment_group._new, count (distinct usubjid) as bign
    from _sc_adsl_tot
    group by subtypn,subtyp,subtyp_text,trt&treatment_group.n_new,trt&treatment_group._new
  ;
quit;

data _sc_subj_count;
  set _sc_subj_count;
  if not missing(trt&treatment_group._new) then seqord=1*(scan(trt&treatment_group._new,1," ")="P1")+
                                                       2*(scan(trt&treatment_group._new,1," ")="P2")+
                                                      99*(scan(trt&treatment_group._new,1," ")="All")+
                                                     999*(scan(trt&treatment_group._new,1," ")="Total");
  if not missing(trt&treatment_group._new) then trt&treatment_group._new_txt=substr(trt&treatment_group._new,index(trt&treatment_group._new," ")+1);
  if missing(trt&treatment_group._new_txt) and seqord=999 then trt&treatment_group._new_txt="Total";
  macvar="trt_"||strip(compress(subtyp_text,"[]"))||"_"||strip(put(trt&treatment_group.n_new,best.));
  call symputx(strip(macvar),bign,"G");
  macval=resolve("&"||strip(macvar));
run;

proc sort data=_sc_subj_count; 
  by seqord trt&treatment_group.n_new trt&treatment_group._new;
run;

data _null_;
  set _sc_subj_count;
  by seqord trt&treatment_group.n_new trt&treatment_group._new;
  if seqord not in (99 999) then do;
    put "Subjects in the treatment " trt&treatment_group._new_txt " for Period " seqord " is " bign " and macro variable associated to this is " macvar "=" macval;
  end;
  else if seqord in (99) then do;
    put "Subjects in the treatment " trt&treatment_group._new_txt " for all Periods is " bign " and macro variable associated to this is " macvar "=" macval;
  end;
  else if seqord in (999) then do;
    put "Total Number of subjects in the study treatment are " bign " and macro variable associated to this is " macvar "=" macval;
  end;
run;

*------------------------------------------;
* clean the datastep processing            ; 
* -----------------------------------------;
%if ^ &debug. %then %do;
  proc datasets lib=work nodetails noprint;
    delete _sc_: ;
  quit;
%end;

%MSTOP: ;
%mend _qc_subject_counts;
