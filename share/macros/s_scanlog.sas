 /*****************************************************************************\
*        O                                                                      
*       /                                                                       
*  O---O     _  _ _  _ _  _  _|                                                 
*       \ \/(/_| (_|| | |(/_(_|                                                 
*        O                                                                      
* ____________________________________________________________________________
* Sponsor              : Veramed
* Study                : <STUDY>
* Program              : s_scanlog.sas
* Purpose              : Scans SAS logs (interactive SAS:DMS only or stored) and reports summary of messages 
* ____________________________________________________________________________
* DESCRIPTION           Macro to scan logs and return count of issues to the user
*                       When running in interactive mode (no parameters completed) within a program
*                          will return information to users active streamed SAS LOG screen 
*                          This works both SAS DMS and EG.
*                       When running with both a LOGFLDR and LOGRPT parameter completed, will scan all logs
*                          in a folder and deliver a PDF of the results
*
*  Input Macro Parameters
*    LOGFLDR = Full path of the folder storing the .LOG files to be scanned
*    LOGRPT  = Filename of generated PDF when reporting the scanned folder.  
*              File stored in folder quoted in &LOGFLDR
*    DEBUG   = Y or N.  
*              N = supresses SAS log of execution of this macro so no risk of double counting strings.  Work datasets deleted
*              Y = Options MPRINT NOTES SGEN MLOGIC SOURCE forced on for execution if debugging required.  Work datasets retained
*                  Users entry options will be re-applied at end of macro 
*

* Example macro calls
*
*    %s_scanlog;
*           Simple call.  No parameters when running in interactive mode.  Results fed back to users active SAS Log window
*
*    %s_scanlog(logfldr=&__logpath,
*               logrpt =&__logpath.\<FILENAME>.pdf);
*               scans all SAS log messages in a folder and returns the results to a select file, store in the same folder as scanned logs 
*
*
* Input files: Interactive SAS log window, or ALL .LOG files in a selected folder
*
*              
* Output files: PDF summary saved to same location as .LOG files
*               
* Macros: none
*         
* Assumptions: 
** Global variables required for processing from %INIT macro.  If not present a defaul will be set to enable stand alone execution
*   __DELIM = for use in path resolution
*   __RUNMODE to be present to present execution status
*   _STUDYID = to put current study name on output
*
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*  12March2022             | Mark Holland          | Original version
*  31March2022             | Mark holland          | update for EG execution
*  09May2022               | Mark Holland          | Bug fix as on occasion in DMS mode
*                                                    macro would save LST window and scan as opposed to LOG window
\*****************************************************************************/


