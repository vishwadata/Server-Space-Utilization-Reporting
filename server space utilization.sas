

/*************************************************server space ****************************************/
data extraction;
	infile datalines delimiter='~';
	input dept:$10. path:$100.;
	datalines;
PBG~/path/PVT_BANKING
QDESK~/path/PRIORITY_NONPRIORITY
NRI~/path/NRI
IBG~/path/IBG
;
run;

PROC sql;
	SELECT count(distinct dept) into:cnt from extraction;
	SELECT dept, path into:dt_1-:%sysfunc(compress(dt_&cnt.)), 
		:pt_1-:%sysfunc(compress(pt_&cnt.)) from extraction;
	run;
	options mprint mlogic;

	%macro loop();
		%do i=1 %to 4;
			%put check=&i.;
			X "find &&pt_&i. -type f -exec du --time -Sh {} + | sort -rh | head -n 100000000 >
/path/BACKUPS/VISHWA/&&dt_&i...txt";

		data &&dt_&i.;
			infile "/path/BACKUPS/VISHWA/&&dt_&i...txt" delimiter="    ";
			input size :$10. date :$10. filenames :$1000.;
			dept="&&dt_&i.";
		run;

	%end;
%mend;

%loop();

data memory(drop=date);
	set QDESK PBG IBG NRI;
	memory=input(substr(size, 1, length(size)-1), best12.);
	memoryinbytes=substr(size, length(size), 1);
	dates=input(date, anydtdte32.);
	format dates date9. year $4.;
	year=year(dates);

	if memoryinbytes='G' then
		kb=memory*(1024*1024);

	if memoryinbytes='M' then
		kb=memory*1024;

	if memoryinbytes='K' then
		kb=memory*1;
run;

proc sql;
	create table dept_wise as select dept, year, memoryinbytes, SUM(memory) AS 
		SUM_of_memory, SUM(KB) AS SUM_KB FROM memory GROUP BY dept, year, 
		memoryinbytes having memoryinbytes not='0';
	RUN;

proc sql;
	create table dept_wise_summary as select dept, year, SUM(SUM_KB) AS KB, 
		ROUND(calculated KB/1024/1024, 0.01) as GB FROM dept_wise GROUP BY dept, year 
		order by dept, KB desc;
	RUN;

PROC SORT DATA=dept_wise_summary(DROP=KB);
	BY year;
RUN;

PROC TRANSPOSE DATA=dept_wise_summary OUT=dept_wise_summary1;
	BY year;
	ID dept;
	VAR GB;
RUN;

DATA dept_wise_summary2(DROP=_NAME_);
	length year $10.;
	informat year $4.;
	format year $10.;
	SET dept_wise_summary1;
	ARRAY ZERO _NUMERIC_;

	DO OVER ZERO;

		IF ZERO=. THEN
			ZERO=0;
	END;
RUN;

%let path=/PATH/BACKUPS;
%PUT --->&PATH.;
X 
	"find &PATH. -type f -exec du --time -Sh {} + | sort -rh | head -n 100000000 >
/PATH/BACKUPS/VISHWA/TOP.txt";

data file_list;
	infile "/PATH/BACKUPS/VISHWA/TOP.txt" delimiter=" ";
	input size :$10. date :$10. filenames :$1000.;
run;

data dates(drop=date);
	set file_list;
	memory=input(substr(size, 1, length(size)-1), best12.);
	memoryinbytes=substr(size, length(size), 1);
	dates=input(date, anydtdte32.);
	format dates date9. year $4.;
	year=year(dates);

	if memoryinbytes='G' then
		kb=memory*(1024*1024);

	if memoryinbytes='M' then
		kb=memory*1024;

	if memoryinbytes='K' then
		kb=memory*1;
run;

PROC SQL;
	CREATE TABLE file_extensions as select UPCASE(SCAN(filenames, -1, '.')) as 
		extension, sum(kb) as ext_size_KB, 
		ROUND(calculated ext_size_KB/1024/1024, 0.01) as GB 
		from dates group by extension having extension in('$$1', 'BAK', 'CSV', 'DOCX', 'EGP', 'HTML',
		'JS', 'LOG', 'MAP', 'PDF', 'PNG', 'PY', 'SAS', 'SAS7BCAT', 'SAS7BDAT', 'TXT', 'XLS', 'XLSB', 
		'XLSX', 'XML', 'ZIP') order by 
		ext_size_KB DESC;
	RUN;

