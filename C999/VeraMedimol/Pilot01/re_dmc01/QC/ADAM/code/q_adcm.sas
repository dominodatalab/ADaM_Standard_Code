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
* Program              : q_adcm.SAS
* Purpose              : 
* ____________________________________________________________________________
* DESCRIPTION                                                    
*                                                                   
* Input files: SDTM: CM,  ADAM: ADSL
*              
* Output files: Q_ADCM
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
data ADAMQCW.Q_ADCM (label = "Concomitant Medications Analysis Dataset");
   set ADAM.ADCM;
run;

 ** Inline interactive compare of saved dataset **;
%s_compare(base=ADAM.ADCM,
           comp=ADAMQCW.Q_ADCM);

********;
%s_scanlog;
********;
