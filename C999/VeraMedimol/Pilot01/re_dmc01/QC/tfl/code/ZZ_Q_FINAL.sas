dm 'out;clear;';
dm 'log;clear;';
 /*****************************************************************************\
*        O                                                                      
*       /                                                                       
*  O---O     _  _ _  _ _  _  _|                                                 
*       \ \/(/_| (_|| | |(/_(_|                                                 
*        O                                                                      
* ____________________________________________________________________________
* Sponsor              : Veramed
* Study                : <STUDY>
* Program              : ZZ_QC_FINAL.SAS
* Purpose              : TFL closeout program
* ____________________________________________________________________________
* DESCRIPTION                                                    
*                                                                   
* Input files: None
*              
* Output files: None
*               
* Macros: None
*         
* Assumptions: 
*
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*  <DATE>             | <NAME>          | Original version
\*****************************************************************************/

********;
%__init;
********;

** temp Setting of input parms assumed in INIT-VERASETUP-AUTOEXEC process.  TO BE UPDATED WHEN THESE ARE CONFIRMED **;
    %let studyid=ABC-123-X;
    %let progtype=TFL;
    %let outpath=%str(&__env_runtime.\qc\tfl\output);
    %let logpath=%str(&__env_runtime.\qc\tfl\saslogs);
    libname tflqc "&__env_runtime\data\tfl\qc";
   


** Full library level compare and report **;
%s_compare(base=TFL._ALL_,
           comp=TFLQC._ALL_,
           prefix=Q_,
           TFL=Y,
           comprpt =%str(&outpath\%str(&studyid)-&__re.-&PROGTYPE.-%sysfunc(date(),yymmddn.)-COMPARE.pdf));

** Full folder level log scan and report **;
%s_scanlog(logfldr=%str(&logpath),
           logrpt =%str(&logpath\%str(&studyid)-&__re.-&PROGTYPE.-%sysfunc(date(),yymmddn.)-LOGSCAN.pdf));

********;
%s_scanlog;
********;
