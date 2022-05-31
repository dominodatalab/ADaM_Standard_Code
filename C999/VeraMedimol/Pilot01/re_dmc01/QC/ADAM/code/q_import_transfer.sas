dm 'out;clear;';
dm 'log;clear;';

/*****************************************************************************\
*       O
*      /
* O---O|    _  _ _  _ _  _  _|
*      \ \/(/_| (_|| | |(/_(_|
*       O
*
* ____________________________________________________________________________ 
* Sponsor	: Veramedimol
* Study	    : Pilot01
* Analysis	: 
* Program	: q_import_transfer.sas
* Purpose	: This program calls the cstutilxptread macro to convert ADAM xpt files 
*             in a specified directory to SAS datasets and output them to a 
*             specified directory
* ____________________________________________________________________________
* DESCRIPTION
*
* Input files  : 
*
* Output files :
*
* Macros       :
*
* Assumptions  :
*
* ____________________________________________________________________________
* PROGRAM HISTORY
*
* 03May2022 | Dianne Weatherall | Original
* ----------------------------------------------------------------------------
* ddmmmyyyy |	<<name>>	| ..description of change..
\*****************************************************************************/

%init;

%cstutilxptread(
  _cstSourceFolder  = &__env_client.&__DELIM.transfer&__DELIM.Received&__DELIM.20220310_CDISCPILOT01_SDTM_Data&__DELIM.sdtm-adam-pilot-project-master&__DELIM.updated-pilot-submission-package&__DELIM.900172&__DELIM.m5&__DELIM.datasets&__DELIM.cdiscpilot01&__DELIM.analysis&__DELIM.adam&__DELIM.datasets,
  _cstOutputLibrary = adamqcw,
  _cstExtension     = XPT,
  _cstOptions       = ,
  _cstReturn        = _cst_rc,
  _cstReturnMsg     = _cst_rcmsg
  );

********;
%s_scanlog;
********;
