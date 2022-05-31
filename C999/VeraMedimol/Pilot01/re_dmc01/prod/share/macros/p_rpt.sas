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
* Program              : p_rpt.sas
* ____________________________________________________________________________
* DESCRIPTION
* Macro used to create standard proc report 
*                                                                   
* Input files:                                                   
*                                                                   
* Output files:                                                   
*                                                                
* Macros:                                                         
*                                                                   
* Assumptions: Data is in long format and structured to tfldata standards. See
* documentation for more information. 
*                                                                   
* ____________________________________________________________________________
* PROGRAM HISTORY                                                         
*  2022-03-28  | Emily Gutleb     | Original                                    
* ----------------------------------------------------------------------------
*  2022-04-20  | Emily Gutleb     | Added functionality with no across variables       
\*****************************************************************************/


%macro p_Rpt(inds       =       /*input dataset, expected to follow tfl data conventions*/
            ,outds      =       /*output dataset, optional variable used to store dataset created by proc report. 
                                   This can be missing*/
            ,FLWs       =       /*format/label/where statement(s) to execute within proc report. This is inserted into
                                   the proc step as is and thus must result in complete statement/s including semicolons.*/

            ,avar       =       /*name of across variable is multiple are used then seperate by space, is multiple
                                  layers used seperated by comma. Assumption all use same cell type*/ 
            ,aorder         = data preloadfmt
                               /* ordering for across variable. Default of 'data PreLoadFmt' will order by appearance of values 
                                  in data if no format is applied. If a format is applied then the
                                  order of the values in the format will be used first followed by any unformatted values (in the order 
                                  they appear in the data. Use a NotSorted format for fine control over column order.
                                  Use 'formatted' for default proc report behaviour. See SAS documentation for more details*/
            ,resultvar      = 
                              /*list the result variables used for the across. This can be both numeric and character*/
            ,addvar         =
                               /*any additional variables in the dataset that are notprinted such as paging variables*/

            ,rowlabelheader =   /*header for the rowlabel column. Can be missing */
            ,rowlabelwidth  = 4.0in 
                                /* width of rowlabel column.*/
            ,colwidths      = 0.5in+0.4in+0.7in+0.4in
                                /* widths for reporting columns: first  is overall width, if using
                                   numeric then list the widths for indervidual numeric columns */

            ,linebreak    =      /*variable to specify a line break before. This can be missing but if populated by must 
                                   also be populated to see an effect when groups cross over pages*/ 
            ,sectionbreak   = line  
                                /* Specifies style for section breaks: No, Line or Page.
                                   If (upcase of first character) = L then:formats section label line with a bold top border. 
                                   If (upcase of first character) = P then: includes a "break after Section / page;" statement. Otherwise does neither. */

            ,dest           = ods /*specifies the destination of output. This can be ODS or RTF.
                                  ODS     = Uses only ODS formatting [default]. (Can only do first line indents.)
                                  RTF     = Uses &escapevar.R/RTF formatting. (Can do left margin indents but renders without
                                            indentation to other destinations*/ 
            ,rptoptions    =    /*for additional study specific options. Can be missing*/

            ,split      = #     /*this is the split variable used in the proc report, this could be preset in a study setup 
                                  or changed if needed for an indervidual output.*/
            ,escapevar      = ^ 
                               /*the ods escape variable used. Reccomend this is predefined in study set up*/
            ,tidyup         = 1
                              /*Set to 0 to turn off tidy up so temporary work datasets are kept*/
            ,resultlabel      = N /*Set to Y if labels from the tfl data should be displayed on the output*/ );

    /****************************************************/
    /*** pre processing                               ***/
    /****************************************************/



