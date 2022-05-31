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
* Program              : q_adae.SAS
* Purpose              : 
* ____________________________________________________________________________
* DESCRIPTION                                                    
*                                                                   
* Input files: SDTM: AE,  ADAM: ADSL
*              
* Output files: Q_ADAE
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
data ADAMQCW.Q_ADAE (label = "Adverse Event Analysis Dataset");
   set ADAM.ADAE;
run;

 ** Inline interactive compare of saved dataset **;
%s_compare(base=ADAM.ADAE,
           comp=ADAMQCW.Q_ADAE);

********;
%s_scanlog;
********;
