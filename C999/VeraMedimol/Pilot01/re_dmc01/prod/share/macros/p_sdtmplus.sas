/*****************************************************************************\
*        O                                                                     
*       /                                                                      
*  O---O     _  _ _  _ _  _  _|                                                
*       \ \/(/_| (_|| | |(/_(_|                                                
*        O                                                                     
* ____________________________________________________________________________
* Sponsor              : Evelo
* Study                : EDP1867-101
* Analysis             : Final Analysis
* Program              : sdtmplus.sas 
* Purpose              : Macro to merge SDTM datasets with relavent supplementary dataset
* ____________________________________________________________________________                                                   
*                                                                   
* Input files: None                                                   
*                                                                   
* Output files: None                                                  
*                                                                
* Macros: sdtmplus                                                        
*                                                                   
* Assumptions: None                                                   
*                                                                   
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*  10FEB2021  |  Natalie Thompson  |  Copied from 1815-201         
* ----------------------------------------------------------------------------
*  26JUL2021  |  Kaja Najumudeen   |  Added code to handle when supplemental 
                                      dataset does not exists
* ----------------------------------------------------------------------------
*  06AUG2021  |  Kaja Najumudeen   |  Added code to handle by variables information
*                                     when supplemental dataset doesnot exists
\*****************************************************************************/

%macro p_sdtmplus(libname=sdtm,dataset=,cleanup=Y)/mindelimiter=' ';
option validvarname=v7 MAUTOSOURCE minoperator;
  %let dataset=%sysfunc(lowcase(&dataset.));
  data _null_;
    if exist ("&libname..supp&dataset.") then do;
      id=open("&libname..supp&dataset.","IN");
	  nobs=attrn(id,"nobs");
	  call symputx("suppqual_obs",nobs);
	  rc=close(id);
	end;
	else do;
	  call symputx("suppqual_obs",0);
	end;
  run;
  ** Process when supplemental dataset exists;
  %if &suppqual_obs. ne 0 %then %do;
  proc sort data=&libname..supp&dataset. out=supp&dataset.;
    by usubjid idvarval idvar;
  run;

  ** Transpose supplementary dataset;
  proc transpose data=supp&dataset. out=trp_&dataset. (drop=_name_ _label_);
    by usubjid idvarval idvar;
  var qval;
  id qnam;
  idlabel qlabel;
  run;

  ** Split dataset by IDVAR;
  data trp_&dataset.2 (drop=idvarval) nomerge;
    set trp_&dataset.;
  %if &dataset. ne dm %then %do; if lowcase(idvar)=lowcase("&dataset.seq") then &dataset.seq=input(idvarval,best.); %end;
  if lowcase(idvar)=lowcase("&dataset.seq") or lowcase("&dataset.")="dm" then output trp_&dataset.2;
  else output nomerge; ** Where idvar is not sequence number;
  run;

  proc sort data=trp_&dataset.2;
    by usubjid %if &dataset. ne dm %then %do; &dataset.seq %end;;
  run;

  proc sort data=&libname..&dataset. out=&dataset.;
    by usubjid %if &dataset. ne dm %then %do; &dataset.seq %end;;
  run;

  ** Merge dataset by IDVAR; 
  data &dataset.plus;
    merge &dataset. trp_&dataset.2;
    by usubjid %if &dataset. ne dm %then %do; &dataset.seq %end;;
  run;

  %if &cleanup.=Y %then %do;
    proc datasets lib = work nolist memtype = data;
      delete supp&dataset. trp_&dataset. trp_&dataset.2 &dataset.;
    quit;
  %end;
  %end;
  %else %do;
    ** Process when supplemental dataset does not exists;
    %put UNOTE: Supplemental variable information doesnot exist for &dataset. dataset ;

	proc sort data=&libname..&dataset. out=&dataset.plus;
      by usubjid %if &dataset. in (dm sv) %then %do;  %end; %else %do; &dataset.seq; %end; ;
      ;
	run;
  %end;
%mend;
