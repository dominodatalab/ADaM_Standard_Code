dm 'out;clear;';
dm 'log;clear;';
 /*****************************************************************************\
*        O                                                                      
*       /                                                                       
*  O---O     _  _ _  _ _  _  _|                                                 
*       \ \/(/_| (_|| | |(/_(_|                                                 
*        O                                                                      
* ____________________________________________________________________________
* Sponsor              : {{CLIENT}}
* Study                : {{STUDY}}
* Program              : q_final.sas
* Purpose              : Final program to be executed as part of batch process
*                        Runs full library level PROC COMPARE and LOG SCANS to
*                        generate PDF summary reports 
* ____________________________________________________________________________
* DESCRIPTION          
*                                                                   
* Input files:  All datasets from ADAM and ADAMQCW libraries
*               All SAS Logs from folder ..\QC\ADAM\SASLOG
*              
* Output files: PDF summary report from all dataset compares
*               PDF summary report of SAS log scans
*
* Macros:       S_COMPARE and S_SCANLOG
*         
* Assumptions:  All programs fully executed in batch mode in advance and only datasets
*               and SAS Logs / Dataset needed for delivery are present in folders
*               All QC datasets have Q_ prefix
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*  <DATE>             | <NAME>          | Original version
\*****************************************************************************/

********;
%init;
********;


 ** Full library level compare and report **;
%s_compare(base=ADAM._ALL_,
           comp=ADAMQCW._ALL_,
           comprpt =%str(&__outpath\%str(&_studyid)_11.03.02_%sysfunc(date(),yymmddn.)_&_relabel.-&__PROGTYPE.-Compare-Summary.pdf));


 ** Full folder level log scan and report **;
%s_scanlog(logfldr=%str(&__logpath),
           logrpt =%str(&__logpath\%str(&_studyid)_11.03.02_%sysfunc(date(),yymmddn.)_&_relabel.-&__PROGTYPE.-QC-SASLog-Summary.pdf));


********;
%s_scanlog;
********;
