/*****************************************************************************\
*        O                                                                      
*       /                                                                       
*  O---O     _  _ _  _ _  _  _|                                                 
*       \ \/(/_| (_|| | |(/_(_|                                                 
*        O                                                                      
* ____________________________________________________________________________
* Sponsor              : Veramed
* Study                : ALL
* Program              : init.sas
* Purpose              : Identifies location of current program and runs the
*                        reporting effort level autoexec if one exists.
*                        
* ____________________________________________________________________________
* DESCRIPTION
* 
* This macro starts the Veramed standard initialization. This file should
* be called by every driver program run on the Veramed VIP platform.
* This macro does the following:
* 1) identify where in the standard directory structure the program is,
* 2) identify which environment the program is running in (Development or Production)
* 3) call the standard Veramed setup program re_reporting_effort\config\verasetup.sas 
*
* This macro defines the following global SAS macros:
*
* PROGRAM GLOBAL VARIABLES
*
* &__progcat      Category of program: PROD, QC, SHARE
* &__progtype     Type of program: SDTM, ADAM, TFL
* &__progname     Name of program file (including the .sas extension)
*
* PATHNAME GLOBAL VARIABLES
*
* &__full_path    Full path of the program that called init (incl prog+ext)
* &__env_runtime  Path to the reporting effort the program is running in
*
* ENVIRONMENT GLOBAL VARIABLES
*
* &__runmode      SAS is running INTERACTIVE or BATCH
* &__exemode      How was SAS executed? DMS, EG, SAS_BATCH, VIPER_BATCH
* &__env_mode     Which workspace is program running in (DEV, CLIENT, UNKNOWN)
* &__DELIM        path delimeter for windows/unix compatability ;
*
* STUDY NAME VARIABLES
*
* &__client     (from full path) client code e.g. C006 ;
* &__compound   (from full path) compound name e.g. VeraMedimol;
* &__study      (from full path) study name e.g. Pilot-1 ;
* &__re         (from full path) name of reporting effort e.g. re_dmc01 ;
*
* Input files: None
*              
* Output files: None
*
* Macros used: None
*         
* Assumptions: 
* - Code is running in \[prod-qc-share]\[adam-sdtm-tfl-tests]\code
* - study names are parsed from full pathname assuming standard dir structure
* - Path delimeter is set to Windows forward-slash. Change manually for Unix.
* - assumes running on Accel server in the Z: drive
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*  11MAR2022 | Hector Leitch   | Original version - currently only creates
*            |                 | minimum required variables to execute the
*            |                 | autoexec if it exists
* ----------------------------------------------------------------------------
*  11mar2022 | Stuart Malcolm  | rename and relocate autoexec to verasetup
*            |                 | changed __auto_path to __env_runtime
*            |                 | added delimeter for x-platform compatability
*            |                 | added comments 
*            |                 | removed call to init. should be in driver prog
*            |                 | removed ods settings
*            |                 | changed test dataset to _null_
*            |                 | added global vars for re/study/client names
* ----------------------------------------------------------------------------
*  15MAR2022 | Hector Leitch   | Tidy up comments and alginment style
* ----------------------------------------------------------------------------
*  16mar2022 | Stuart Malcolm  | #15 detect if running in VIPER batch mode
* ----------------------------------------------------------------------------
*  26mar2022 | Stuart Malcolm  | #26 additional vars (prog cat/type/name/etc)
* ----------------------------------------------------------------------------
*  01jun2022 | Stuart Malcolm  | change DELIM to Unix and fix hardcoded \
\*****************************************************************************/

%macro init;

   /* See header comment for description of global vars */
   %global __runmode;
   %global __exemode;
   %global __full_path; 
   %global __env_mode;
   %global __auto_path;
   %global __env_runtime;
   %global __DELIM;     
   %global __re;        
   %global __study;     
   %global __compound;  
   %global __client;
   %global __progcat;
   %global __progtype;
   %global __progname;

   /* Local vars are not available ouside this macro */
   %local verasetup;

   /* Define path delimeter \ for Windows / for unix */
   %let __DELIM = %str(/);

   /* Check for macro var _SASPROGRAMFILE. This parameter is only present in EG */
   %if %symexist(_SASPROGRAMFILE) %then %do;
      %let __full_path = %str(&_SASPROGRAMFILE.);
      %let __runmode=INTERACTIVE;
      %let __exemode=EG;
      %put %str(TR)ACE: [Program: init.sas] Running in SAS EG.;
   %end;

   %* Check for Operating System parameter SYSIN. This parameter indicates batch execution ;
   %else %if %quote(%sysfunc(getoption(sysin))) ne %str() %then %do;
      %let __full_path = %quote(%sysfunc(getoption(sysin)));
      %let __runmode=BATCH;
      %let __exemode=SAS_BATCH;
      %put %str(TR)ACE: [Program: init.sas] Running in BATCH SAS.;
   %end;
  
   %* [16mar2022_SM] ;
   %* Otherwise check environment variables to see if we can determine how SAS invoked ;
   %* All the env vars are read into a dataset and filtered out. This is done to avoid ;
   %* having to use %sysget on a var that might not exist resulting in a log WARNINIG  ;
   %else %do;
     * run SET command to get all environment variables.. ;
     * and filter out ones that indicate how SAS invoked. ;
     * Only tested on Windows but should work on Linux    ;
     filename envcmd pipe 'set' lrecl=1024;
     data work.__envars;
       infile envcmd dlm='=' missover;
       length name $ 32 value $ 1024;
       input name $ value $;
     run;
     * look for anv vars that indicate how SAS invoked..;
	 * ..there should only be one of these defined ;
     data __search;
       set __envars;
       if compare(trim(name),"SAS_EXECFILEPATH",'i') eq 0 then do;
         put 'TRACE: [Macro: init] Running in SAS DMS.';
         call symput("__full_path", strip(value));
         call symput("__runmode", 'INTERACTIVE');
         call symput("__exemode", 'DMS');
       end;*if;
       if compare(trim(name),"VIPER_EXECFILEPATH",'i') eq 0 then do;
         put 'TRACE: [Macro: init] Running in SAS VIPER batch';
         call symput("__full_path", strip(value));
         call symput("__runmode", 'BATCH');
         call symput("__exemode", 'VIPER_BATCH');
       end;*if;
     run;
	 * clean-up ;
	 proc datasets library=work nolist;
	   delete __envars __search;
	 quit;
   %end;

   %* Error if FULLPATH not obtained ;
   %if %quote(&__full_path.) = %str() %then %do;
      %put %str(DE)BUG: [Program: init.sas] Cannot determine SAS execution mode.;
      %let __runmode=%str();
      %let __exemode=%str();
      %goto exit;
   %end;

   /* From full path of current program idenitifed above, split out to create limited */
   /* global macros variables for future processing */
   data _null_;
      length envmode $7;

