/*****************************************************************************\
*        O
*       /
*  O---O     _  _ _  _ _  _  _|
*       \ \/(/_| (_|| | |(/_(_|
*        O
* _____________________________________________________________________________
* Sponsor              : Orchard
* Study                : OTL-103
* Program              : rtfCourier.sas
* Purpose              : Set up style template for TFLs
* _____________________________________________________________________________
* DESCRIPTION
*
* Input files: N/A
*
* Output files: N/A
*
* Macros: N/A
*
* Assumptions: N/A
*
* _____________________________________________________________________________
* PROGRAM HISTORY
*  17FEB2020  |  Emily Berrett       |  Original
*  20FEB2020  |  Otis Rimmer         |  Test respecification of the border from 1pt to 0.5% (reset)
*  12MAR2020  |  Emily Berrett       |  Update fonts and add GraphFonts
* -----------------------------------------------------------------------------
*
\*****************************************************************************/

%macro p_rtfcourier();

  proc template;
    define style rtfCourier;
      parent = styles.printer;
      style fonts /
        'TitleFont2' = ("Courier, Cumberland AMT",9pt)
        'TitleFont' = ("Courier, Cumberland AMT",9pt)
        'StrongFont' = ("Courier, Cumberland AMT",9pt)
        'headingFont' = ("Courier, Cumberland AMT",9pt)
        'headingEmphasisFont' = ("Courier, Cumberland AMT",9pt)
        'FixedStrongFont' = ("Courier, Cumberland AMT",9pt)
        'FixedHeadingFont' = ("Courier, Cumberland AMT",9pt)
        'FixedFont' = ("Courier, Cumberland AMT",9pt)
        'FixedEmphasisFont' = ("Courier, Cumberland AMT",9pt)
        'EmphasisFont' = ("Courier, Cumberland AMT",9pt)
        'docFont' = ("Courier, Cumberland AMT",9pt)
        'BatchFixedFont' = ("Courier, Cumberland AMT",9pt);
      class GraphFonts /
        'NodeDetailFont' = ("Courier, Cumberland AMT",9pt)
        'NodeInputLabelFont' = ("Courier, Cumberland AMT",9pt)
        'NodeLabelFont' = ("Courier, Cumberland AMT",9pt)
        'NodeTitleFont' = ("Courier, Cumberland AMT",9pt)
        'GraphDataFont' = ("Courier, Cumberland AMT",9pt)
        'GraphUnicodeFont' = ("Courier, Cumberland AMT",9pt)
        'GraphValueFont' = ("Courier, Cumberland AMT",9pt)
        'GraphLabel2Font' = ("Courier, Cumberland AMT",9pt)
        'GraphLabelFont' = ("Courier, Cumberland AMT",9pt)
        'GraphFootnoteFont' = ("Courier, Cumberland AMT",9pt)
        'GraphTitleFont' = ("Courier, Cumberland AMT",9pt)
        'GraphTitle1Font' = ("Courier, Cumberland AMT",9pt)
        'GraphAnnoFont' = ("Courier, Cumberland AMT",9pt);
      class GraphData4 from GraphData4 /
        markersymbol = "tilde";
      class GraphData6 from GraphData6 /
        markersymbol = "triangle";
      class GraphData8 from GraphData8 /
        markersymbol = "star";
      class GraphData9 from GraphData9 /
        markersymbol = "triangledown";
      class GraphData10 from GraphData10 /
        markersymbol = "hash";
      class cell / paddingright = 1.6%;
      style Table from output /
        borderwidth = 1pt
        borderspacing = 1pt
        cellpadding = 1pt
        rules = groups
        frame = above
        backgroundcolor = _undef_;
      style color_list /
        'link' = blue
        'bgH' = white
        'fg' = black
        'bg' = white;
    end;
  run;

%mend p_rtfcourier;