proc sql;
	create table folders as select year, memoryinbytes, SUM(memory) AS 
		SUM_of_memory, SUM(KB) AS SUM_KB, 
		CASE WHEN filenames LIKE '%BACKUPS%' THEN 'BACKUPS' 
			 WHEN filenames LIKE '%DATA_SETS%' THEN 'DATA_SETS' 
			 WHEN filenames LIKE '%OUTPUTS%' THEN 'OUTPUTS' 
			 WHEN filenames LIKE '%PVT_JOBS%' THEN 'PVT_JOBS' else 'others' END AS file_folders 
			 FROM dates GROUP BY calculated 
		file_folders, year, memoryinbytes having memoryinbytes not='0';
	RUN;

proc sql;
	create table folders_wise_summary as select file_folders, year, SUM(SUM_KB) AS 
		KB, ROUND(calculated KB/1024/1024, 0.01) as GB FROM folders GROUP BY 
		file_folders, year order by file_folders, KB desc;
	RUN;

proc sql;
	create table year_wise_summary as select year, SUM(SUM_KB) AS KB, 
		ROUND(calculated KB/1024/1024, 0.01) as GB FROM folders GROUP BY year order 
		by year, KB desc;
	RUN;

data year_wise_summary;
	length year $5.;
	informat year $4.;
	format year $5.;
	set year_wise_summary;
run;

PROC EXPORT DATA=dates(DROP=kb memory memoryinbytes) 
		OUTFILE="/PATH/OUTPUTS/SERVER_FILES.XLSX" DBMS=XLSX REPLACE;
RUN;

DATA DUMP;
	LENGTH FILENAME $30. link $200. URL $300.;
	FILENAME="ALL FILES FROM SERVER";
	link="<a href=http//PATH/SERVER_FILES.XLSX>Click to Download server Dump</a>";
	URL="<center><a href='mailto:vishwa?cc=bharath?
	subject=[Priority]Need to Clear the  Server Space'>draft a mail for clearing the space</a></center>";
run;

filename kvb email from=("Analytics Group <>") 
	sender=("Analytics Group <>") to=("vishwabharath") 
	subject="Server Space Information" CT="text/html";
Ods _all_ close;
ods listing close;
ods escapechar='^';
ods html body=kvb style=normal;
TITLE1 j=center COLOR=BLUE bold font=Mulish height=13pt "<U>Dept wise Summary<U>";

proc report data=dept_wise_summary2 STYLE(REPORT)=[cellspacing=0 borderwidth=2 
		TAGATTR="WRAP" FONT=('Mulish SemiBold', 11PT) OUTPUTWIDTH=35%] 
		STYLE(Header)=[FOREGROUND=WHITE BACKGROUND=maroon FONT=('Mulish SemiBold', 
		10PT) FONT_WEIGHT=BOLD TAGATTR="WRAP" BORDERCOLOR=BLACK] 
		STYLE(COLUMN)=[TAGATTR="WRAP" background=lightyellow FONT=('Mulish SemiBold', 
		9PT) foreground=black BORDERCOLOR=BLACK] style(Summary)=[Foreground=white 
		Background=maroon Bordercolor=Black font=('Mulish', 10pt)];
	column year PBG IBG NRI QDESK;
	define year / 'Years';
	RBREAK after / SUMMARIZE;
	COMPUTE after;
		year='Total-GB';
	ENDCOMP;
	footnote;
run;

TITLE1;
TITLE2 j=center COLOR=BLUE bold font=Mulish height=13pt "<U>Year wise Summary<U>";

proc report data=year_wise_summary STYLE(REPORT)=[cellspacing=0 borderwidth=2 
		TAGATTR="WRAP" FONT=('Mulish SemiBold', 11PT) OUTPUTWIDTH=35%] 
		STYLE(Header)=[FOREGROUND=WHITE BACKGROUND=maroon FONT=('Mulish SemiBold', 
		10PT) FONT_WEIGHT=BOLD TAGATTR="WRAP" BORDERCOLOR=BLACK] 
		STYLE(COLUMN)=[TAGATTR="WRAP" background=lightyellow FONT=('Mulish SemiBold', 
		9PT) foreground=black BORDERCOLOR=BLACK] GB;
	style(Summary)=[Foreground=white Background=maroon Bordercolor=Black 
		font=('Mulish', 10pt)];
	column year KB define year / 'Years';
	define KB /order=data 'Size-KB';
	define GB /order=data 'Size-GB';
	RBREAK after / SUMMARIZE;
	COMPUTE after;
		year='Total';
	ENDCOMP;
	footnote;
run;

TITLE2;
TITLE3 j=center COLOR=BLUE bold font=Mulish height=13pt "<U>Folders wise Summary<U>";

