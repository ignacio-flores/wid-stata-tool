// -------------------------------------------------------------------------- //
// Input validation and local command resolution tests
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

which wid

findfile wid.ado
local wid_ado = lower(subinstr(`"`r(fn)'"', "\", "/", .))
local expected_wid_ado = lower(subinstr(`"$root/ssc/wid.ado"', "\", "/", .))
if (`"`wid_ado'"' != `"`expected_wid_ado'"') {
	display as error "wid.ado resolved to `wid_ado'; expected `expected_wid_ado'"
	exit 9
}

findfile wid.jar
local wid_jar = lower(subinstr(`"`r(fn)'"', "\", "/", .))
local expected_wid_jar = lower(subinstr(`"$root/ssc/wid.jar"', "\", "/", .))
if (`"`wid_jar'"' != `"`expected_wid_jar'"') {
	display as error "wid.jar resolved to `wid_jar'; expected `expected_wid_jar'"
	exit 9
}

findfile sfi-api.jar
findfile json-20180813.jar

// Data-loss protection
clear
set obs 1
capture noisily wid, areas(FR) indicator(sptinc)
if (_rc != 4) {
	display as error "data-loss protection did not return error 4"
	exit 9
}

// Required country/indicator selection
clear
capture noisily wid, clear
if (_rc != 198) {
	display as error "missing country/indicator selection did not return error 198"
	exit 9
}

// Invalid indicator codes
capture noisily wid, indicators(foo) areas(FR) clear
if (_rc != 198) {
	display as error "short indicator code did not return error 198"
	exit 9
}

capture noisily wid, indicators(SPTINC) areas(FR) clear
if (_rc != 198) {
	display as error "uppercase indicator code did not return error 198"
	exit 9
}

capture noisily wid, indicators(sptincx) areas(FR) clear
if (_rc != 198) {
	display as error "long indicator code did not return error 198"
	exit 9
}

// Invalid percentile, age, and population codes
capture noisily wid, indicators(sptinc) areas(FR) perc(foo) clear
if (_rc != 198) {
	display as error "invalid percentile did not return error 198"
	exit 9
}

capture noisily wid, indicators(sptinc) areas(FR) perc(99p100) clear
if (_rc != 198) {
	display as error "malformed percentile did not return error 198"
	exit 9
}

capture noisily wid, indicators(sptinc) areas(FR) age(99) clear
if (_rc != 198) {
	display as error "short age code did not return error 198"
	exit 9
}

capture noisily wid, indicators(sptinc) areas(FR) age(adults) clear
if (_rc != 198) {
	display as error "nonnumeric age code did not return error 198"
	exit 9
}

capture noisily wid, indicators(sptinc) areas(FR) pop(x) clear
if (_rc != 198) {
	display as error "invalid population code did not return error 198"
	exit 9
}

// Removed extrapolation option
capture noisily wid, areas(FR) indicator(sptinc) exclude clear
if (_rc != 198) {
	display as error "removed exclude option did not return error 198"
	exit 9
}
