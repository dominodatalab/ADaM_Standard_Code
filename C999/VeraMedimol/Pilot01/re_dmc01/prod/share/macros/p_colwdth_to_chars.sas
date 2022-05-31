/*****************************************************************************\
*        O
*       /
*  O---O     _  _ _  _ _  _  _|
*       \ \/(/_| (_|| | |(/_(_|
*        O
* _____________________________________________________________________________
* Sponsor              : Orchard
* Study                : OTL-103
* Program              : u_colwdth_to_chars.sas
* Purpose              : Convert widths from u_colwdth to character widths
* _____________________________________________________________________________
* DESCRIPTION
*
* Input files: N/A
*
* Output files: N/A - macro variable for each column read in named [col]chars
*
* Macros: N/A
*
* Assumptions: All columns listed must have margins provided even if 0
*
* _____________________________________________________________________________
* PROGRAM HISTORY
*  02MAR2020  |  Emily Berrett       |  Original
* -----------------------------------------------------------------------------
*
\*****************************************************************************/

%macro p_colwdth_to_chars(cols=,margins=,cellpadding=1.6,charwidth=0.78);

  /*Number of columns to cycle through*/
  %let numcols = %sysfunc(countw(&cols));

  /*Cycle through each column and calculate width in characters*/
  %do ii = 1 %to &numcols;
    %let currcol = %scan(&cols,&ii.);
    %let currcolmargin = %scan(&margins,&ii.,%str( ));
    %let &currcol.widthnum = %sysfunc(compress(&&&currcol.width.,%str(%%)));
    %global &currcol.chars;
    %let &currcol.chars = %sysfunc(floor(%sysevalf((&&&currcol.widthnum. - &currcolmargin. - &cellpadding.)/&charwidth.)));
  %end;

%mend p_colwdth_to_chars;
