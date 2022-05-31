/*****************************************************************************\
*        O                                                                     
*       /                                                                      
*  O---O     _  _ _  _ _  _  _|                                                
*       \ \/(/_| (_|| | |(/_(_|                                                
*        O                                                                     
* ____________________________________________________________________________
* Sponsor              :  Evelo
* Study                :  EDP1815-201
* Analysis             :  Macro to create study day variables
* Program              :  q_day.sas
* ____________________________________________________________________________
* DESCRIPTION                                                   
*                                                                   
* Input files:                                                    
*                                                                   
* Output files:                                                    
*                                                                
* Macros:                                                         
*                                                                   
* Assumptions:                                                    
*                                                                   
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
* 18NOV2020  | Nancy Carpenter  | Original                                    
* ----------------------------------------------------------------------------
* ddmmmyyyy  |   <<name>>       | ..description of change..         
\*****************************************************************************/

%macro q_day(dtvar=adt,    /* Input date variable */
		      dyvar=ady);   /* Output day variable */

 if nmiss(trtstdt, &dtvar)=0 then do;
         if &dtvar lt trtstdt then &dyvar=&dtvar-trtstdt;
	else if &dtvar ge trtstdt then &dyvar=&dtvar-trtstdt+1;
 end;


%mend q_day;
