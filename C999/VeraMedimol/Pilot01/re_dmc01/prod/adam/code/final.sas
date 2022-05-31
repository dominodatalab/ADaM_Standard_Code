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
* Program              : final.sas
* Purpose              : ADaM Final program to be executed as part of batch process
*                        Runs full library level LOG SCAN to generate PDF summary report 
*                        and any other library level processing as neccessary 
* ____________________________________________________________________________
* DESCRIPTION          
*                                                                   
* Input files:  All SAS Logs from folder ..\PROD\ADAM\SASLOG
*              
* Output files: PDF summary report of SAS log scans
*
* Macros:       S_SCANLOG
*         
* Assumptions:  All programs fully executed in batch mode 
*               All SAS Logs needed for delivery are present in folder
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*  <DATE>             | <NAME>          | Original version
\*****************************************************************************/

*********;
%init;
*********;



*********************;

** Library level processing.  e.g. - SAS to XPT **;

*********************;


 ** Full library level compare and report **;
%s_scanlog(logfldr=%str(&__logpath),debug=n,
           logrpt =%str(&__logpath\%str(&_studyid)_11.03.02_%sysfunc(date(),yymmddn.)_&_relabel.-&__PROGTYPE.-SASLog-Summary.pdf));

********;
%s_scanlog;
********;
