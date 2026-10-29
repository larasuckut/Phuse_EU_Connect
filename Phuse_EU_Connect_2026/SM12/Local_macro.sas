%macro dedup(data,vars);
	proc sort data=&data nouniquekey out=&data._dups;
		by &vars;
	run;
	
	%if %sysfunc(exist(&data._dups)) %then %put Duplicates found for &data..;
%mend dedup;