options mlogic mprint;

    %*split out input formating variables;

    data __inds;
        set &inds.;

        %* Checks if variables are in input dataset;
        %local nobs rptdsid rc;
        %let rptdsid=%sysfunc(open(&inds,in));

        %if &rptdsid gt 0 %then %do;
            %let nobs=%sysfunc(attrn(&rptdsid.,nobs));


            %local SectionVar;      %if %sysfunc(varnum(&RptDSID,Section))     =0 %then %let SectionVar=;      %else %let SectionVar     =Section;
            %local SectionLabelVar; %if %sysfunc(varnum(&RptDSID,SectionLabel))=0 %then %let SectionLabelVar=; %else %let SectionLabelVar=SectionLabel;


            %local PanelVar;        %if %sysfunc(varnum(&RptDSID,Panel))       =0 %then %let PanelVar=;        %else %let PanelVar       =Panel;
            %local Offset;
            %local PanelLabelVar;   %if %sysfunc(varnum(&RptDSID,PanelLabel))  =0 %then %let PanelLabelVar=;   %else %let PanelLabelVar  =PanelLabel;

            %local panelindentvar;
            %if %sysfunc(varnum(&rptdsid,panelopt))       = 0 %then %do;
                %let panelindentvar = ;
            %end;

            %else %do;
                    panelindent = input(scan(panelopt,1,"+","o"),best.);
                    call symput("panelindentvar","panelindent"); 
            %end;


            %local rowlabellabel; 
            %local rowindent; 
            %local rowbold; 
            %local rowbordertop; 


            %local RowLabelLabel; 
                %let RowLabelLabel  =%sysfunc(varlabel(&RptDSID,%sysfunc(varnum(&RptDSID,RowLabel))));

            %if %sysfunc(varnum(&rptdsid,rowopt))       = 0 %then %do;
                %let rowindentvar = ;
                %let rowboldvar = ;
                %let rowbordertopvar = ;
            %end;

            %else %do;
                rowindent = input(scan(rowopt,1,"+","o"),best.);
                rowbold = input(scan(rowopt,2,"+","o"),best.);
                rowbordertop = input(scan(rowopt,3,"+","o"),best.);

                call symput("rowindentvar","rowindent");
                call symput("rowboldvar","rowbold");
                call symput("rowbordertopvar","rowbordertop");  
            %end;

            %let rc = %sysfunc(close(&rptdsid));
            %end;

        %else
            %let nobs = 0;
    run;

    %* find the type of the resultvar input;
    data _null_;
       set sashelp.vcolumn (keep = memname name type format);
       where upcase(memname) = upcase("&inds.");

        %let resultvar_tot = %sysfunc(countw(&resultvar.));
        array cattype (*)$ cattype1-cattype&resultvar_tot.;
        retain cattype: catformat:;
        do p = 1 to &resultvar_tot.;
           next_resultvar = scan("&resultvar.",p);
           if upcase(name) = upcase(next_resultvar) then do;
                cattype(p) = type;
           end;
       end;

       all_type = catx(" ",of cattype:);
       call symput ("resultvartype",all_type);


    run;

    data type;
        set sashelp.vcolumn;
        where upcase(memname) = upcase("&inds.");
    run;


    %if &avar. ne %then %do;

        %*avar report variable;
        data __avar;
           if _n_ = 1 then do;
               %* count numeber of across variables;
               avar_tot = countw("&avar");
               call symput("avar_tot",put(avar_tot,best.));
           end;
           retain k;
           %*modify avar so we only break on spaces between different layers;
           avar_safe = tranwrd(tranwrd("&avar.",", ",",")," ","!");

           k = 1; %* Define start of loop, k is the element within the avar list;
              do while (scan(avar_safe, k,"!" ) ne "" ); %* Check if at the end of the avar list;
                i = scan(avar_safe, k, "!"); %* Set i to the next group number in the list; 
                output;     

                k = k +1;  %* Increment include list element for the next loop;      
            end;
        run;


        %*create a macro variable that can be used in the column line of the report;
        %local avar_rpt;
        proc sql noprint;
            select cat(strip(i),", (%str(&resultvar.))") into: avar_rpt separated by " "
            from __avar
            ;
        quit;
     %end;

     %else %do;
        %*create a macro variable that can be used in the column line of the report;
        %local avar_rpt;
        %let avar_rpt = &resultvar.;
     %end;

    
    /****************************************************/
    /*** report                                       ***/
    /****************************************************/


    proc report data = __inds nowindows missing spanrows 
                &rptoptions.
                split = "&split."  
                %if &outds. ~= %then %str(out = &outds.);
                ;

        %str(&flws);


        column &sectionvar. &sectionlabelvar.
               &panelvar. &panelindentvar. &panellabelvar. 
               row ("&rowlabelheader" rowlabel) &rowindentvar. &rowboldvar. &rowbordertopvar.
               &addvar.
               &avar_rpt.;

        %if &sectionvar. ~=      %then %str( define &sectionvar.       / group         noprint  order=internal     missing; );
        %if &sectionlabelvar. ~= %then %str( define &sectionlabelvar.  / group         noprint                     missing; );

        %if &panelvar. ~=        %then %str( define &panelvar.         / group         noprint  order=internal     missing; );
        %if &panelindentvar. ~=  %then %str( define &panelindentvar.   / group         noprint  order=internal     missing; );
        %if &panellabelvar. ~=   %then %str( define &panellabelvar.    / group         noprint                     missing; );
                                             define  row              / group         noprint  order=internal     missing;
                                             define  rowlabel         / group    flow            "&rowlabellabel." missing  width = 40 style = [cellwidth = &rowlabelwidth.  just = l];

        %if &rowindentvar. ~=    %then %str( define &rowindentvar.     / group         noprint                     missing; );
        %if &rowboldvar. ~=      %then %str( define &rowboldvar.       / group         noprint                     missing; );
        %if &rowbordertopvar. ~= %then %str( define &rowbordertopvar.  / group         noprint                     missing; );

        %if &avar. ne %then %do;
            %do i = 1 %to &avar_tot.;
                 %let next_avar = %scan(&avar.,&i.);
                                               define &next_avar.          / across               order= &aorder.   '' missing;
            %end;
        %end;
                                      

        %do i = 1 %to &resultvar_tot.;
            %let next_resultvar = %scan(&resultvar.,&i.);
            %let next_resulttype = %scan(&resultvartype.,&i.);
            %if "&next_resulttype." = "char" %then %do;
                                           define &next_resultvar.     / group    flow %if &resultlabel. = N %then %str( "" );    missing  width=16 style(column)=[width=%scan(&colwidths.,&i.,+) just = c];
            %end;

            %else %do;
                                           define &next_resultvar.     / analysis sum  %if &resultlabel. = N %then %str( "" );     missing  width= 8 style(column)=[width=%scan(&colwidths.,&i.,+) just=d]; 
            %end;


        %end;

        %if &addvar. ~= %then %do;
            %let p = %sysfunc(countw(&addvar.));
            %do q = 1 %to &p.;
                %let next_add = %scan(&addvar., &q.);
                                            define &next_avar.          /group         noprint                     missing;                

            %end; 

        %end;


        %if &sectionlabelvar. ~= %then %do;
            compute before sectionlabel / style = [font_weight=bold %if %upcase(%substr(&sectionbreak,1,1))=L %then %str(bordertopcolor=black bordertopwidth=1);];
                l = lengthn(sectionlabel);
                line @1 sectionlabel $varying. l;
            endcomp;
        %end;

        %if &panelindentvar. ~= %then %do;
            compute before panelindent;
                offset = panelindent;
            endcomp;
            %let offset=offset;
            %end;
        %else
            %let offset=0;

        %put &offset.;

        %if &panellabelvar. ~= %then %do;
            compute before panellabel   / style = [font_weight=bold];
                %if &dest. = ods %then %do;
                    if lengthn(panellabel) & sum(&offset.,0) then panellabel=repeat("&escapevar.{unicode 00a0}&escapevar._&escapevar._",sum(&offset.,0)-1)||panellabel;
                %end;
                %else %if &dest. =rtf %then %do;
                    if lengthn(panellabel) then panellabel=cat("&escapevar.r/rtf'\li",put(sum(&offset.,0)*200,z4.0),"' ",panellabel);
                    %end;
                call define(_row_,'style','style=[textindent=40]');
                l = lengthn(panellabel);
                line @1 panellabel $varying. l;
            endcomp;
        %end;

        %if &rowindentvar. ~= %then %do;
            compute rowindent;
                %if &dest. = ods %then %do;                            
                    call define('rowlabel','style','style=[textindent='||put(sum(&offset.,rowindent,0)*20,z3.0)||']');
                    %end;
                %else %if &dest. = rtf %then %do;
                    rowlabel=cat("&escapevar.r/rtf'\li",put(sum(&offset.,rowindent,0)*200,z4.0),"' ",rowlabel);
                    %end;
            endcomp;
        %end;                     

        %if &rowboldvar. ~= %then %do;
            compute &rowboldvar.;
                if &rowboldvar.      then call define(_row_,'style/merge','style=[font_weight=bold]');
            endcomp;
        %end;
        
        %if &rowbordertopvar. ~= %then %do;      
            compute &rowbordertopvar.;
                if &rowbordertopvar. then call define(_row_,'style/merge','style=[bordertopcolor=gray bordertopwidth=1]');
            endcomp;
        %end;
        
        %if %upcase(%substr(&sectionbreak.,1,1))=P %then %do;
            break after section / page;
        %end;

        %if &linebreak. ne "" %then %do;
            compute before &linebreak.;             
              line '';
            endcomp;    
        %end;

    run;

    %if &tidyup = 1 %then %do;
        proc datasets library = work nolist;
            delete __inds __avar;
        run;
    %end;



%mend p_rpt;
