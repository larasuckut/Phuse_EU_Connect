%macro dedup(data,vars);
	proc sort data=&data nodupkey dupout=&data._dups out=&data._unis;
		by &vars;
	run;
	
	%if %sysfunc(exist(&data._dups)) %then %put Duplicates found for &data..;
%mend dedup;

data test;
	length var1 var2 var3 $10;
	var1="test1";
	var2="test1";
	var3="test1";
	output;
	var1="test2";
	var2="test2";
	var3="test2";
	output;
	var1="test2";
	var2="test3";
	var3="test2";
	output;
	var1="test1";
	var2="test1";
	var3="test1";
	output;
run;

%dedup(test,var1 var2 var3)

%macro dedup2(data,vars);
	proc sort data=&data nouniquekey out=&data._dups;
		by &vars;
	run;
	
	%if %sysfunc(exist(&data._dups)) %then %put Duplicates found for &data..;
%mend dedup2;

%dedup2(test,var1 var2 var3)
