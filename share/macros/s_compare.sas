 /*****************************************************************************\
*        O                                                                      
*       /                                                                       
*  O---O     _  _ _  _ _  _  _|                                                 
*       \ \/(/_| (_|| | |(/_(_|                                                 
*        O                                                                      
* ____________________________________________________________________________
* Sponsor              : Veramed
* Study                : None
* Program              : s_compare
* Purpose              : Flexible proc compare + extended comparison (i.e. variable name case, variable position)
* ____________________________________________________________________________
* DESCRIPTION   
*           Standard macro for comparing either individual datasets, or a library of datasets
*           In addition to a classic proc compare, returns codes are used to target additional detail and provide 
*           additional summaries from the execution.
*           By working with the returns codes, we are able to tailor the summary report to ignore certain items checked (e.g. variabel length)
*           where not neccessary          
*    
*  Input Macro Parameters
*      See macro code for details
*
*
* Example macro calls in standard use.
*
*  Single ADaM Dataset call - within QC program
*    %s_compare(base=ADAM.ADSL,comp=ADAMQC.Q_ADSL);
*
*  Single TFL dataset call within QC program
*    %s_compare(base=TFL.T1401010101,comp=TFLQC.Q_T140101010101,TFL=Y);
*
*  Batch ADaM data call via FINAL.SAS program
*    %s_compare(base=ADAM._ALL_,
*               comp=ADAMQC._ALL_,
*               comprpt =%str(<FILEPATH\FILENAME.PDF>));
*
*  Batch TFL call via FINAL.SAS program
*    %s_compare(base=TFL._ALL_,
*               comp=TFLQC._ALL_,
*               tfl=Y,
*               comprpt =%str(<FILEPATH\FILENAME.PDF>));
*
* Input files: Selectged datasets, or libraries of datasets
*              
* Output files: Primary output is LST or PDF output summarising the results of PROC COMPARE
*               
* Macros: None
*         
* Assumptions: 
* Global variables required for processing from %INIT macro.  If not present a default will be set to enable stand alone execution
*   _STUDYID = to add current study name on output
*   _SPLIT   = if split character controlled centrally, this variable is used.  If not present, the macro variable in call is used
*
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*  10-11JUN2020  | Otis Rimmer  | Original version
* MH additions - ONGOING 
*  18May2022     | Mark Holland | Allowed split char to be controlled from outside macro call in study level autoexec
*                                 Fixed bug on how splitchar was being applied to variable labels - num and char
*                                 Fixed bug on cmpbl function by adding left justification
*  23May2022     | Mark Holland | Added functionlaity when TFL=Y to drop recording ordering vars from compare if present
\*****************************************************************************/

%macro s_compare(
                    /* primary options for selecting data to compare */
    base=,                      /* [Required] : The Base dataset.  */
                                /*              If comparing library use convention <ProdLibname>._ALL_ */
    comp=,                      /* [Required] : The Comp dataset.  */
                                /*              If comparing library use convention <QCLibname>._ALL_ */

    options=,                   /* [Not Required]: compare options to apply to PROC COMPARE statement */
    idvars=,                    /* [Not Required]: List of ID variables to use in proc compare, if specified  */
                                /*                  can only be used when comparing datasets pairs (not _ALL_)*/

                      /* options to control depth of results.  Expected only to be used on TFL dataset compares */
    criterion=,                 /* [Not Required]: Acceptable difference for Criterion (i.e. 1E-12, 1E-17 etc) */
    IgnoreMask = 0,             /* [Required]: Given a default value of 0. This is a + separated list of codes 
                                                to ignore from proc compare SYSINFO, which details the mismatches 
                                                Note that you can also specify the sum (see ex macro calls) */
    TFL=N,                      /* [Required] : Pre-fills IgnoreMask values with the recommended masks for TFL checking */
                                /*              and also defaults COMPBL to text variables */
    splitchar=,                 /* [Not Required]: The character which is used to split labels/character string
                                                   when selected this is removed from strings before the compare occurs */
    compbl=N,                   /* [Not Required]: Specify Y to change repeated spaces into one space variables */
    compress=N,                 /* [Not Required]: Specify Y to remove all spaces from character variables */

                       /* debugging options if needed given log is turns off to preven false positives */
    tidyup=Y,                   /* [Not Required]: Specify Y to remove temporary datasets created by macro  */  
                                /*                 if DEBUG=Y then tidy forced to N to retain work datasets */
    debug=N,                    /* [Not required]: N = all log messaging supressed to prevent log check counting */
                                /*                 Y = Macro Debug options switched on and SAS log visible */

                        /* Following parameters only relavent when runing against a full library */
    comprpt=,                   /* [Required - against library]: full path name and filename of the PDF report generated */
                                /*                 suggested standard files names should be followed                     */
    prefix=Q_                   /* [Not required]: If comparing a library, it is assumed the dataset names in COMP and BASE */
                                /*                  libraries are the same name - other than Q_ prefix.                     */
                                /*                  IF prefix differnt, or needs to be null, this can be reset              */
    );

%****************************************************************************************

                                Example macro calls;

%****************************************************************************************;


%PUT TRACE: [Macro: S_COMPARE] Starting.;

 %**Obtain options changed by DEBUG to enable reset if neccessary **;
