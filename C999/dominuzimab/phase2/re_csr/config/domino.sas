/* domino.sas - SAS setup program for Domino environment
 *
 * TODO - add header
 *
 * this setup relies on the following environment vars
 * that must be defined in the Domino platform:
 *
 * DOMINO_PROJECT_NAME
 * DOMINO_WORKING_DIR
 * DCUTDTC
 * 
 * Exported 
 */

* grab the environment varaibles that we need to create pathnames;
%let __WORKING_DIR  = %sysget(DOMINO_WORKING_DIR);
%let __PROJECT_NAME = %sysget(DOMINO_PROJECT_NAME);
%let __DCUTDTC      = %sysget(DCUTDTC);

* write to log for traceability ;
%put TRACE: (domino.sas) [__WORKING_DIR = &__WORKING_DIR.] ;
%put TRACE: (domino.sas) [__PROJECT_NAME = &__PROJECT_NAME.];
%put TRACE: (domino.sas) [__DCUTDTC = &__DCUTDTC.];


*EOF;