/*****************************************************************************\
*        O
*       /
*  O---O     _  _ _  _ _  _  _|
*       \ \/(/_| (_|| | |(/_(_|
*        O
* _____________________________________________________________________________
* Sponsor              : Orchard
* Study                : OTL-103
* Program              : u_rowsperpage.sas
* Purpose              : Determine the maximum number of rows that can fit on a
*                        page based on titles and footnotes included
* _____________________________________________________________________________
* DESCRIPTION
*
* Input files: refdata.titles
*
* Output files: Macro variable max_rows_per_page for use in mcrAddPageVar
*
* Macros: u_breakvar
*
* Assumptions: Breaks do not account for existing coded breaks so number of rows
*              used may be overestimated - you can use fuzz to account for this
*
* _____________________________________________________________________________
* PROGRAM HISTORY
*  19FEB2020  |  Emily Berrett       |  Original
*  13JUL2020  |  Emily Berrett       |  Recognising unicode break as a break
* -----------------------------------------------------------------------------
*
\*****************************************************************************/

%macro p_rowsperpage(tfl_id=,linesperpage=41,charsperline=126,columnrows=1,break=|n,esc=|);

  /*Read in titles and footnotes and determine how many rows these take up*/
  data _null_;
    set refdata.titles (where = (tfl_id = "&tfl_id"));

    array tf {*} title2-title10 footnote1-footnote9;
    array tf_new {*} $ 1000 _title2-_title10 _footnote1-_footnote9;
    array lines {*} _lines2-_lines20;

    do __ii = 1 to dim(tf);
      *Change any instances of unicode breaks to actual breaks so they are counted as 1 new row not 1 character;
      tf{__ii} = tranwrd(upcase(tf{__ii}),upcase("&esc.{unicode 000A}"),"&break");
      *Ensure any codes only count as one character;
      *This works by replacing each instance of "[escape character]{[any characters]}" with simply ".";
      *Since many common escape characters have special meanings in PRX, these have to be overridden if used;
      if "&esc." in ("{" "}" "[" "]" "(" ")" "^" "$" "." "|" "*" "+" "?" "\") then tf{__ii} = prxchange("s/\&esc.\{([^\{\}].)*\}/./",-1,tf{__ii});
      else tf{__ii} =prxchange("s/&esc.\{([^\{\}].)*\}/./",-1,tf{__ii});
      *Identify breaking for each variable;
      %u_breakvar(var=tf{__ii},newvar=tf_new{__ii},break=&break,length=&charsperline,slashyn=N);
      *Replace break characters with single character to identify number of words where each word is a line;
      tf_new{__ii} = tranwrd(tf_new{__ii},"&break.","&esc.");
      *Count number of lines;
      if tf_new{__ii} ^= "" then lines{__ii} = countw(tf_new{__ii},"&esc");
      else lines{__ii} = 0;
    end;

    *Total number of rows from titles and footnotes;
    rows = sum(of _lines2-_lines20) + 4;

    *Available figure height;
         if rows =  6 then figheight = 5.94;
    else if rows =  7 then figheight = 5.78;
    else if rows =  8 then figheight = 5.61;
    else if rows =  9 then figheight = 5.45;
    else if rows = 10 then figheight = 5.28;
    else if rows = 11 then figheight = 5.12;
    else if rows = 12 then figheight = 4.95;
    else if rows = 13 then figheight = 4.79;
    else if rows = 14 then figheight = 4.62;
    else if rows = 15 then figheight = 4.46;
    else if rows = 16 then figheight = 4.29;
    else if rows = 17 then figheight = 4.13;
    else figheight = 3.96;

    *Output value into global macro variable;
    call symputx("figheight",figheight,'G');

    *Maximum number of rows available;
    max_rows_per_page = strip(put(&linesperpage - rows - 1 - &columnrows,best.));

    *Output value into global macro variable;
    call symputx("max_rows_per_page",max_rows_per_page,'G');

  run;

%mend p_rowsperpage;
