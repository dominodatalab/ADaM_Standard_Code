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
* Study                : VeraMedimol-Pilot01
* Program              : final.sas
* Purpose              : Run QA checks as final step of batch run
* ____________________________________________________________________________
* DESCRIPTION
* - Scan the SAS logs and generate a PDF report for QA
*
* Input files: 
* - None
*              
* Output files: 
* - output\<STUDY>-<REPORTING_EFFORT>-<PROD|QC>-LOGSCAN.PDF
*
* Macros:
* - init
* - logscan
*         
* Assumptions: 
* - relies on init macro global vars
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*  <DATE>             | <NAME>          | Original version
\*****************************************************************************/

*********;
%init;
*********;

* define a STUDYID which is <COMPOUND>-<STUDY> using global vars (defined in init);
%let studyid=%qupcase(&__compound)-%upcase(&__study);
* define the path that we are running in.. this is the parent of the code dir that   ;
* this program is in. (The ENV RUNTIME is the reporting effort dir)                  ;
%let runpath=%str(&__env_runtime.&__DELIM.&__progcat.&__DELIM.&__progtype.&__DELIM);
* define the report name. this is the PDF that the scanlog generates ;
%let reportname=%str(&studyid)-&__re.-&__PROGCAT.-&__PROGTYPE.-LOGSCAN.pdf;

%s_scanlog(logfldr=%str(&runpath.saslogs)                       /* saslogs folder to scan */
            ,logrpt =%str(&runpath.output&__DELIM.&reportname)   /* output report path+name */
            ,debug=n                                             /* Debug switch */
);

********;
%s_scanlog;
********;