*      fullpath = upcase(translate("&__full_path.", "", "'"));
      fullpath = translate("&__full_path.", "", "'");
      /* Set envmode based on current file path */
      * if the username is in the filepath then assume in DEV mode ;
      if find(fullpath, "&__DELIM.&sysuserid.&__DELIM", "i") ge 1 then envmode = "DEV";
      else if substr(fullpath, 1, 3) eq "Z:&__DELIM." then envmode = "CLIENT";
      else                                                 envmode = "UNKNOWN";

      /* Derive autoexec location assuming program is within code-level folder in */
      /* standard structure */
      progname = scan(fullpath, -1, "&__DELIM."); /* program name */
      progtype = scan(fullpath, -3, "&__DELIM."); /* SDTM, ADAM, TFL */
      prodqc   = scan(fullpath, -4, "&__DELIM."); /* PROD, QC, SHARE */
      re       = scan(fullpath, -5, "&__DELIM."); /* Reporting effort e.g. re_dmc01 */
      study    = scan(fullpath, -6, "&__DELIM."); /* Study name */
      compound = scan(fullpath, -7, "&__DELIM."); /* Compound name */
      client   = scan(fullpath, -8, "&__DELIM."); /* Client name */
  
	   /* repath is e.g. z:\client\compund\study\re_name */
      /* All paths in reporting effort are relative to this */
      path2    = "&__DELIM." || strip(prodqc) || "&__DELIM." || strip(progtype);
      repath = substr(fullpath, 1, index(fullpath, strip(path2))-1);

	   /* Define the global variables */
	   /* PATHS */
      call symput("__full_path", strip(fullpath));
      call symput("__env_mode",  strip(envmode));
      call symput("__env_runtime", strip(repath)); 
      /* NAMES (extracted from __full_path) */
      call symput("__re",  strip(re));     
      call symput("__study",    strip(study));   
      call symput("__compound", strip(compound));   
      call symput("__client",   strip(client));   
	  /* PROGRAM */
      call symput("__progcat",   strip(prodqc));   
      call symput("__progtype",   strip(progtype));   
      call symput("__progname",   strip(progname));   
   run;

   %* Write the global variables to the log for traceability ;
   %put %str(TR)ACE: [Program: init.sas] __FULL_PATH: %str(&__full_path.);
   %put %str(TR)ACE: [Program: init.sas] __ENV_MODE:  %str(&__env_mode.);
   %put %str(TR)ACE: [Program: init.sas] __ENV_RUNTIME: %str(&__env_runtime.);
   %put %str(TR)ACE: [Program: init.sas] __RE: %str(&__re);
   %put %str(TR)ACE: [Program: init.sas] __STUDY: %str(&__study);
   %put %str(TR)ACE: [Program: init.sas] __COMPOUND: %str(&__compound);
   %put %str(TR)ACE: [Program: init.sas] __CLIENT: %str(&__client);
   %put %str(TR)ACE: [Program: init.sas] __RUNMODE: %str(&__runmode);
   %put %str(TR)ACE: [Program: init.sas] __EXEMODE: %str(&__exemode);
   %put %str(TR)ACE: [Program: init.sas] __progcat: %str(&__progcat);
   %put %str(TR)ACE: [Program: init.sas] __progtype: %str(&__progtype);
   %put %str(TR)ACE: [Program: init.sas] __progname: %str(&__progname);

   %* Execute Verasetup if it can be located ;
   %* Verasetup is the Veramed standard setup program ;
   %* This does most of the initialisation heavy-lifting ;
   %* e.g. defines libnames, etc. ;
   %let verasetup = &__env_runtime.&__DELIM.config&__DELIM.verasetup.sas;

   %if %sysfunc(fileexist(%quote(&verasetup.))) %then %inc "&verasetup.";
   %else %put %str(DE)BUG: [Program: init.sas] Verasetup file does not exist. [verasetup: &verasetup].;;

   %* Line 113: if __full_path is not obtained ;
   %exit:

%mend init;