%local ___mprint ___notes ___sgen ___mlogic ___source;
%let ___mprint=%sysfunc(getoption(mprint));
%let ___notes =%sysfunc(getoption(notes));
%let ___sgen  =%sysfunc(getoption(sgen));
%let ___mlogic=%sysfunc(getoption(mlogic));
%let ___source=%sysfunc(getoption(source));

%** Set options based on the DEBUG value ;
%if %upcase(&debug=N) %then %do;
  options nomprint nonotes nosgen nomlogic nosource;
  %PUT TRACE: [MACRO: S_COMPARE] DEBUG=N. SAS log supressed to prevent double counting in SASLog scan;
%end;
%else %if %upcase(&debug=Y) %then %do;
    options mprint  notes    sgen   mlogic   source;
    %PUT TRACE: [MACRO: S_COMPARE] DEBUG=Y. SAS log fully visible to review and all work datasets present.  Users options are reset at end of call;
    %let tidyup=N;
%end;

   %** check for required global variables.  If not present then create a default to allow stand alone execution **;
%if %symexist(_studyid) = 0 %then %do;
    %let _studyid=<TBC>;
    %PUT TRACE: [MACRO: s_scanlog] _STUDYID did not exist.  set to <TBC> to allow execution;
%end;
%if %symexist(_split) = 0 %then %do;
    %let _split=;
    %PUT TRACE: [MACRO: s_scanlog] _SPLIT did not exist.  set to NULL to allow execution;
%end;

 %** Complile file on file processing section for later execution **;
