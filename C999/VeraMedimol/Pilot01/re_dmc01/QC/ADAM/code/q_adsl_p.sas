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
* Program              : q_adsl_p.SAS
* Purpose              : 
* ____________________________________________________________________________
* DESCRIPTION                                                    
*                                                                   
* Input files: ADAMQCW: ADSL
*              
* Output files: N/A
*               
* Macros: None
*         
* Assumptions: FOR DEMONSTRATION PURPOSES, THIS QC PROGRAM MERELY SETS THE ORIGINAL PILOT STUDY ADAM DATASET
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
 ** N/A;

 ** Inline interactive compare of saved dataset **;
%s_compare(base=ADAM.ADSL,
           comp=ADAMQCW.ADSL);

********;
%s_scanlog;
********;
