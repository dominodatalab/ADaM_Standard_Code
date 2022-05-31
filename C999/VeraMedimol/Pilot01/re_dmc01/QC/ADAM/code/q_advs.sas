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
* Program              : q_advs.SAS
* Purpose              : 
* ____________________________________________________________________________
* DESCRIPTION                                                    
*                                                                   
* Input files: SDTM: VS,  ADAM: ADSL
*              
* Output files: Q_ADVS
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
data ADAMQCW.Q_ADVS (label = "Vital Signs Analysis Dataset");
   set ADAM.ADVS;
run;

 ** Inline interactive compare of saved dataset **;
%s_compare(base=ADAM.ADVS,
           comp=ADAMQCW.Q_ADVS);

********;
%s_scanlog;
********;
