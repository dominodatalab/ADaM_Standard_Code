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
* Program              : q_formats.sas
* Purpose              : To store study specific ADaM SAS formats for use on QC programming only
*                        These are formats that are expected to be available across multiple programs
* ____________________________________________________________________________
* DESCRIPTION                                                    
*                                                                   
* Input files:  None
*              
* Output files: Formats catalog and dataset (for easy viewing) to folder ...\refdata
*
* Macros:       None
*         
* Assumptions:  OPTIONS FMTSEARCH already setup by the %INIT process
*
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*  <DATE>             | <NAME>          | Original version
\*****************************************************************************/

*********;
%init;
*********;


 ** Always ensure clean build of fresh catalog to ensure no old formats remain **;
proc datasets lib=refdataw memtype=cat noprint;
   delete &__progcat2.&__progtype._fmt;
quit;


 ** all user defined formats defined here **;
proc format lib=refdataw.&__progcat2.&__progtype._fmt cntlout=refdataw.&__progcat2.&__progtype._fmt;

   value q_dummy
        1 = 'one'
        2 = 'two'
        ;  ** DELETE ME FROM ACTIVE FILE WHEN IN STUDY **;

run;


*****************************************************************************;
** Place holder:                                                           **;
** future process to add CDISC CT formats From specification into same CAT **;
*****************************************************************************;


********;
%s_scanlog;
********;