%macro ___COMP;

    %****************************************************************************************
                                    STANDARDIZE MACRO PARAMETERS;
    %****************************************************************************************;

    %let tidyup        = %upcase(&tidyup);
    %let compbl        = %upcase(&compbl);
    %let compress      = %upcase(&compress);
    %let tfl           = %upcase(&tfl);
    %let splitchar     = %cmpres(%nrbquote(&splitchar));

    %* Create the dataset name with no input options;
    %let _compnoopts = %scan(%superq(comp),1,%str(%());
    %let _basenoopts = %scan(%superq(base),1,%str(%());

    %****************************************************************************************
                              MACRO PARAMETER SENSE CHECK SECTION;
    %****************************************************************************************;

    %* If compressing all spaces and removing repeated spaces specified, then compression takes precedence;
    %if %bquote(&compress) = Y and %bquote(&compbl) = Y %then 
      %put %str(TRA)CE: [MACRO:S_COMPARE] COMPRESS and COMPBL set.  COMPRESS will take precedence; 


    %* Check IGNOREMASK is provided;
    %if %superq(IGNOREMASK) = %then %do;
      %put %str(DEB)UG: [MACRO:S_COMPARE] Ignore Mask macro parameter is not populated;
      %goto leave;
    %end;

      %* Check prod dataset is provided;
    %if %superq(base) = %then %do;
      %put %str(DEB)UG: [MACRO:S_COMPARE] Base dataset macro parameter is not populated;
      %goto leave;
    %end;

    %* Check qc dataset is provided;
    %if %superq(comp) = %then %do;
      %put %str(DEB)UG: [MACRO:S_COMPARE] Comp dataset macro parameter is not populated;
      %goto leave;
    %end;

    %* Check prod dataset exists;
    %if ^%sysfunc(exist(&_basenoopts)) %then %do;
      %put %str(DEB)UG: [MACRO:S_COMPARE] Dataset &_basenoopts does not exist;
      %goto leave;
    %end;

    %* Check QC dataset exists;
    %if ^%sysfunc(exist(&_compnoopts)) %then %do;
      %put %str(DEB)UG: [MACRO:S_COMPARE] Dataset &_compnoopts does not exist;
      %goto leave;
    %end;



    %* Check if all the ID Variables are present on the input dataset;
    %macro ___idvarchk(type=);

        data _&type.;
          set &&&type.;
        run;

        %do _j = 1 %to %sysfunc(countw(%bquote(&idvars.),%str( )));
          %let _var  = %scan(%bquote(&idvars.),&_j);
          %let _dsid = %sysfunc(open(_&type.));
          %if %sysfunc(varnum(&_dsid,&_var)) = 0 %then %do;
            %let rc = %sysfunc(close(&_dsid));

            proc datasets nolist mt=data lib=work nodetails;
              delete _&type.;
            quit;

            %put %str(ERR)OR: Variable &_var is listed as ID var but not present on dataset &&&type;
            %abort cancel;
          %end;
          %else %do;
            %let rc = %sysfunc(close(&_dsid));
          %end;
        %end;

        proc datasets nolist mt=data lib=work nodetails;
          delete _&type.;
        quit;

    %mend ___idvarchk;

    %___idvarchk(type=base);
    %___idvarchk(type=comp);


    %****************************************************************************************
                            for TFL compares, process standard blanks mask and split;
    %****************************************************************************************;


    %* check TFL flag set;
    %if &TFL = %str() %then %do;
      %put %str(DEB)UG: [MACRO:S_COMPARE] TFL Flag not set;
      %goto leave;
    %end;

    %** force on COMPBL option / default values for Mask / Split char if centrally defined **;
    %else %if &TFL=Y %then %do;
       %let compbl=Y;
       %let IgnoreMask=1+2+4+8+16;

        %** If split character SPLITCHAR in macro call is null, but system variable _split is present.  use that for split char processing     **;
        %** This means any value in direct macro call takes presedence.  However, if central controll in place, this is actioned only if TFL=Y **;
       %if %bquote(&splitchar) = %str() %then %do;
           %if %bquote(&_split) ne %str() %then %do;
              %let splitchar=%str(&_split);
           %end;
       %end;
       footnote1 "TFL COMPARE SELECTION MADE.  The Following controlled issues are not directly highlighted as a problem";
       footnote2 "Dataset label/type.  Var length/format/informat. Blanks compressed. Report ORDER vars and split chars dropped";
       %put %str(TRA)CE: [MACRO:S_COMPARE] TFL selected.  All blanks compressed with COMPBL;
       %put %str(TRA)CE: [MACRO:S_COMPARE] TFL selected.  Selected checks ignored var length, format, informat and dataset label;
    %end;

     %** Set split message **;
    %if %quote(&splitchar) ne %str() %then %put %str(TRA)CE: [MACRO:S_COMPARE] Split character &splitchar will be supressed from data before compare;
   

    %****************************************************************************************
                                       The SYSINFO code and decode list
    %****************************************************************************************;

    data _decode;
     length varc $200.;
      
        * Default PROC COMPARE System information codes;
        varn = 1;       varc = 'Data set labels differ';                               output;
        varn = 2;       varc = 'Data set types differ';                                output;
        varn = 4;       varc = 'Variable has different informat';                      output;
        varn = 8;       varc = 'Variable has different format';                        output;
        varn = 16;      varc = 'Variable has different length';                        output;
        varn = 32;      varc = 'Variable has different label';                         output;
        varn = 64;      varc = 'Base data set has observation not in comparison';      output;
        varn = 128;     varc = 'Comparison data set has observation not in base';      output;
        varn = 256;     varc = 'Base data set has BY group not in comparison';         output;
        varn = 512;     varc = 'Comparison data set has BY group not in base';         output;
        varn = 1024;    varc = 'Base data set has variable not in comparison';         output;
        varn = 2048;    varc = 'Comparison data set has variable not in base';         output;
        varn = 4096;    varc = 'A value comparison was un' !! 'equal';                 output; %* Split to prevent false positive on log check **;
        varn = 8192;    varc = 'Conflicting variable types';                           output;
        varn = 16384;   varc = 'BY variables do not match';                            output;
        varn = 32768;   varc = 'Fatal error: comparison not done';                     output;
        * Start of Extended System information codes;
        varn = 65536;   varc = 'Base dataset modified after comparison dataset';       output;
        varn = 131072;  varc = 'Variable order differs (for variables in common)';     output;** CHECK NOT PRESENT BUT VALUE RETAINED IN LIST **;
        varn = 262144;  varc = 'Variable name has different case';                     output;** CHECK NOT PRESENT BUT VALUE RETAINED IN LIST **;
        varn = 524288;  varc = 'Dataset(s) not in IDVAR order (had to sort)';          output;
        varn = 1048576; varc = 'ID Variables are not unique to a record in Dataset(s)';output;

    run;

    data _null_;
      set _decode end=eof;

       total+varn;
       ** total count created to check user no supressing everything **;
      if eof then do;
       call symputx('ignorechk',total);
       put "Ignorechk = " total;
      end;

    run;

    %****************************************************************************************
                    Check if IGNOREMASK is specified as a set of integers added
    %****************************************************************************************;

    %local _oldignoremask;
    %let _oldignoremask = &ignoremask.;

    %let ignoremask = %eval(&ignoremask);

     %** check is everything being ignored **;
    %if &ignorechk = &ignoremask %then %do;
      %put %str(DEB)UG: [MACRO:Compare] All issues being ignored - please check for at least one issue;
      %goto leave;
    %end;


    %****************************************************************************************
       APPLY RELEVANT PREPROCESSING ON DATASET(S) AND OBTAIN VARIABLE INFORMATION;
    %****************************************************************************************;

    %macro ___precomp(type=);


         %** Force some key parms to null to ensure present at start **;
       %local __dsetlbl lblchgc lblchgn;
       %let __dsetlbl=;
       %let lblchgc=0;  ** forced in case no char vars **;
       %let lblchgn=0;  ** forced in case no num vars **;

         %** The modified date and label of the original datasets will be needed, so this will be kept;
        proc contents data = &&_&type.noopts out = _&type.modate(keep=modate memlabel) noprint;
        run;

        proc sort data = _&type.modate nodupkey;
          by modate memlabel;
        run;

        data _&type.modate(drop=memlabel);
          set _&type.modate;

          rename modate = &type.modate;
          dummy = 1;
          call symput('__dsetlbl',trim(left(memlabel)));

        run;
       

         %** Identify any variable allowed to be dropped from compare from either side - when TFL selected **;
         %** Per agreed standard these variable only contain order data.  NEVER subject data or results **;
         %** Variable to drop are ROWORD BYORD1-n ROWGRP1-n **;
         %** Set vars to null initially before population **;
        %local __dropvars __drop;
        %global _addstr3;
        %let   __drop=;       %** DROP statement to apply to data step **;
        %let   __dropvars=;   %** List of variables into the DROP statement **;

         %** set _addstr3 for use in report list of allowable adaptations **;
         %** Number of cycles through macro is controlled, hence for first set to null, and drop vatr for second cycle **;
        %if  &type=comp %then %let _addstr3=;

        %if &TFL=Y %then %do;
             %** Check for presence of agreed order variables and build DROP statement if any present - for TFL processing only **;
            %let dsid = %sysfunc(open(&&&type));
            %if %sysfunc(varnum(&dsid, ROWORD))  gt 0 %then %let __DROPVARS= &__DROPVARS ROWORD;;
            %if %sysfunc(varnum(&dsid, BYORD1))  gt 0 %then %let __DROPVARS= &__DROPVARS BYORD:;;
            %if %sysfunc(varnum(&dsid, ROWGRP1)) gt 0 %then %let __DROPVARS= &__DROPVARS ROWGRP:;;
            %if &__DROPVARS ne %str() %then %let __drop= %str((drop= &__dropvars));
            %let rc = %sysfunc(close(&dsid));

            %if &__dropvars ne %str() %then %do;
                 %put %str(TRA)CE: [MACRO:S_COMPARE] TFL selected.  Variables &__dropvars dropped from &type dataset &&_&type.noopts before compares;;
                 %let _addstr3=&__dropvars VARS DROPPED;
            %end;
        %end;

        data _&type.;
          set &&&type. &__drop;
        run;


        * Check that there are at least some character variables on the input dataset,
           following the (potential) removal of any spaces/split characters etc;

        proc contents data = _&type. out = _charcount&type.(where=(type=2)) noprint;
        run;

         %local _dsid _charcnt _rc;
         %let _dsid    = %sysfunc(open (_charcount&type.));
         %let _charcnt = %sysfunc(attrn(&_dsid, nobs));
         %let _rc      = %sysfunc(close(&_dsid));

        proc contents data = _&type. out = _numcount&type.(where=(type=1)) noprint;
        run;

         %local _dsid _numcnt _rc;
         %let _dsid    = %sysfunc(open (_numcount&type.));
         %let _numcnt  = %sysfunc(attrn(&_dsid, nobs));
         %let _rc      = %sysfunc(close(&_dsid));

        data _&type.;
          set _&type.;

            %if &_charcnt > 0 %then %do;
            * Obtain the character variables and the respective labels;
            * Also, apply any split character, space removal (entirely or just repeated spaces) here;
              array _charall_ {*} _character_;

              do __ii__ = 1 to dim(_charall_);

                if ^missing("&splitchar") then do;
                  _charall_(__ii__) = tranwrd(_charall_(__ii__)," &splitchar. ", "  ");
                  _charall_(__ii__) = tranwrd(_charall_(__ii__),"&splitchar. ", " ");
                  _charall_(__ii__) = tranwrd(_charall_(__ii__)," &splitchar.", " ");
                  _charall_(__ii__) = tranwrd(_charall_(__ii__),"&splitchar.", " ");

                  * Apply modifications to the label also;
                  __vlabel__ = vlabel(_charall_(__ii__)); 
                  __vlabel__ = tranwrd(__vlabel__," &splitchar. ", "  ");
                  __vlabel__ = tranwrd(__vlabel__,"&splitchar. ", " ");
                  __vlabel__ = tranwrd(__vlabel__," &splitchar.", " ");
                  __vlabel__ = tranwrd(__vlabel__,"&splitchar.", " ");

                  call symputx(cats("labelc",__ii__),__vlabel__,"L");
                  call symputx(cats("namec" ,__ii__),vname (_charall_(__ii__)),"L");
                  call symputx("lblchgc"            ,dim(_charall_)           ,"L");
                end;

                if "&compbl" = "Y" then do;
                  _charall_(__ii__) = left(compbl(_charall_(__ii__)));
                end;
                if "&compress" = "Y" then do;
                  _charall_(__ii__) = compress(_charall_(__ii__));
                end;

              end;

              drop __ii__ __vlabel__;

            %end;

        run;
 
        %if &_numcnt > 0 %then %do;

            data _null_;
              if 0 then set _&type.;

              array _numall_ {*} _numeric_;

              do __jj__ = 1 to dim(_numall_);

                if ^missing("&splitchar") then do;
                  * Apply modifications to the label also;
                  __vlabel__ = vlabel(_numall_(__jj__)); 
                  __vlabel__ = tranwrd(__vlabel__," &splitchar. ", "  ");
                  __vlabel__ = tranwrd(__vlabel__,"&splitchar. ", " ");
                  __vlabel__ = tranwrd(__vlabel__," &splitchar.", " ");
                  __vlabel__ = tranwrd(__vlabel__,"&splitchar.", " ");

                  call symputx(cats("labeln",__jj__),__vlabel__,"L");
                  call symputx(cats("namen" ,__jj__),vname (_numall_(__jj__)),"L");
                  call symputx("lblchgn"            ,dim(_numall_)            ,"L");
                end;

              end;

              drop __jj__;
              stop;

            run;

        %end;

        proc datasets lib=work mt=data nolist nodetails;

           ** reapply dataset label to ensure valid comparion ;
          modify _&type.  %if %bquote(&__dsetlbl) ne %str() %then (label="&__dsetlbl");;

           ** Apply updated var labels without split (if this was specified);
          %if %nrbquote(&splitchar) ne %then %do;
            %local _ii _jj;
            label 
            %do _ii = 1 %to &lblchgc.;
              &&namec&_ii = "&&labelc&_ii"
            %end;
            %do _jj = 1 %to &lblchgn.;
              &&namen&_jj = "&&labeln&_jj"
            %end;
          ;
          %end;
          ;
        quit;
           

        * Produce variable information about the datasets;
/*        proc contents data = _&type. out = _&type.info noprint;*/
/*        run;*/
/**/
/*        data _&type.info;*/
/*          set _&type.info;*/
/*          uname = upcase(name);*/
/*        run;*/
/**/
/*        proc sort data = _&type.info presorted;*/
/*          by uname;*/
/*        run;*/

         %** If IDVARS quoted - check if data sorted by these quoted variables **;
        %if %nrbquote(&idvars.) ne %then %do;

          data &type._presorted;
            set _&type.;
          run;

          proc sort data = _&type. presorted;
            by &idvars.;
          run;

          proc compare base = &type._presorted c = _&type. noprint out=_&type.sortchk;
          run;

           ** if sortchk has record it means data was not sorted by quoted ID vars and will have bene re-sorrted **;
          %local _dsid _nobs _rc;
          %let _dsid    = %sysfunc(open (_&type.sortchk));
          %let _nobs    = %sysfunc(attrn(&_dsid, nobs));
          %let _rc      = %sysfunc(close(&_dsid));

          %global _&type.sort;
          %if &_nobs > 0 %then %let _&type.sort = 0;
          %else %let _&type.sort = 1;


          * Check - IDVARs should be unique enough to each record;
          data _&type.idvarchk _&type.dupchk;
            set _&type.;
            by &idvars.;

            output _&type.idvarchk;
            if ^(first.%scan(&idvars.,-1) and last.%scan(&idvars.,-1)) then output _&type.dupchk;

          run;
           ** If dupchk has records, it means non unique records per quoted IDVARs **;
          %let _dsid    = %sysfunc(open (_&type.dupchk));
          %let _nobs    = %sysfunc(attrn(&_dsid, nobs));
          %let _rc      = %sysfunc(close(&_dsid));

          %global _&type.iduniq;
          %if &_nobs > 0 %then %let _&type.iduniq = 0;
          %else %let _&type.iduniq = 1;

          * Count number of records per group;

          proc sql;
            create table _&type.idvarchk2 as 
            select %sysfunc(tranwrd(%left(&idvars),%str( ),%str(,))), count(*) as cnt
            from _&type.idvarchk
            group by %sysfunc(tranwrd(%left(&idvars),%str( ),%str(,)));
          quit;

        %end;

 
    %mend ___precomp;

    %___precomp(type=comp);
    %___precomp(type=base);

    %****************************************************************************************

                  COMPARE AND CONTRAST THE RELEVANT VARIABLE AND DATASET METADATA;

    %****************************************************************************************;

    %* Compare on the production and qc information - these are additional summaries not produced by PROC COMPARE;
    %* Note that variables not in one dataset are ignored, as these are covered by PROC COMPARE;

    %***********************************************************************************
        Add the modification date checks (PROC COMPARE does not raise this as an issue);
    %***********************************************************************************;

    data _modatechk;
      merge _basemodate _compmodate;
      by dummy;

      call symputx("basedtm",put(basemodate,datetime.));
      call symputx("compdtm",put(compmodate,datetime.));

      if basemodate > compmodate then do;
        bitn = 2**(17-1);
        output;
      end;
    run;


    %***********************************************************************************
            *Check for sort order and if byvariables are not unique enough to identify  ;
            *User data obtained from the precomp sub-macro above                        ; 
    %***********************************************************************************;

    * Now the IDVAR checks will be concatenated on also;
    %if %nrbquote(&idvars.) ne %then %do;

        data _sortcheck;
          
          if &_compsort = 0 or &_basesort = 0 then do;
             bitn = 2**(20-1);
             output;   
          end;
        run;

        data _iduniqcheck;
      
          if &_compiduniq = 0 or &_baseiduniq = 0 then do;
             bitn = 2**(21-1);
             output;   
          end;
        run;

    %end;


    * Now combine all of these information datasets together;
    data _addinfo;
      set _modatechk %if %nrbquote(&idvars.) ne %then _sortcheck _iduniqcheck;;
    run;

    proc sort data = _addinfo nodupkey;
      by bitn;
    run;

    proc sql noprint;
      select max(0,sum(bitn)) into :_addsysinfo separated by '' from _addinfo;
    quit;

    %****************************************************************************************

                                   MAIN COMPARE SECTION;

    %****************************************************************************************;

     %* Sub section to create pre-processing string for title;
    %local _addstr1 _addstr2 _sep;
    %if &compress = Y %then %let _addstr1 = ALL SPACES REMOVED;
    %else %if &compbl = Y and ^(&compress = Y) %then %let _addstr1 = REPEATED SPACES REMOVED;
    %if %superq(splitchar) ne %then %let _addstr2 = SPLIT CHARACTER  %superq(splitchar) REMOVED;
    %*if &__dropvars ne %str() %then %let _addstr3=&__dropvars. VARS DROPPED;
    %if %superq(_addstr1) ne and %superq(_addstr2) ne %then %let _sep = %str( , );
  
%put _addstr3=&_addstr3;

    * Adding title for what is being compared and any additional pre-processing;
    * addstr3 comes from section where TFL by and order vars are identified and dropped *;
    title5 "BASE DATASET %superq(base) IS BEING COMPARED WITH COMP DATASET %superq(comp)";

    %if %superq(_addstr1) ne or %superq(_addstr2) ne or %superq(_addstr3) ne %then %do;
    title6 "ADDITIONAL PREPROCESSING APPLIED: &_addstr1.&_sep.&_addstr2.&_sep.&_addstr3.";
    %end;

    * Final proc compare section;
    proc compare b = _base 
                 c = _comp 
                 &options.
                 out = _compy_diffs;
                 %if %bquote(&criterion.) ne %then criterion=&criterion.;
                 ;

    %if %nrbquote(&idvars.) ne %then id &idvars.;;

    %put SYSINFO=&sysinfo;

    run;
     %** Add any macro made return code values into COMPARE return code value **;
    %let origsysinfo  = &sysinfo.;
    %let xSYSINFO=%eval( &sysinfo. + &_addsysinfo.);
    %let comptime = %sysfunc(date(),date9.)T%sysfunc(time(),tod8.);

    %put Original COMPARE return code     origsysinfo = &origsysinfo. ;
    %put Added macro specific return code _addsysinfo = &_addsysinfo.;

    %* Check if any preproc has been preformed (note that any dataset options applied to the input datasets
       also need to be checked, and do count as pre-processing;

    %local preproc_ _compprestr _baseprestr;
    %if (%bquote(&_compnoopts) ne %superq(comp) or %bquote(&_basenoopts) ne %superq(base)) 
      or &COMPRESS = Y or &COMPBL = Y or %superq(splitchar) ne or %superq(_addstr3) ne 
    %then %do;

      %* Flag for any pre-processing;
      %let preproc_ = Y;

      %if %bquote(&_compnoopts) ne %superq(comp) %then %let 
        _compprestr = COMP OPTIONS USED: %substr(%superq(comp), %eval ( %length(%bquote(&_compnoopts)) + 1) );

      %if %bquote(&_basenoopts) ne %superq(base) %then %let 
        _baseprestr = BASE OPTIONS USED: %substr(%superq(base), %eval ( %length(%bquote(&_basenoopts)) + 1) );

    %end;

    %****************************************************************************************

                                    OUTPUT SECTION;

    %****************************************************************************************;

     %** build messages for the SAS log based on if compare was clear, or not **;
    data _null_;

       %** Note that 22 is used as have 21 conditions for SYSINFO;
       %** If any valid message triggered (after ignore values removed) it means there are issues to report **;
      if band(&xSYSINFO.,(2**22-1)-&IgnoreMask) then do;
      
         if "&preproc_" = "Y" and &ignoremask ne 0 then do;
           put  "DEB" "UG: [MACRO:S_COMPARE]" " (1): Datasets &_basenoopts and &_compnoopts differ or have other issues";
           put  "DEB" "UG: [MACRO:S_COMPARE]" " (2): After pre-processing and ignoring info codes (IgnoreMask)";
         end;

         else if "&preproc_" = "Y" then do;
           put  "DEB" "UG: [MACRO:S_COMPARE]" " (1): Datasets &_basenoopts and &_compnoopts differ or have other issues";
           put  "DEB" "UG: [MACRO:S_COMPARE]" " (2): After pre-processing";
         end;

         else if &ignoremask ne 0 then do;
           put  "DEB" "UG: [MACRO:S_COMPARE]" " (1): Datasets &_basenoopts and &_compnoopts differ or have other issues";
           put  "DEB" "UG: [MACRO:S_COMPARE]" " (2): After ignoring info codes (IgnoreMask)";
         end;

         else do;
           put  "DEB" "UG: [MACRO:S_COMPARE] (1): Datasets &_basenoopts and &_compnoopts differ or have other issues";
         end;

      end;

       %** if compare is clean report based on whether pre-processing took place or not **;
      else if &xSYSINFO. or "&preproc_" = "Y" then do;

         if "&preproc_" = "Y" and &xSYSINFO. then do;
           put "TRA" "CE: [MACRO:S_COMPARE] (1): Datasets &_basenoopts and &_compnoopts compare OK";
           put "TRA" "CE: [MACRO:S_COMPARE] (2): After pre-processing and ignoring info codes (IgnoreMask)";
         end;

         else if "&preproc_" = "Y" then do;
           put "TRA" "CE: [MACRO:S_COMPARE] (1): Datasets &_basenoopts and &_compnoopts compare OK";
           put "TRA" "CE: [MACRO:S_COMPARE] (2): After pre-processing";
         end;

         else if &ignoremask ne 0 then do;
           put "TRA" "CE: [MACRO:S_COMPARE] (1): Datasets &_basenoopts and &_compnoopts compare OK";
           put "TRA" "CE: [MACRO:S_COMPARE] (2): After ignoring info codes (IgnoreMask)";
         end;

      end;

      else if &xSYSINFO. = 0 then do;
        put "TRA" "CE: [MACRO:S_COMPARE]: Datasets &_basenoopts and &_compnoopts compare identical.";
      end;

    run;
        

    ** Build all results into a dataset to present summary results to user **; 
    data _compy_result;

      ComparisonDTM = input("&comptime.",datetime.);
        label ComparisonDTM = 'DateTime of Comparison';
        format ComparisonDTM datetime.;

      length Base $200.;
      Base = "&_basenoopts";
        label Base = "Base Dataset";

      BaseDTM = input("&basedtm.",datetime.);
        label BaseDTM = 'DateTime of Base Dataset';
        format BaseDTM datetime.;    

      length Comp $200.;
      Comp = "&_compnoopts";
        label Comp = "Comp Dataset";

      CompDTM = input("&Compdtm.",datetime.);
        label CompDTM = 'DateTime of Comp Dataset';
        format CompDTM datetime.; 
     
      length PreProc $2000.;
      if "&preproc_" = "Y" then PreProc = catx(" ; ", "Yes: &_addstr1.&_sep.&_addstr2.&_sep.&_addstr3. ", "&_compprestr", "&_baseprestr");
        label PreProc = "Pre-Processing applied to both datasets";

      xSYSINFO = &xSYSINFO.;
        label xSYSINFO = "Extended SYSINFO return value";

      length IgnoreMask $500.;
      IgnoreMask = "&_oldignoremask";
        label IgnoreMask = 'Extended SYSINFO bits to ignore';
       
      length compstatus $200.;

      * If any issues;
      if band(&xSYSINFO.,(2**22-1)-&IgnoreMask) then do 
        CompStatusN = 0;
        CompStatus = 'Issues';
      end;

      * Matches, aside from some masked issues;
      if ^(band(&xSYSINFO.,(2**22-1)-&IgnoreMask)) and band(&xSYSINFO.,(2**22-1)) then do;
        CompStatusN = 1;
        CompStatus = 'Matches with planned masked issues accepted';
        if "&preproc_" = "Y" then CompStatus = 'Matches with planned masked issues accepted and preproc applied';
      end;

      * If nothing comes up;
      else if ^(band(&xSYSINFO.,(2**22-1)-&IgnoreMask)) and ^band(&xSYSINFO.,(2**22-1)) then do;
        if "&preproc_" = "Y" then do;
          CompStatusN = 2;
          CompStatus = 'Clean (with preproc applied)';
        end; 

        else do;
          CompStatusN = 3;
          CompStatus = 'Clean';
        end; 
      end;

      label CompStatus = 'Compare Status' CompStatusN = 'Compare Status (N)';
      
    run;

    * Interim dataset which adds the (undecoded) issues;

    data _ResultDSN_adddetail;  
      length type $200.;
      set _compy_result;
      
      * Flag all issues which are not ignorable;
      if band(&xSYSINFO.,(2**22-1)-&IgnoreMask) then do ii = 1 to 21;

        if band( 2**(ii-1), &xSYSINFO.) and ^band(&ignoremask,2**(ii-1)) then do; 
           type='Issue';
           varn = 2**(ii-1);
           output;
        end;

      end;

      * Flag all issues which were ignorable but actually came up;
      * Note that if ignoremask is 0 then this prevents an issue being considered an issue and ignored;
      if band(&xSYSINFO.,(2**22-1)) then do ii = 1 to 21;

          if band( 2**(ii-1), &xSYSINFO.) and band(&ignoremask,2**(ii-1)) then do;
            type = 'Ignored Issue';
            varn = 2**(ii-1);
            output;
          end;

      end;

      * If nothing comes up, then all good - can just output one record;
      else if ^(band(&xSYSINFO.,(2**22-1)-&IgnoreMask)) and ^band(&xSYSINFO.,(2**22-1)) then output;

      drop ii;
    run;

    proc sort data = _ResultDSN_adddetail;
      by varn;
    run;

    data _compy_result_details;

      merge _ResultDSN_adddetail(in=repissue) _decode;
      by varn;
      if repissue;

      length issue ignored_issue $200.;
      if type = 'Issue' then Issue = varc;
      else if type = 'Ignored Issue' then Ignored_Issue = varc;

      label Issue = 'Issue' Ignored_Issue = 'Ignored Issue' varn = 'Issue Code';
      rename varn = Issue_Code;

      drop varc type;
    run;

    * If IDVARS is specified, then a dataset is created which shows all the groups not in or in PROD/QC;

    %if %nrbquote(&idvars.) ne %then %do;

     data _compy_IDVARSCHK;
      length diffcat $60.;
       merge _baseidvarchk2(rename=(cnt=cnt_comp) in=base) 
             _compidvarchk2(rename=(cnt=cnt_base) in=comp) ;
       by &idvars.;

       if base then __inBASEFN = 1;
       if comp then __inCOMPFN = 1;

       label __inBASEFN = 'Present in Base Dataset?'
             __inCOMPFN = 'Present in Comp Dataset?'
              diff      = 'Difference in counts'
             diffcat    = 'Difference in counts (categorized)'
             cnt_base   = 'Count in Base Dataset'
             cnt_comp   = 'Count in Comp Dataset';

      diff = abs(max(0,cnt_comp) - max(0,cnt_base));

      if cnt_base > cnt_comp then diffcat = "Base has more records for these set of IDVARs than Comp";
      else if cnt_comp > cnt_base then diffcat = "Comp has more records for these set of IDVARs than Base";
      else if cnt_comp = cnt_base then diffcat = "Base and Comp have same number of records";

     run;

    %end;

    %if &tidyup = Y %then %do;

        proc datasets nolist mt=data lib=work nodetails;

           delete _base _baseinfo 
                  _comp _compinfo 
                  _charcount:
                  _addinfo
                  _numcount:
                  _modatechk
                  _basemodate
                  _compmodate
                  _ResultDSN_adddetail
                  _decode

            %if %nrbquote(&idvars.) ne %then _baseidvarchk: base_presorted comp_presorted
    _basesortchk _compsortchk _basedupchk _compdupchk _compidvarchk: _sortcheck _iduniqcheck ;

            ;
        quit;

    %end;

%leave:

%MEND ___COMP;


 %** Section to run against folder / library, if _ALL_ dataset names selected **;
%if %index(%upcase(&base),_ALL_) %then %do;

        %** If processing on library - as confirmed by _ALL_ IDVARs should not be used **;
        %** This is due to expected wider variety of ID vars across a library          **;
       %if &idvars ne %str() %then %do;
          %put DEBUG: [MACRO:S_COMPARE] IDVARS should not be used when comparing full library amd have been removed.  Please remove list from macro call;
          %let idvars=;
       %end;   


        %** obtain library name only **;
       %local ___baselib ___complib;
       %let ___baselib=%upcase(%scan(&base,1,.));
       %let ___complib=%upcase(%scan(&comp,1,.));

        %** All dataset names from selected libraries obtained **;
       proc sort data=sashelp.vtable (keep=libname memname crdate) out=___libs;
         by libname memname;
         where upcase(libname) in("&___baselib","&___complib");
       run;

        %** Prepare data based on prefix selection **;
       data ___libbase (rename=(libname=baselib crdate=baseDTM))
            ___libcomp (rename=(libname=complib crdate=compDTM));
          set ___libs;
          length comp base $200;
          if libname="&___complib" then do;
                 comp="&___complib.." !! memname;
                   %** if prefix quoted - strip out to allow join of library dataset names **;
                 %if %str(&prefix) ne %str() %then memname=substr(memname,length("&prefix")+1);;  
                 output ___libcomp;
          end;
          else if libname="&___baselib" then do;
                 base="&___baselib.." !! memname;
                 output ___libbase; 
          end;
       run;

       proc sort data=___libcomp;by memname;run;
       proc sort data=___libbase;by memname;run;

        %** Look for datasets in both or one library only  **; 
        %**   If both - processed to compare               **;
        %**   if one only - then listed in report          **;        
       data ___libmissmatch ___libmatch;
          merge ___libbase (in=inbase)
                ___libcomp (in=incomp);
            length issue compstatus $200. preproc $2000.;
            by memname;
           
            preproc = ' '; ** Set new vars to null **;
            order=0;
            if inbase ne incomp then do;
               issue='Dataset only in one library';
               compstatus='Issues';
               order=-1;  ** to force missmatch library first order **;
               output ___libmissmatch;
            end;
            else output ___libmatch;
       run;

        %** Set local vars in case no datasets to compare in libraries **;
       %local dsetnum;
       %let dsetnum=0;

       data _null_;
          set ___libmatch end=eof;
          call symput("dset"!!left(put(_n_,best.)),left(memname));
          call symput("dsetnum",left(put(_n_,best.)));
       run;

        ** build initial dataset for reporting                         **;
        ** This will ensure presence even if no data to compare at all **;
        ** It will be added to later on after each compare             **;
       data ___libALLcomp;
          set ___libmissmatch;
       run;

       %** for each dataset in both libraries, run through whole compare process **;
      %do i = 1 %to &dsetnum;
      
         %let base=&___baselib..&&dset&i;
         %let comp=&___complib..&prefix.&&dset&i;

         %___COMP;

          %** Join all reporting datasets together from each cycle    **;
          %** also add in dataset containing daasets in one side only **;
            data ___libALLcomp;
               set ___libALLcomp
                _compy_result_details;
               if order=. then order=0;
            run;                                 

         proc sort data=___libALLcomp nodupkey;
            by order base basedtm comp compdtm compstatus preproc issue;
         run;

      %end;

      ods listing close;
      ODS PDF file="%str(&comprpt)";

          %local ___dat ___tim ___username;
          %let ___dat=%sysfunc(date(),yymmdd10.);
          %let ___tim=%sysfunc(time(),time5.);
          %let ___username=%sysget(username);

          title1 "Study: %str(&_studyid.)";
          title3 "Summary of Dataset Compare";
          title4 "BASE library=&___baselib";
          title5 "COMP library=&___complib";
          title6 "Executed by user: &___username on &___dat at &___tim";
           ** footnote is set above if TFL=Y selected **;

          proc print data=___libALLcomp label;
             var base basedtm comp compdtm compstatus preproc issue;
             label basedtm='Base Date/Time'
                   compdtm='Compare Date/Time'
                   issue='If no match, Why?';
          run;
          title1; footnote1;

      ODS PDF CLOSE;
      ods listing;

    %if &tidyup = Y %then %do;
        proc datasets nolist mt=data lib=work nodetails;
           delete ___lib: _compy:
           ;
        quit;
    %end;

%end;

 %** If a standard run against a named dataset (no _ALL_ in names) then run as normal **;
%else %do;
    %___comp;

          proc print data=_compy_result_details label;
             var base basedtm comp compdtm compstatus preproc issue;
             label basedtm='Base Date/Time'
                   compdtm='Compare Date/Time'
                   issue='If no match, Why?';
          run;
%end;

 %** Switch options back to value at entry **;
option &___mprint
       &___sgen
       &___mlogic
       &___notes
       &___source;

%PUT TRACE: [Macro: S_COMPARE] Completed;

%mend s_compare;
