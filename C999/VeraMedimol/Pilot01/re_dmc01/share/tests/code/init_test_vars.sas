/*****************************************************************************\
*        O                                                                     
*       /                                                                      
*  O---O     _  _ _  _ _  _  _|                                                
*       \ \/(/_| (_|| | |(/_(_|                                                
*        O                                                                     
* ____________________________________________________________________________
* Sponsor              : Veramed
* Study                : VeraMedimol
* Analysis             : re_dmc01
* Program              : init_test_vars.sas
* ____________________________________________________________________________
* DESCRIPTION
*
* This program is used to test that the init+verasetup macros set global
* variables as expected. This program is run by the init.tests.ps1 test
* script, which checks the SAS log file for expected results.
*
* Input files: none
*
* Output files: none
*                                                                
* Macros: init
*                                                                   
* Assumptions: none
*                                                                   
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*  2022-03-22  |   stuart.malcolm      | Original                                    
* ----------------------------------------------------------------------------
*  YYYYMMDD  |  username        | ..description of change..         
\*****************************************************************************/

%init;

* log global vars set by init/verasetup so they can be tested ;
%put %str(TE)ST: [Program: init_test_vars] [__runmode: &__runmode];
%put %str(TE)ST: [Program: init_test_vars] [__exemode: &__exemode];
%put %str(TE)ST: [Program: init_test_vars] [__full_path: &__full_path] ;
%put %str(TE)ST: [Program: init_test_vars] [__env_mode: &__env_mode]  ;
%put %str(TE)ST: [Program: init_test_vars] [__auto_path: &__auto_path] ;
%put %str(TE)ST: [Program: init_test_vars] [__env_runtime: &__env_runtime];
%put %str(TE)ST: [Program: init_test_vars] [__DELIM: &__DELIM];
%put %str(TE)ST: [Program: init_test_vars] [__re: &__re];
%put %str(TE)ST: [Program: init_test_vars] [__study: &__study];
%put %str(TE)ST: [Program: init_test_vars] [__compound: &__compound];
%put %str(TE)ST: [Program: init_test_vars] [__client: &__client];