%macro s_scanlog (logfldr=,
                  logrpt =,
                  debug  =N);

  %PUT TRACE: [Macro: s_scanlog] Starting;

   %* Pre input parameters **;
  %let debug=%upcase(&debug);

   %**Obtain options changed by DEBUG to enable reset **;
  %local ___mprint ___notes ___sgen ___mlogic ___source;
  %let ___mprint=%sysfunc(getoption(mprint));
  %let ___notes =%sysfunc(getoption(notes));
  %let ___sgen  =%sysfunc(getoption(sgen));
  %let ___mlogic=%sysfunc(getoption(mlogic));
  %let ___source=%sysfunc(getoption(source));


   %** Set options based on the DEBUG value ;
  %if &debug=N %then %do;
      options nomprint nonotes nosgen nomlogic nosource;
      %PUT TRACE: [Macro: s_scanlog] DEBUG=N. SAS log supressed to prevent double counting;
  %end;
  %else %if &debug=Y %then %do;
        options mprint  notes    sgen   mlogic   source;
        %PUT TRACE: [Macro: s_scanlog] DEBUG=Y. SAS log fully visible to review.  Users options are reset at end of call;
  %end;

   %** check for required global variables.  If not present then create a default to allow stand along execution **;
  %if %symexist(__delim) = 0 %then %do;
      %let __delim=\;
      %PUT TRACE: [Macro: s_scanlog] __DELIM did not exist.  set to \ to allow execution;
  %end;
  %if %symexist(__runmode) = 0 %then %do;
      %let __runmode=INTERACTIVE;
      %PUT TRACE: [Macro: s_scanlog] __RUNMODE did not exist.  set to INTERACTIVE to allow execution;
  %end;
  %if %symexist(_studyid) = 0 %then %do;
      %let _studyid=<TBC>;
      %PUT TRACE: [Macro: s_scanlog] _STUDYID did not exist.  set to <TBC> to allow execution;
  %end;



   %** Idenfity the SAS execution mode and paramters completed in macro  call to control exactly what runs **;
   %** If SAS batch.
   %**    If no macro parameters selected then the run is for interactive use only  Do not run
   %**    If logfldr complete - macro will run against all files in selecged folder 
   %**
   %** If interactive SAS.
   %**    if no macro parameters selected then macro will check interacive SAS log only 
   %**    If logfldr complete - macro will run against all files in selecged folder **;
  %local ___workpath ___userprofile ;
  %let ___workpath=%sysfunc(pathname(work));
  %let ___userprofile=%sysget(userprofile);

   %** Condition below prevent instream execution running, if SAS programs are run as a whole batch execution **;
   %** as part of a delivery.  IN this case it is expected a folder level scan of a suite of log files will  **;
   %** be called - and as such a PDF summary of all logs will be presented                                   **;
  %if not(&__runmode=BATCH and %quote(&logfldr) = %str()) %then %do;

            %** for interactive mode - need to build location of log files and copy to SASWORK for processing **;
            %**  as driven by whether running in EG or SAS DMS                                                **;
          %if &__runmode ne BATCH and %quote(&logfldr) = %str() %then %do;

               %PUT TRACE: [Macro: s_scanlog] Runnning against streamed interactive SAS Log.;

                %** SAS EG log file  **;    
               %if %symexist(_SASPROGRAMFILE) %then %do;

                      %** SAS EG stores log files in various location in path below                                  **;
                      %** copy all possible log files over to SASWORK folder  to be able to determine newest         **;
                      %** This is not using the DLIM paramters as this is the windows installation only hence \ only **;
                     filename s_eglog pipe "dir &___userprofile.\appdata\roaming\SAS\enterpriseguide\egtemp\*.log /s /b"; 

                     data _null_;
                         infile s_eglog;
                         input;
                         var = _infile_;
                         newfile=trim("&___workpath.") !! '\results' !! trim(left(put(_n_,best.))) !! '.zzz';
                         *Copy each log file to saswork folder as name.zzz ;
                         call execute(cats('%sysexec(copy "',VAR,'" "',newfile,'")'));
                     run;
                      %** Now all in one folder, can assess the most recent log file and reset this to log.log for scanning  **;
                     filename s_eglog2 pipe "dir ""&___workpath.\*.zzz"" /b /s /o:d"; 
                     %local ___zzz;
                     data _null_;
                         infile s_eglog2;
                         input;
                         var = _infile_;
                         call symput('___zzz',trim(var)); ** dir order will mean newest is last **;
                     run;

                      %** newest file only will be read in/out to log.log for scanning later **;
                     data _null_;
                        infile "&___zzz" truncover;  ** both files in **;
                        length var $ 300;
                        input var $1-300;
                        file "&___workpath.&__delim.log.log" ;  ** one file out **;
                        put var;
                     run;       
                      %** force folder for logs to be WORK folder **;
                     %let logfldr=&___workpath;

               %end;
                %** Run in DM mode **;
               %else %do;
                   %** Save log from interactive window into SASWORK folder **;
                  dm "log;";
                  dm "log; file '&___workpath.&__delim.log.log' replace;";
                   %** force folder for logs to be WORK folder **;
                  %let logfldr=&___workpath;
               %end;
          %end;
          %else %do;
               %PUT TRACE: [Macro: s_scanlog] Runnning against folder &logfldr;
          %end;

           %** Get the total number of files and file names from the seleted folder for log scanning **;
          filename _logs pipe "dir ""&logfldr.&__delim.*.log"" /b";
          data ___logs;
             infile _logs;
             input;
             name=_infile_;
             if index(upcase(name),'FINAL.LOG') then delete;  %** Drop scan of FINAL programs - as these are inflight and cannot be scanned when in batch mode **;
          run;

          %local ___totlogs;
          %let ___totlogs=0;
          data _null_;
             set ___logs;
             call symput('___totlogs',trim(left(put(_n_,8.))));
             call symput('file'||trim(left(put(_n_,8.))),trim(left(name)));
          run;

          %do i=1 %to &___totlogs;
             data ___logfiles;
               infile "&logfldr.&__delim.&&file&i" dsd dlm='09'x truncover;
               input line $200.;
               line=upcase(line);
               length filenm $40.;
               filenm="&&file&i";
                 if index(line,'fatal') then cnt1+1;
                 else if substr(line,1,5)='ERROR'     then cnt2+1;
                 else if substr(line,3,5)='ERROR'     then cnt2+1;   ** second option is for EG;
                 else if substr(line,1,7)='WARNING'   then cnt3+1;
                 else if substr(line,3,7)='WARNING'   then cnt3+1;   ** second option is for EG;
                 else if index(line,'UNINITIALIZED') then cnt4+1;
                 else if index(line,'MERGE STATEMENT HAS MORE THAN') then cnt5+1;
                 else if index(line,'VALUES HAVE BEEN CONVERTED') then cnt6+1;
                 else if index(line,'NOTE: MISSING') then cnt7+1;
                 else if index(line,'NOTE: INVALID ARGUMENT') then cnt8+1;
                 else if index(line,'W.D FORMAT WAS TOO SMALL') then cnt9+1;
                 else if index(line,'HAS 0 OBSERVATIONS') then cnt10+1;
                 else if index(line,'VARIABLES NOT IN') then cnt11+1;
                 else if index(line,'VARIABLES HAVE CONFLICTING') then cnt12+1;
                 else if index(line,'UNEQUAL') then cnt13+1;
                 else if index(line,'DIVISION BY ZERO DETECTED') then cnt14+1;
                 else if index(line,'OPERATIONS COULD NOT BE PERFORMED') then cnt15+1;
                 else if index(line,'DUPLICATE KEY VALUES WERE DELETED') then cnt16+1;
                 else if index(line,'OUTSIDE THE AXIS RANGE') then cnt17+1;
                 else if index(line,'HAS BEEN TRUNCATED') then cnt18+1;
                 else if index(line,'WAS NOT FOUND OR COULD NOT BE LOADED') then cnt19+1;
                 else if (substr(upcase(line),1,8) ='DEBUG: [') or (substr(upcase(line),1,7) ='DEBUG:[') then cnt20+1;
                 else cnt0+1; ** count for zero messages found **;
             run;

              %** Update value below based on max cntXX variable value **;
             %let ___max=20;

              %** Count the nubm er of issues per message **;
             proc univariate data=___logfiles noprint;
                by filenm;
                var cnt0-cnt&___max.;
                output out=___logstat1 max=max0-max&___max.;
             run;

              %** If sum of all max cols is zero - it means no issues.  In this case reset max0 to ne 0.5 for later processing **;
              %** thus allowing a CLEAN message to be presented **;
              data ___logstat1;
                set ___logstat1;
                if sum(of max0-max&___max.)=max0 then max0=0.5;
                else max0=0;
             run;

             proc transpose data=___logstat1 out=___logstat2(where=(col1>0));
                by filenm;
                var max0-max&___max.;
             run;

             data ___logstat2;
                set ___Logstat2;
                order=input(substr(_name_,4),best.); ** set a var to be the number of the MAX label.  This allows some re-ordering if needed **;
             run;

             proc sort data=___logstat2;
                by order;
             run;

             data ___logfinal;
               set %if &i>1 %then %do; ___logfinal %end; ___logstat2;
                 %if &i=&___totlogs %then %do;
                    length desc $100.;
                     if lowcase(_name_)='max1' then desc='fatal';
                     if lowcase(_name_)='max2' then desc='ERROR';
                     if lowcase(_name_)='max3' then desc='WARNING';
                     if lowcase(_name_)='max4' then desc='uninitialized';
                     if lowcase(_name_)='max5' then desc='Merge statement has more than one data set with repeats of BY values';
                     if lowcase(_name_)='max6' then desc='Num or char values have been converted in uncontrolled manner';
                     if lowcase(_name_)='max7' then desc='Note: Missing';
                     if lowcase(_name_)='max8' then desc='Note: Invalid argument';
                     if lowcase(_name_)='max9' then desc='W.D format was too small';
                     if lowcase(_name_)='max10' then desc='has 0 observations';
                     if lowcase(_name_)='max11' then desc='variables not in';
                     if lowcase(_name_)='max12' then desc='variables have conflicting attributes';
                     if lowcase(_name_)='max13' then desc='unequal';
                     if lowcase(_name_)='max14' then desc='Division by zero detected';
                     if lowcase(_name_)='max15' then desc='Mathematical operation could not be performed';
                     if lowcase(_name_)='max16' then desc='observations with duplicate key values were deleted';
                     if lowcase(_name_)='max17' then desc='outside the axis range';
                     if lowcase(_name_)='max18' then desc='has been truncated';
                     if lowcase(_name_)='max19' then desc='a format was not found or could not be loaded';
                     if lowcase(_name_)='max20' then desc='USER or MACRO DEFINED Debug messages for further assessment';

                     if lowcase(_name_)='max0'  then desc='No messages of concern';
                     drop _name_ _label_;
                 %end;
             run;

          %end;
           %** If no files scanned - push message to PDF and log **;
          %if &___totlogs=0 %then %do;
              data ___logfinal;
                 filenm = 'MISSING';
                 desc2  = 'FOLDER HAS NO LOG FILES PRESENT.  PLEASE CHECK CONTENT OF FOLDER SELECTED FOR SCANNING';
              run;
              %put DEBUG: [Macro: s_scanlog] Folder does not contain any .LOG files.  Please check;;

          %end;
          %else %do;
               %** Get the total number of occurrences of unwanted messages **;
              data ___logfinal;
                 set ___logfinal;
                  %** Create single var string for key information to report **;
                 length desc2 $100.;
                 if col1 ge 1 then desc2 = trim(left(put(col1,8.))) !! '  x  ' !! desc;
                 else desc2 = desc;
              run;
          %end;

          %** If folder level run - create PDF **;
         %if %quote(&logrpt) ne %str() %then %do;
   
             %let ___dat=%sysfunc(date(),yymmdd10.);
             %let ___tim=%sysfunc(time(),time5.);
             %let ___username=%sysget(username);

             ods listing close;
             ods pdf file="&logrpt";

              title1 "Study: %str(&_studyid.)";
              title3 "Summary of Log Files";
              title4 "FOLDER: &logfldr";
              title5 "Executed by user: &___username on &___dat at &___tim";

                 proc report data=___logfinal headline headskip split='|' missing nowd;
                     columns filenm desc2;
                      define filenm / order order=data style(column)=[cellwidth=1.5in] style(header)=[just=left] 'File';
                      define desc2 / style(column)=[cellwidth=5in] style(header)=[just=left] 'Description';
                      compute before filenm;
                           line ' ';
                       endcomp;
                 run;

             ods pdf close;
             ods listing;
             title1;

         %end;

          %** If instream SAS - sent to SAS Log window **;
         %else %do;
            options notes;  ** notes option forced on here to present note to log **;
            data _null_;
               set ___logfinal end=eof;
                %** Setup - starter **;
               if _n_=1 then do ;
                  put 'NOTE:  ';
                  put 'NOTE:  ';
                  put 'NOTE:   ************************************************';
                  put 'NOTE:   ** SUMMARY OF LOG EXECUTION ********************';
                  put 'NOTE:   ************************************************';
                  put 'NOTE:   ** ';
               end;
                %** tweak output based on content **;
               if col1=0.5 then do;
                  put 'NOTE:   **   NO MESSAGES OF IMMEDIATE CONCERN';
                  put 'NOTE:   **   ENSURE LOG IS STILL THOROUGHLY REVIEWED';
               end;
               else if index(upcase(desc),'ERROR') then
                  put 'ERROR:  **   '     col1  '  x  '    desc;
               else if index(upcase(desc),'WARNING') then
                  put 'WARNING:**   '     col1  '  x  '    desc;
               else
                  put 'NOTE:   **   '     col1  '  x  '    desc;
                %** Close out the counter section **;
               if eof then do;
                  put 'NOTE:   ** ';
                  put 'NOTE:   ************************************************';
                  put 'NOTE:   ** END *****************************************';
                  put 'NOTE:   ************************************************';
                  put "NOTE:";
                  put "NOTE:"; 
               end;
            run;
            options nonotes;  ** switch notes off again **;

         %end;
  %end;

   %** If an instream call - but batch execution - do not run **;
  %else %do;
       %put TRACE: [Macro: s_scanlog] INLINE MACRO CALL NOT EXECUTED BY DESIGN IN SAS BATCH MODE;
  %end;

  %endscan:

    %* clearing all created datasets if debug not selected **;
   %if &debug=N %then %do;
        proc datasets nolist mt=data lib=work nodetails;
           delete ___log:
           ;
        quit;
    %end;

     %** Switch options back to value at entry **;
    option &___mprint
           &___sgen
           &___mlogic
           &___notes
           &___source;

%PUT TRACE: [Macro: s_scanlog] Complete;

%mend s_scanlog;
