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
* Program              : FORMATS.SAS
* Purpose              : To store study specific SAS formats for use on PRODUCTION programming only
*                        These are formats that are expected to be available across multiple programs
*                        but only within the current program type (e.g. SDTM / ADaM or TFL)
* ____________________________________________________________________________
* DESCRIPTION                                                    
*                                                                   
* Input files: None
*              
* Output files: None
*          formats catalog and dataset (for easy viewing) to folder ...\refdata
* Macros: None
*         
* Assumptions: 
*          OPTIONS FMTSEARCH already setup by the %INIT process
*
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*  <DATE>             | <NAME>          | Original version
\*****************************************************************************/

*********;
%init;
*********;

 ** Always ensure clean build of fresh catalog to ensure no old formats stick around **;
proc datasets lib=refdataw memtype=cat noprint;
   delete &__progcat2.&__progtype._fmt;
quit;


 ** all user defined formats defined here **;
proc format lib=refdataw.&__progcat2.&__progtype._fmt cntlout=refdataw.&__progcat2.&__progtype._fmt;

   value dummy
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
