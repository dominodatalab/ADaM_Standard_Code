/*****************************************************************************\
*        O                                                                      
*       /                                                                       
*  O---O     _  _ _  _ _  _  _|                                                 
*       \ \/(/_| (_|| | |(/_(_|                                                 
*        O                                                                      
* ____________________________________________________________________________
* Sponsor              : Evelo
* Study                : 1867-101
* Analysis             : Final Analysis
* Program              : p_adslvars.sas
* Purpose              : Macro to merge common variables from ADSL and any other required variables from ADSL
* ____________________________________________________________________________
* DESCRIPTION                                                    
*                                                                   
* Input files:                                                    
*                                                                   
* Output files:                                                   
*                                                                 
* Macros:                                                         
*                                                                   
* Assumptions: Common ADSL variables has to be mentioned in macro variable "ADSLVARS" in study setup call.
							 If ADDVARS is not needed do not include in the macro call.                                                   
*                                                                   
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*  26JUL2021  |  Natalie Thompson  |  Original  (Copied and updated from Synairgen study)                                  
* ----------------------------------------------------------------------------
*  ddmmmyyyy  |   <<name>>  |  ..description of change..          
\*****************************************************************************/

%macro p_adslvars(dsin     = 	 , /* Name of input dataset to add ADSL variables to */
                  dsout    = 	 , /* Name of output dataset */
				  				addvars  = "", /* String of any additional adsl variables to merge from ADSL apart from what is mentioned in &ADSLVARS in study setup*/
                  leftjoin =  	 /* Default of program is right join to keep all records in input dataset, set to Y to keep only records in ADSL */
                  );

	%if &leftjoin = Y %then %let jointype = left join;
	%else %let jointype = right join;
	
	proc sql;
	  create table &dsout. as
        select a.*,
               &adslvars. 
               %if &addvars. ne "" %then %do;
                 ,&addvars. 
               %end;
	  from &dsin. a &jointype adam.adsl b on a.usubjid=b.usubjid;
    quit;

%mend p_adslvars;

