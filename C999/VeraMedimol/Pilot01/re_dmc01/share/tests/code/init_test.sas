/*****************************************************************************\
*        O                                                                     
*       /                                                                      
*  O---O     _  _ _  _ _  _  _|                                                
*       \ \/(/_| (_|| | |(/_(_|                                                
*        O                                                                     
* ____________________________________________________________________________
* Sponsor              : 
* Study                : 
* Analysis             : 
* Program              : test_init.sas
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
*  2022-03-13  |   stuart.malcolm      | Original                                    
* ----------------------------------------------------------------------------
*  YYYYMMDD  |  username        | ..description of change..         
\*****************************************************************************/


%init;

* sent global vars set by init macro to the log so they can be tested by test script;

%put %str(TR)ACE: [Program: init_test] [__runmode: &__runmode];
%put %str(TR)ACE: [Program: init_test] [__exemode: &__exemode];

