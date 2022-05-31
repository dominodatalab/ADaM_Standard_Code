/*****************************************************************************\
*        O
*       /
*  O---O     _  _ _  _ _  _  _|
*       \ \/(/_| (_|| | |(/_(_|
*        O
* _____________________________________________________________________________
* Sponsor              : Orchard
* Study                : OTL-103
* Program              : u_fig_nodata
* Purpose              : Utility to output a figure with no data to report
* _____________________________________________________________________________
* DESCRIPTION
*
* Input files: None
*
* Output files: None
*
* Macros: None
*
* Assumptions: None
*
* _____________________________________________________________________________
* PROGRAM HISTORY
*  05JUN2020  |  Emily Berrett       |  Original
* -----------------------------------------------------------------------------
*
\*****************************************************************************/

%macro p_fig_nodata();

  /*Dummy data to plot in white*/
  data dummy;
    x = 0;
    y = 0;
    output;
    x = 100;
    y = 100;
    output;
  run;

  /*Annotation for text in the middle of the plot*/
  %sganno;
  data anno;
    %sgtext(label="No data to report.",width=100,widthunit="PERCENT",textfont="Courier New",textsize=9,justify="CENTER",x1=50,y1=50);
  run;

  proc sgplot data = dummy noautolegend nocycleattrs sganno = anno;
    scatter x = x y = y / markerattrs = (color = white);
    xaxis display = none;
    yaxis display = none;
  run;

%mend p_fig_nodata;
