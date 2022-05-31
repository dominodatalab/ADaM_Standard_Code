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
* Program              : _qc_process_tfl_trtvar_names.sas                     |
* ____________________________________________________________________________|
* Macro to rename the treatment variables as per tfl reporting requirement    | 
*                                                                             |
* Input files:                                                                |
* Macro Parameters                                                            |
* ----------------------------------------------------------------------------|
* indata              = name of the tfl reporting dataset that requires the   |
*                       processing for treatment variable renaming            |
* debug               = logical value specifying whether debug mode is        |
*                       on or off.                                            |
*                                                                             |
* Output files:                                                               |
* Macro Parameters                                                            |
* ----------------------------------------------------------------------------|
* outdata             = name of the processed input dataset for tfl reporting |
*                                                                             |
* Macros: _qc_process_tfl_trtvar_names                                        |                    
*                                                                             |
* Assumptions: required treatment as per EDP1867-101                          |                                            
*                                                                             |
* ____________________________________________________________________________|
* PROGRAM HISTORY                                                             |
*  21SEP2021  |   Kaja Najumudeen | Original version of the code              |
* ----------------------------------------------------------------------------|
\*****************************************************************************/
%macro _qc_process_tfl_trtvar_names(indata=,outdata=,debug=)/mindelimiter=' ';
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
  %if %index(&indata.,.) > 0 %then %let ptfl_data_name=%scan(&indata.,2,.);
  %else %let ptfl_data_name=&indata.;
%end;

%if %bquote(%superq(outdata))= %then %do;
  %put %str(UER)ROR: output dataset name is missing. Macro will exit now from processing;
  %GOTO MSTOP;
%end;

%if %bquote(&debug.) eq %then %let debug=0;
%if %bquote(&debug.) in (y Y yes YES 1) %then %let debug=1;
%if %bquote(&debug.) in (n N no NO 0) %then %let debug=0;

proc format;
  value $tfl_trt
  /*HV*/
  "trt_hv_0"    =  " "    
  "trt_hv_1"    =  " "    
  "trt_hv_2"    =  "trt_hv_2"    
  "trt_hv_3"    =  " "    
  "trt_hv_4"    =  "trt_hv_5"    
  "trt_hv_5"    =  " "    
  "trt_hv_6"    =  "trt_hv_3"    
  "trt_hv_7"    =  " "    
  "trt_hv_8"    =  "trt_hv_6"    
  "trt_hv_99"   =  " "   
  "trt_hv_100"  =  "trt_hv_1"  
  "trt_hv_199"  =  " "  
  "trt_hv_200"  =  "trt_hv_4"  
  "trt_hv_299"  =  " "  
  /*AD*/
  "trt_ad_0"    =  " "    
  "trt_ad_1"    =  " "    
  "trt_ad_2"    =  " "    
  "trt_ad_3"    =  " "    
  "trt_ad_4"    =  "trt_ad_2"    
  "trt_ad_5"    =  " "    
  "trt_ad_6"    =  " "    
  "trt_ad_7"    =  " "    
  "trt_ad_8"    =  " "    
  "trt_ad_99"   =  " "   
  "trt_ad_100"  =  "trt_ad_1"  
  "trt_ad_199"  =  " "  
  "trt_ad_200"  =  " "  
  "trt_ad_299"  =  " "  
  /*PS*/
  "trt_ps_0"    =  " "    
  "trt_ps_1"    =  " "    
  "trt_ps_2"    =  " "    
  "trt_ps_3"    =  " "    
  "trt_ps_4"    =  "trt_ps_2"    
  "trt_ps_5"    =  " "    
  "trt_ps_6"    =  " "    
  "trt_ps_7"    =  " "    
  "trt_ps_8"    =  " "    
  "trt_ps_99"   =  " "   
  "trt_ps_100"  =  "trt_ps_1"  
  "trt_ps_199"  =  " "  
  "trt_ps_200"  =  " "  
  "trt_ps_299"  =  " "  
  /*AS*/
  "trt_as_0"    =  " "    
  "trt_as_1"    =  " "    
  "trt_as_2"    =  " "    
  "trt_as_3"    =  " "    
  "trt_as_4"    =  "trt_as_2"    
  "trt_as_5"    =  " "    
  "trt_as_6"    =  " "    
  "trt_as_7"    =  " "    
  "trt_as_8"    =  " "    
  "trt_as_99"   =  " "   
  "trt_as_100"  =  "trt_as_1"  
  "trt_as_199"  =  " "  
  "trt_as_200"  =  " "  
  "trt_as_299"  =  " "  
  ;
run;

proc contents data=&indata. noprint out=_ptfl_contents;
run;

proc sort data=_ptfl_contents;
  by memname varnum;
run;

data _ptfl_contents;
  length new_name rename $32. new_re_name re_name as_name $100.;
  set _ptfl_contents;
  by memname varnum;
  name=lowcase(name);
  if index(name,"trt_")>0 then do;
    rename="var"||strip(put(varnum,best.));
	new_name=strip(put(name,$tfl_trt.));
  end;
  if cmiss(name,rename)=0 then re_name=catx("=",name,rename);
  if cmiss(new_name,rename)=0 then as_name=catx("=",new_name,rename)||";";
  if cmiss(new_name,rename)=0 then new_re_name=catx("=",rename,new_name);
run;

data _ptfl_contents_meta;
  length renames assigns new_renames $32767.;
  set _ptfl_contents;
  by memname varnum;
  if cmiss(libname,memname)=0 then indata=catx(".",libname,memname);
  retain renames assigns new_renames;
  if first.memname then renames=strip(re_name);
  else renames=strip(renames)||" "||strip(re_name);
  if first.memname then assigns=strip(as_name);
  else assigns=strip(assigns)||" "||strip(as_name);
  if first.memname then new_renames=strip(new_re_name);
  else new_renames=strip(new_renames)||" "||strip(new_re_name);
  if last.memname then output;
run;


filename _ptfl_ temp;
data _null_;
  set _ptfl_contents_meta end=eof;
  file _ptfl_;
  put "data &outdata.(rename=(" new_renames '));';  
  put '  set ' indata '(rename=(' renames '));' ;  
/*  put '  ' assigns;*/
  put 'run;';  
run;

%include _ptfl_;
filename _ptfl_;

*------------------------------------------;
* clean the datastep processing            ; 
* -----------------------------------------;
%if ^ &debug. %then %do;
  proc datasets lib=work nodetails noprint;
    delete _ptfl_: ;
  quit;
%end;

%MSTOP: ;
%mend _qc_process_tfl_trtvar_names;