proc report data=folders_wise_summary OUT=summary_out missing 
		STYLE(REPORT)=[cellspacing=0 borderwidth=2 TAGATTR="WRAP" 
		FONT=('Mulish SemiBold', 11PT) OUTPUTWIDTH=35%] 
		STYLE(Header)=[FOREGROUND=WHITE BACKGROUND=maroon FONT=('Mulish SemiBold', 
		10PT) FONT_WEIGHT=BOLD TAGATTR="WRAP" BORDERCOLOR=BLACK] 
		STYLE(COLUMN)=[TAGATTR="WRAP" background=lightyellow FONT=('Mulish SemiBold', 
		9PT) foreground=black BORDERCOLOR=BLACK] style(Summary)=[Foreground=white 
		Background=maroon Bordercolor=Black font=('Mulish', 10pt)];
	column file_folders year KB GB;
	define file_folders /group 'Folders';
	define year / 'Years';
	define KB /order=data 'Size-KB';
	define GB /order=data 'Size-GB';
	break after file_folders/SUMMARIZE style=[FONT=(Mulish, 9PT) background=GREY 
		foreground=black font_weight=bold];
	RBREAK after / SUMMARIZE;
	COMPUTE after;
		file_folders='Total';
	ENDCOMP;
	footnote;
run;

TITLE3;
TITLE4 j=center COLOR=BLUE bold font=Mulish height=13pt "<U>File Extension wise Summary<U>";

proc report data=file_extensions missing STYLE(REPORT)=[cellspacing=0 
		borderwidth=2 TAGATTR="WRAP" FONT=('Mulish SemiBold', 11PT) OUTPUTWIDTH=35%] 
		STYLE(Header)=[FOREGROUND=WHITE BACKGROUND=maroon FONT=('Mulish SemiBold', 
		10PT) FONT_WEIGHT=BOLD TAGATTR="WRAP" BORDERCOLOR=BLACK] 
		STYLE(COLUMN)=[TAGATTR="WRAP" background=lightyellow FONT=('Mulish SemiBold', 
		9PT) foreground=black BORDERCOLOR=BLACK] style(Summary)=[Foreground=white 
		Background=maroon Bordercolor=Black font=('Mulish', 10pt)];
	column extension ext_size_KB GB;
	define extension /'Folders';
	define ext_size_KB /order=data 'Size-KB';
	define GB /order=data 'Size-GB';
	RBREAK after / SUMMARIZE;
	COMPUTE after;
		extension='Total';
	ENDCOMP;
	footnote;
run;

TITLE4;
TITLE5 j=center COLOR=BLUE bold font=Mulish height=13pt "<U>Top 10 files Occupied highest Space<U>";

proc report data=file_list(obs=10) STYLE(REPORT)=[cellspacing=2 borderwidth=2 
		TAGATTR="NOWRAP" FONT=('Mulish SemiBold', 11PT) OUTPUTWIDTH=45%] 
		STYLE(Header)=[FOREGROUND=WHITE BACKGROUND=maroon FONT=('Mulish SemiBold', 
		10PT) FONT_WEIGHT=BOLD TAGATTR="NOWRAP" BORDERCOLOR=BLACK] 
		STYLE(COLUMN)=[TAGATTR="NOWRAP" background=lightyellow FONT=('Mulish', 9PT) 
		foreground=black BORDERCOLOR=BLACK];
	column SR_NO size date filenames;
	define SR_NO /'Sr.no';
	define size /'Size';
	define date / 'Last Modified Date' style(column)=[just=c];
	define filenames / 'Filenames';
	COMPUTE SR_NO;
		A+1;
		SR_NO=A;
	ENDCOMP;
	footnote;
run;

TITLE5;
TITLE6 j=center COLOR=BLUE bold font=Mulish height=13pt "<U>All Server Files Dump<U>";

PROC REPORT DATA=DUMP STYLE(REPORT)=[cellspacing=2 borderwidth=3 FONT=(Mulish, 
		10PT)] STYLE(Header)=[FOREGROUND=BLACK BACKGROUND=orange FONT=(Mulish, 8PT) 
		FONT_WEIGHT=BOLD] STYLE(COLUMN)=[TAGATTR="NOWRAP" background=AZURE];
	columns FILENAME LINK URL;
	define FILENAME/'Filename';
	define LINK/'Link';
	define URL/'Draft a mail';
	footnote j=l bold bc=yellow "<u> <MARQUEE><BLINK> Note: Dear Team, The Information provided Regarding server 
space utilization for Internal Use only.
^{newline 1} Kindly Review the data carefully and take necessary actions as per your requirements.
^{newline 1} Ensure that critical files and system dependencies are not removed while clearing space. 
</BLINK></MARQUEE></u> ";
run;

TITLE6;
ods _all_ close;