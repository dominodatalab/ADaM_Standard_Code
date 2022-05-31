/*****************************************************************************\
*        O                                                                     
*       /                                                                      
*  O---O     _  _ _  _ _  _  _|                                                
*       \ \/(/_| (_|| | |(/_(_|                                                
*        O                                                                     
* ____________________________________________________________________________
* Sponsor              :  Evelo
* Study                :  EDP1815-205
* Analysis             :  Macro to compress statistics for QC proc compare
* Program              :  q_compress.sas
* ____________________________________________________________________________
* DESCRIPTION                                                   
*                                                                   
* Input files:         &dsetin                                          
*                                                                   
* Output files:        &dsetout                                           
*                                                                
* Macros:                                                         
*                                                                   
* Assumptions:         
*                                                                   
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
* 10NOV2020  | Nancy Carpenter  | Copied from EDP1066-001                                    
* ----------------------------------------------------------------------------
* ddmmmyyyy  |   <<name>>       | ..description of change..         
\*****************************************************************************/

%macro q_compress(
   dsetin=,     /* Input dataset */
   dsetout=,    /* Output dataset */
   compress_vars=  /* List of variables to align */
   ); 

/* Construct an array containing align_vars and right align */
data &dsetout.(drop=i);
   set &dsetin.;

   array compress_vars (*) &compress_vars.;

   do i=1 to dim(compress_vars);
      compress_vars{i} = compress(compress_vars{i});
   end;

run;

%mend q_compress;
