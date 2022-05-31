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
* Program              : q_adtte.SAS
* Purpose              : 
* ____________________________________________________________________________
* DESCRIPTION                                                    
*                                                                   
* Input files: ADAM: ADAE, ADSL
*              
* Output files: Q_ADTTE
*               
* Macros: None
*         
* Assumptions: FOR DEMONSTRATION PURPOSES, THIS QC PROGRAM MERELY SETS THE PRODUCTION DATASET
*
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*  05May2022      | Dianne Weatherall          | Original version
\*****************************************************************************/

********;
%init;
********;


 *******************************;


 ** USER DEFINED DATASET CODE **;


 *******************************;

 ** FOR DEMONSTRATION PURPOSES, THIS QC PROGRAM MERELY SETS THE PRODUCTION DATASET **

 ** Save final dataset to network **;
data ADAMQCW.Q_ADTTE (label = "Time to Event Analysis Dataset");
   set ADAM.ADTTE;
run;

 ** Inline interactive compare of saved dataset **;
%s_compare(base=ADAM.ADTTE,
           comp=ADAMQCW.Q_ADTTE);

********;
%s_scanlog;
********;
