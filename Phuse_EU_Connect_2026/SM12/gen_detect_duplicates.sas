***************************************************************************************************;
***************************************************************************************************;
*   Evidenze Germany
*
*   Project             Generalized Macros
*   Study               utility
*   Program name        gen_detect_duplicates.sas
*   Version             1.0
*
*   Purpose             Detect duplicated entries for a combination of variables in a dataset.
*
*   Author              Lara Suckut
*   Reference           URS_gen_detect_duplicates.xlsx  
*   Validation level    C - Test Procedures
*   Validated by        xy
*   Reviewed by         xyz
*   Software            X64 / SAS9.4M8
*
*   Input               
*       Parameters:
*          Name:        INLIB 
*          Description: Input library.
*          Mandatory:   Yes
*          Default:     raw_data
*          Example:     mylib
*                       
*          Name:        INDATA 
*          Description: Input sas7bdat dataset.
*          Mandatory:   Yes
*          Example:     mydata
*                       
*          Name:        INVAR_KEY 
*          Description: Input key variables, space-separated, whose combination will be checked for duplicate values.
*          Mandatory:   Yes
*          Example:     var1 var2 var3
*                       
*          Name:        OUTLIB 
*          Description: Output library. 
*                       Either OUTLIB with OUTDATA or OUTREPORT must be valued. Must be valued if OUTDATA is valued.
*          Mandatory:   No
*          Example:     duplib
*                       
*          Name:        OUTDATA 
*          Description: Output sas7bdat dataset with duplicated key variable values. 
*                       Either OUTLIB with OUTDATA or OUTREPORT must be valued. Must be valued if OUTLIB is valued.
*          Mandatory:   No
*          Example:     out
*                       
*          Name:        OUTREPORT 
*          Description: Path and name of output xlsx report of duplicated key variable values. 
*                                        Either OUTLIB with OUTDATA or OUTREPORT must be valued.
*          Mandatory:   No
*          Example:     ../reports/duplicates_mydata.xlsx
*                       
*          Name:        EMAIL 
*          Description: Email adress(es) to notify in case any duplicates are detected.
*          Default:     lara.suckut@evidenze.com
*          Mandatory:   No
*          Example:     test@evidenze.com
*
*          Name:        OUTMACROVAR 
*          Description: Global macro variable set to 1 to notify in case any duplicates are detected.
*          Default:     
*          Mandatory:   No
*          Example:     duplicates_detected
*
*          Name:        DEBUG 
*          Description: Set to 1 to keep intermdeiate datasets and libraries at the end.
*          Default:     0
*          Allowed:     0,1
*          Mandatory:   Yes
*          Example:     1
*
*       Source data: sas7bdat datasets
*
*   Output              OUTDATA dataset and/or OUTREPORT xlsx file
*
*   Example             %gen_detect_duplicates(inlib=work,indata=test,invar_key=var1 var2 var3,
*.                      outlib=work,outdata=dups_test,outreport=,email=lara.suckut@evidenze.com,macrovar=test_dups)
*
*	Dependencies	    none
*
***************************************************************************************************;
*
*   Modifications
*	Changed by          Lara Suckut, 14Aug2026
*   Reason              Initial Version
*
*
***************************************************************************************************;
%macro gen_detect_duplicates(inlib=raw_data
							,indata=
							,invar_key=
							,outlib=
							,outdata=
							,outreport=
							,email=lara.suckut@evidenze.com
							,outmacrovar=
							,debug=0
							)/minoperator;
							
    /*---------------------------------------------------------------------*/
    /* Block_1: --- Initialization --------------------------------------- */
    /*---------------------------------------------------------------------*/
	%put ;
	%put Starting execution of macro &sysmacroname Version 1;
	%put ;
	
	%*** print macro parameters to log ***;
	%put ;
	%put Parameters:;
	%put _local_;
	%put ;
		
	*initialize local macro parameters;
	%local _options _error _note _abort _n_dups _macroparams;
	
	*save previous options;
	data _NULL_;
		call symputx('_options',catx(' ',getoption('nodlcreatedir'),getoption('nonotes')),'L');
	run;
	
	option nonotes;
	
	*create work subdirectory;
	option dlcreatedir;
		libname dedup "%sysfunc(pathname(work))/dedup";
	option nodlcreatedir;
	
	*save prefix for custom messages and abortion parameter;
	data _NULL_;
		call symputx("_error","%str(ERR)OR: gen_detect_duplicates macro - ","L");
		call symputx("_note","NOTE: gen_detect_duplicates macro - ","L");
		call symputx("_abort",0,"L");
	run;
	
    /*---------------------------------------------------------------------*/
    /* Block_2: --- Parameter validation --------------------------------- */
    /*---------------------------------------------------------------------*/
	*Check if expected parameters are valued;
	data dedup._empty_params;
		length parameter $10 parameter_value $50;
		do ii=1 to countw("INLIB INDATA INVAR_KEY DEBUG",' ');
			parameter=scan("INLIB INDATA INVAR_KEY DEBUG",ii,' ');
			parameter_value=symget(parameter);
			if parameter_value eq '' then do;
				put "&_error";
				put "&_error The parameter " parameter +(-1) " must be valued.";
				put "&_error";
				call symputx("_abort",1,"L");
			end;
		end;
		if (%length(&outlib) eq 0 and %length(&outdata) ne 0) or (%length(&outlib) ne 0 and %length(&outdata) eq 0) then do;
			put "&_error";
			put "&_error The parameters OUTLIB and OUTDATA must both be valued or neither.";
			put "&_error";
			call symputx("_abort",1,"L");
		end;
		if %length(&outlib) eq 0 and %length(&outdata) eq 0 and %length(&outreport) eq 0 then do;
			put "&_error";
			put "&_error Either the parameters OUTLIB with OUTDATA or parameter OUTREPORT must be valued.";
			put "&_error";
			call symputx("_abort",1,"L");
		end;
	run;
	
	*Check if inlib is assigned;
	data _NULL_;
		if libref("&inlib") ne 0 then do;
			put "&_error";
			put "&_error The library from parameter INLIB (value: &inlib) is not assigned.";
			put "&_error";
			call symputx("_abort",1,"L");
		end;
	run;
	
	*Check if outlib is assigned;
	%if %length(&outlib) ne 0 %then %do;
		data _NULL_;
			if libref("&outlib") ne 0 then do;
				put "&_error";
				put "&_error The library from parameter OUTLIB (value: &outlib) is not assigned.";
				put "&_error";
				call symputx("_abort",1,"L");
			end;
		run;
	
	%end;
	
	*Check if outreport has an existing path;
	%if %length(&outreport) ne 0 %then %do;
		data _NULL_;
			outreppath=substrn(transtrn("&outreport","\","/"),1,findc("&outreport","\/",-1))||"/";
			if fileexist(outreppath) ne 1 then do;
				put "&_error";
				put "&_error.The path " outreppath "from parameter OUTREPORT (value: &outreport) does not exist.";
				put "&_error";
				call symputx("_abort",1,"L");
			end;
		run;
		
		*Check if outreport ends with .xlsx;
		data _NULL_;
			if prxmatch('/.xlsx$/i',strip("&outreport")) eq 0 then do;
				put "&_error";
				put "&_error The parameter OUTREPORT (value: &outreport) must end with '.xlsx'.";
				put "&_error";
				call symputx("_abort",1,"L");
			end;
		run;

	%end;
	
	*Check if email has expected format;
	%if %length(&email) ne 0 %then %do;
		data _NULL_;
			if prxmatch('/^[0-9A-Za-z][0-9A-Za-z\.]+[0-9A-Za-z]\@evidenze\.com$/',strip("&email")) eq 0 then do;
				put "&_error";
				put "&_error The parameter EMAIL (value: &email) must be a valid company email adress.";
				put "&_error";
				call symputx("_abort",1,"L");
			end;
		run;
	
	%end;
	
	*Check if debug is valid;
	%if %length(&debug) ne 0 %then %do;
		data _NULL_;
			if not("&debug" in ("0" "1")) then do; 
				put "&_error";
				put "&_error The parameter DEBUG (value: &debug) must be 0 or 1.";
				put "&_error";
				call symputx("_abort",1,"L");
			end;
		run;
		
	%end;
	
	*Exit macro if issue;
	%if "&_abort" eq "1" %then %goto exit;
	
	*Check if indata exists;
	data _NULL_;
		if exist("&inlib..&indata") ne 1 then do;
			put "&_error";
			put "&_error The dataset from parameter INDATA (value: &indata) does not exist in library INLIB (value: &inlib).";
			put "&_error";
			call symputx("_abort",1,"L");
		end;
	run;
	
	*Exit macro if issue;
	%if "&_abort" eq "1" %then %goto exit;
		
	*Check if invar_key variables exist;
	data dedup._check_vars;
		length var $50;
		vars="&invar_key";
		dsid=open("&inlib..&indata");
		do ii=1 to countw(vars,' ');
			var=scan(vars,ii,' ');
			varnum=varnum(dsid,var);
			if varnum eq 0 then do;
				put "&_error";
				put "&_error The variable " var "from parameter INVAR_KEY (value: &invar_key) does not exist";
				put "&_error in the dataset from parameter INDATA (value: &indata) in library INLIB (value: &inlib).";
				put "&_error";
				call symputx("_abort",1,"L");
			end;
			output;
		end;
	run;
	
	*Exit macro if issue;
	%if "&_abort" eq "1" %then %do;
		%put &_error;
		%put &_error Macro terminated due to invalid parameters.;
		%put &_error ;		
		%goto exit;
	%end;
		
    /*---------------------------------------------------------------------*/
    /* Block_3: --- Core logic ------------------------------------------- */
    /*---------------------------------------------------------------------*/
									
	proc sort data=&inlib..&indata nodupkey dupout=dedup._%sysfunc(substrn(&outdata,1,31)) out=dedup._%sysfunc(substrn(&outdata.,1,26))_unis;
		by &invar_key;
	run;
	
	proc sql noprint;
		select count(*) into:_n_dups trimmed from dedup._%sysfunc(substrn(&outdata,1,31));
	quit;
	
	data _NULL_;
		if "&_n_dups" ne "0" then do;
			put "&_note";
			put "&_note The dataset from parameter INDATA (value: &indata) does contain duplicates.";
			put "&_note";
			call symputx("_abort",1,"L");
		end;
		else do;
			put "&_note";
			put "&_note The dataset from parameter INDATA (value: &indata) does not contain duplicates.";
			put "&_note";
			call symputx("_abort",1,"L");
		end;
	run;
	
	* Optional: output dataset;
	%if %length(&outlib) ne 0 and %length(&outdata) ne 0 %then %do;
		data &outlib..&outdata;
			set dedup._%sysfunc(substrn(&outdata,1,31));
		run;
		
	%end;
	
	*Optional: output report;
	%if %length(&outreport) ne 0 %then %do;
		ods listing close;
		options missing = ' ';
		ods Excel file = "&outreport"
		  options 
		   (sheet_interval = 'none'
		  	sheet_name = 'Duplicates'
		   )
		;
		title "&_n_dups duplicated entries found in dataset &inlib..&indata for variable(s) &invar_key..";
		proc report data = dedup._%sysfunc(substrn(&outdata,1,31)) nowd
		  style(REPORT) = {cellpadding = 5 background = #D0C7A8 font_size = 12pt}
		  style(COLUMN) = {font_face = Arial background = white font_size = 12pt}
		  style(HEADER) = {font_face = Arial foreground = black background = #EBE8DA font_size = 12pt}
		;
		  column &invar_key;
		run;
		
		data _null_;
		  if nobs then stop;
		  file print;
		  put "No duplicates were found.";
		  stop;
		  set dedup._%sysfunc(substrn(&outdata,1,31)) nobs=nobs;
		run;
		
		ods Excel close;
		ods listing;

	%end;
	
	*Optional: output macrovariable;
	%if %length(&outmacrovar) ne 0 %then %do;
		%global &outmacrovar;
		%if "&_n_dups" ne "0" %then %let &outmacrovar=1;
		%else %let &outmacrovar=0;
	%end;
	
	*Optional: send email;
	*Save parameters;
	proc sql noprint;
		select catx(': ',name,value) into:_macroparams separated by '|' from dictionary.macros where scope eq "&sysmacroname" and lowcase(name) in ("inlib","indata","invar_key","outlib","outdata","outreport","email","macrovar","debug");
	quit;
	
	*Send email;
	%if %length(&email) ne 0 %then %do;
		filename mymail email "&email" 
		         subject="Macro &sysmacroname"
		         %if %length(&outreport) ne 0 %then %do;
		         	attach=("&outreport" content_type="excel")
		         %end;
		         ;
		
		data _null_;
			file mymail;
			put "Dear user,";
			%if "&_n_dups" eq "1" %then %do;
				put "The macro &sysmacroname found 1 duplicated entry in dataset &inlib..&indata for variable(s) &invar_key..";
			%end;
			%else %do;
				put "The macro &sysmacroname found &_n_dups duplicated entries in dataset &inlib..&indata for variable(s) &invar_key..";
			%end;
			put "Best regards,";
			put "Your macro team";
			put ;
			put "Parameters used:";
			%do ii=1 %to %sysfunc(countw("&_macroparams",'|'));
				put "%scan(&_macroparams,&ii,'|')";
			%end;
			put ;
		run;
		
	%end;
	
    /*-------------------------------------------------------------------*/
    /* Block_4: --- Clean-up ------------------------------------------- */
    /*-------------------------------------------------------------------*/
									
	%exit:
	
	%*** reset options ***;
	options &_options;
	
	%*** delete intermediate datasets unless debug parameter is 1 or error occurred ***;
	%if "&debug" eq "0" and not(&syserr in ("3" "4")) and not(%sysevalf(&syserr gt 6)) %then %do;
		proc datasets lib=dedup nolist;
			delete _:;
		run;
		
		quit;
		
		libname dedup clear;
	
	%end;
	
	%put ;
	%put Ending execution of macro &sysmacroname Version 1;
	%put ;

%mend gen_detect_duplicates;
