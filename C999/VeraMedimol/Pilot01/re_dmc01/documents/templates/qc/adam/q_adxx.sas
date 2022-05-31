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
* Program              : q_adxx.SAS
* Purpose              : 
* ____________________________________________________________________________
* DESCRIPTION                                                    
*                                                                   
* Input files: XXXX
*              
* Output files: ADAMQC.Q_ADxx
*               
* Macros: None
*         
* Assumptions: 
*
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*  <DATE>             | <NAME>          | Original version
\*****************************************************************************/

********;
%init;
********;


 *******************************;


 ** USER DEFINED DATASET CODE **;


 *******************************;


 ** Save final dataset to network **;
data ADAMQCW.<dataset>;
   set <dataset>;
run;

 ** Inline interactive compare of saved dataset **;
%s_compare(base=ADAM.<DATASET>,
           comp=ADAMQCW.Q_<DATASET>);

********;
%s_scanlog;
********;
