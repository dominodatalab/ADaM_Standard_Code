dm 'out;clear;';
dm 'log;clear;';
 /*****************************************************************************\
*        O                                                                      
*       /                                                                       
*  O---O     _  _ _  _ _  _  _|                                                 
*       \ \/(/_| (_|| | |(/_(_|                                                 
*        O                                                                      
* ____________________________________________________________________________
* Sponsor              : Veramedimol
* Study                : Pilot01
* Program              : q_adsl.SAS
* Purpose              : 
* ____________________________________________________________________________
* DESCRIPTION                                                    
*                                                                   
* Input files: SDTM: DM, EX, DS, SV, MH, QS, VS, SC
*              
* Output files: Q_ADSL
*               
* Macros: None
*         
* Assumptions: FOR DEMONSTRATION PURPOSES, THIS QC PROGRAM MERELY SETS THE PRODUCTION DATASET
*
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*  04May2022      | Dianne Weatherall          | Original version
\*****************************************************************************/

********;
%init;
********;


 *******************************;


 ** USER DEFINED DATASET CODE **;


 *******************************;

 ** FOR DEMONSTRATION PURPOSES, THIS QC PROGRAM MERELY SETS THE PRODUCTION DATASET **

 ** Save final dataset to network **;
data ADAMQCW.Q_ADSL (label = "Subject-Level Analysis Dataset");
   set ADAM.ADSL;
run;

 ** Inline interactive compare of saved dataset **;
%s_compare(base=ADAM.ADSL,
           comp=ADAMQCW.Q_ADSL);

********;
%s_scanlog;
********;
