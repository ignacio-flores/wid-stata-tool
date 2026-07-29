// -------------------------------------------------------------------------- //
// quality_filter parser tests that fail before network/API requests
// -------------------------------------------------------------------------- //

version 15
clear all
discard

if "$root" == "" {
	global root "`c(pwd)'"
}

capture confirm file "$root/ssc/wid.ado"
if (_rc) {
	display as error "global root must point to the wid-stata-tool repository"
	exit 601
}

sysdir set PERSONAL "$root/ssc"
cd "$root/tests"

// Load helper programs before testing them directly. An auto-loaded wid command
// that exits with an error does not leave its sibling programs available.
quietly run "$root/ssc/wid.ado"

// Full and abbreviated empty options must reach the option-specific diagnostic
tempfile full_empty_log
tempname full_empty_log_name
quietly log using "`full_empty_log'", text replace name(`full_empty_log_name')
capture noisily wid, quality_filter() clear
local full_empty_rc = _rc
quietly log close `full_empty_log_name'
if (`full_empty_rc' != 198) {
	display as error "quality_filter() returned `full_empty_rc'; expected 198"
	exit 9
}
local full_empty_output = fileread("`full_empty_log'")
if (strpos(`"`full_empty_output'"', "quality_filter() cannot be empty") == 0) {
	display as error "quality_filter() did not emit its empty-option diagnostic"
	exit 9
}

tempfile abbreviated_empty_log
tempname abbreviated_empty_log_name
quietly log using "`abbreviated_empty_log'", text replace name(`abbreviated_empty_log_name')
capture noisily wid, quality() clear
local abbreviated_empty_rc = _rc
quietly log close `abbreviated_empty_log_name'
if (`abbreviated_empty_rc' != 198) {
	display as error "quality() returned `abbreviated_empty_rc'; expected 198"
	exit 9
}
local abbreviated_empty_output = fileread("`abbreviated_empty_log'")
if (strpos(`"`abbreviated_empty_output'"', "quality_filter() cannot be empty") == 0) {
	display as error "quality() did not emit the quality_filter() empty-option diagnostic"
	exit 9
}

// Parser failures are tested directly so another command-level error cannot pass
capture noisily wid_parse_quality_filter `"quality=3"'
if (_rc != 198) {
	display as error "quality selector returned " _rc "; expected 198"
	exit 9
}

capture noisily wid_parse_quality_filter `"data_quality=6"'
if (_rc != 198) {
	display as error "upper bound above 5 returned " _rc "; expected 198"
	exit 9
}

capture noisily wid_parse_quality_filter `"data_quality=-1"'
if (_rc != 198) {
	display as error "lower bound below 0 returned " _rc "; expected 198"
	exit 9
}

capture noisily wid_parse_quality_filter `"data_quality=5 3"'
if (_rc != 198) {
	display as error "descending bounds returned " _rc "; expected 198"
	exit 9
}

capture noisily wid_parse_quality_filter `"data_quality=abc"'
if (_rc != 198) {
	display as error "nonnumeric bound returned " _rc "; expected 198"
	exit 9
}

capture noisily wid_parse_quality_filter `"data_quality=3 4 5"'
if (_rc != 198) {
	display as error "three bounds returned " _rc "; expected 198"
	exit 9
}

capture noisily wid_parse_quality_filter `"avg_quality={min:4,max:2}"'
if (_rc != 198) {
	display as error "descending named bounds returned " _rc "; expected 198"
	exit 9
}

capture noisily wid_parse_quality_filter `"data_quality=3; data_quality=4"'
if (_rc != 198) {
	display as error "duplicate data_quality selector returned " _rc "; expected 198"
	exit 9
}

capture noisily wid_parse_quality_filter `"avg_quality=2; avg_quality=3"'
if (_rc != 198) {
	display as error "duplicate avg_quality selector returned " _rc "; expected 198"
	exit 9
}

capture noisily wid_parse_quality_filter `"row_score=3"'
if (_rc != 198) {
	display as error "removed row_score selector returned " _rc "; expected 198"
	exit 9
}

capture noisily wid_parse_quality_filter `"series_score=3"'
if (_rc != 198) {
	display as error "removed series_score selector returned " _rc "; expected 198"
	exit 9
}

// Valid parser forms retain their existing bounds and selector behavior
quietly wid_parse_quality_filter `"3"'
if (r(data_quality_filter) != 1 | r(avg_quality_filter) != 0 | ///
	r(data_quality_min) != 3 | r(data_quality_max) != 5) {
	display as error "unnamed quality bounds were parsed incorrectly"
	exit 9
}

quietly wid_parse_quality_filter `"data_quality=3 5; avg_quality=4"'
if (r(data_quality_filter) != 1 | r(avg_quality_filter) != 1 | ///
	r(data_quality_min) != 3 | r(data_quality_max) != 5 | ///
	r(avg_quality_min) != 4 | r(avg_quality_max) != 5) {
	display as error "combined quality bounds were parsed incorrectly"
	exit 9
}

// If score_filter were still accepted, populated memory would produce error 4
clear
set obs 1
capture noisily wid, score_filter(3)
if (_rc != 198) {
	display as error "removed score_filter() option returned " _rc "; expected 198"
	exit 9
}
