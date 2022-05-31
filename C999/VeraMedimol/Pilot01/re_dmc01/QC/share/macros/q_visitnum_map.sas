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
* Program              : q_visitnum_map.sas                                 |
* ____________________________________________________________________________|
* Macro to remap the visitnum and visit for different cohorts thats follows   | 
* different visit pattern                                                     | 
*                                                                             |
* Input files:                                                                |
* Macro Parameters                                                            |
* ----------------------------------------------------------------------------|
* inlib               = input libref where parent datasets exist              |
* vispair_suffix      = suffix to be attached to the visitnum/visit pair      |
*                       variables after processing                            |
*                       Default value is _new                                 |
* select              = name of the dataset(s) to be processed for visitnum/  |
*                       visit mapping. Multiple datasets are space delimited  |
* debug               = logical value specifying whether debug mode is        |
*                       on or off.                                            |
*                                                                             |
* Output files:                                                               |
* Macro Parameters                                                            |
* ----------------------------------------------------------------------------|
* outlib              = list of variable names in the dataset in DATA macro   |
*                       parameter to be used in byvar statement               |
* outdata_suffix      = suffix to be attached to the output dataset after     |
*                       visitnum/vist variables are processed                 |
*                                                                             |
* Macros: _qc_visitnum_map,_qc_checkvar_create, _qc_gen_quotetoken            |                    
*                                                                             |
* Assumptions: macro checks for the visit pair variables visitnum and visit   |  
*              and process only when it exists                                | 
*                                                                             |
* ____________________________________________________________________________|
* PROGRAM HISTORY                                                             |
*  12OCT2021  |   Kaja Najumudeen | Original version of the code              |
* ----------------------------------------------------------------------------|
\*****************************************************************************/
%macro q_visitnum_map(inlib=, vispair_suffix=, select=, outlib=, 
outdata_suffix=,debug=)/mindelimiter=' ';
option validvarname=v7 MAUTOSOURCE minoperator;
%if %nrbquote(%superq(select)) ^= %then %do;
  %q_gen_quotetoken(keyword=&select.,delim=%str( ),outmvar=selectQ);
  %q_gen_quotetoken(keyword=&select.,delim=%str( ),outmvar=selectnQ,quote=N);
%end;
%else %do;
  proc sql noprint;
    create table _vm_sel_dsn as
      select a.memname 
      from dictionary.tables as a
      where upcase(libname)=upcase("&inlib.");
      select distinct memname into: _vm_select_chose separated by " "
      from _vm_sel_dsn
      ;
    quit;
  %put VMSELECT_CHOSE= &_vm_select_chose.;
  %let select=&_vm_select_chose.;
  %q_gen_quotetoken(keyword=&select.,delim=%str( ),outmvar=selectQ);
  %q_gen_quotetoken(keyword=&select.,delim=%str( ),outmvar=selectnQ,quote=N);
%end;
%if %nrbquote(&outlib.) eq %then %let outlib=work;
%if %nrbquote(&vispair_suffix.) eq %then %let vispair_suffix=_new;
*----------------------------------------;
* Check for debug macro parameter   ;
* ---------------------------------------;
%if %bquote(&debug.) eq %then %let debug=0;
%if %bquote(&debug.) in (y Y yes YES 1) %then %let debug=1;
%if %bquote(&debug.) in (n N no NO 0) %then %let debug=0;

%if %nrbquote(%superq(select))^= %then %do;
%do _vlm_=1 %to &selectQ_C.;
  *parent dataset;
  %if %sysfunc(exist(&inlib..%sysfunc(scan(&select.,&_vlm_.,%str( ))))) %then %do;
    data _vm_parent&_vlm_.;
      set &inlib..&&selectnQ&_vlm_.;
    run;
    %q_checkvar_create(data=_vm_parent&_vlm_.
                        ,vars=visit
                        ,varstype=2
                        ,create=1
                        ,outdata=_vm_parent&_vlm_.
                        ,debug=&debug.
                        );

    %q_checkvar_create(data=_vm_parent&_vlm_.
                        ,vars=visitnum
                        ,varstype=1
                        ,create=1
                        ,outdata=_vm_parent&_vlm_.
                        ,debug=&debug.
                        );
    data _vm_parent&_vlm_.;
		  length _vm_vis_decode $200.;
      set _vm_parent&_vlm_.;
      _vm_visit=visit;
      _vm_visitnum=visitnum;
      if _vm_visit ne '' then do;
        if index(upcase(_vm_visit),"FUP -") > 0 then _vm_visit=tranwrd(_vm_visit,"FUP -", "FUP ");
        if index(lowcase(_vm_visit),"-") > 0 & countc(_vm_visit,"-")=2 then do;
				  _vm_prd_decode=scan(_vm_visit,1,"-");
          _vm_vis_decode=scan(_vm_visit,2,"-");
        end;
        else if index(lowcase(_vm_visit),"-") > 0 & countc(_vm_visit,"-")=1 then do;
				  _vm_prd_decode="Period 1";
          _vm_vis_decode=scan(_vm_visit,1,"-");
        end;
        else if index(lowcase(_vm_visit),"(") > 0 & countc(_vm_visit,"-")=0 then do;
				  _vm_prd_decode="Period 1";
          _vm_vis_decode=scan(_vm_visit,1,"(");
        end;
        else do;
				  _vm_prd_decode="Period 1";
          _vm_vis_decode=_vm_visit;
        end;
        if index(_vm_vis_decode,".") >0 then _vm_vis_decode=scan(_vm_vis_decode,1,".");
      end;
      if nmiss(_vm_visitnum)=0 then do;
        _vm_visitnum_rep=_vm_visitnum-int(_vm_visitnum);
      end;
      _vm_vis_decode=compbl(strip(_vm_vis_decode));
      _vm_prd_decode=compbl(strip(_vm_prd_decode));
			if not missing(_vm_prd_decode) then _vm_prd_code=100*(lowcase(_vm_prd_decode)="period 1")+200*(lowcase(_vm_prd_decode)="period 2");
			if _vm_prd_code=0 then _vm_prd_code=.;
      if not missing(_vm_vis_decode) then do;
				if lowcase(_vm_vis_decode)="screening" and not missing(_vm_prd_code) then _vm_vis_code=1+_vm_prd_code;
				else if lowcase(_vm_vis_decode)="baseline" and not missing(_vm_prd_code) then _vm_vis_code=2+_vm_prd_code;
        else do;
          if compress(_vm_vis_decode,"0123456789","k") ne '' and not missing(_vm_prd_code) then _vm_vis_code=input(compress(_vm_vis_decode,"0123456789","k"),best.)+2+_vm_prd_code;
				end;
      end;
      if nmiss(_vm_vis_code,_vm_visitnum_rep)=0 then _vm_vis_code=_vm_vis_code+_vm_visitnum_rep;
    run;
    %if %bquote(&outlib.) ne %then %do;
      data &&outlib..&&selectnQ&_vlm_.&&outdata_suffix.;
        set _vm_parent&_vlm_.;
        visitnum&vispair_suffix.=_vm_vis_code;
        visit&vispair_suffix.=_vm_vis_decode;
        %if ^ &debug. %then %do;
          drop _vm_: ;
        %end;
      run;
    %end;
	%end;
%end;
%end;
*------------------------------------------;
* clean the processing if any          ; 
* -----------------------------------------;
%if ^ &debug. %then %do;
  proc datasets lib=work nodetails noprint;
    delete _vm_: ;
  quit;
%end;

%MSTOP: ;
%mend q_visitnum_map;
