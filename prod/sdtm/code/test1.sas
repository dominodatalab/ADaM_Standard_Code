/*
 *  SAS program, created on Domino platform in SAS Studio
 *  to test the basics of running SAS code.
 */


* display the path to the current working directory;
%put %quote(%sysget(DOMINO_WORKING_DIR));

* initialise the environment;
%init;

