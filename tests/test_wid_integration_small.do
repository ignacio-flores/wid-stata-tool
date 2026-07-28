// -------------------------------------------------------------------------- //
// Small live WID API integration tests
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

// Plain output includes row-level data quality
wid, areas(FR) indicator(sptinc) perc(p99p100) age(992) pop(j) years(2010/2012) clear

count
if (r(N) == 0) {
	display as error "plain data request returned no observations"
	exit 9
}
local base_schema country variable percentile year value age pop data_quality
ds
if ("`r(varlist)'" != "`base_schema'") {
	display as error "plain output schema differs from the expected schema"
	exit 9
}
assert country == "FR"
assert variable == "sptinc992j"
assert percentile == "p99p100"
assert inrange(year, 2010, 2012)
capture confirm numeric variable data_quality
if (_rc) {
	display as error "plain output lacks numeric data_quality"
	exit 9
}
count if !missing(data_quality)
if (r(N) == 0) {
	display as error "plain output contains no nonmissing data_quality values"
	exit 9
}
capture confirm variable avg_quality
if (!_rc) {
	display as error "plain output unexpectedly contains avg_quality"
	exit 9
}
capture confirm variable row_score
if (!_rc) {
	display as error "plain output unexpectedly contains row_score"
	exit 9
}
capture confirm variable series_score
if (!_rc) {
	display as error "plain output unexpectedly contains series_score"
	exit 9
}
capture confirm variable countryname
if (!_rc) {
	display as error "plain output unexpectedly contains metadata"
	exit 9
}
capture confirm variable quality
if (!_rc) {
	display as error "plain output unexpectedly contains legacy quality"
	exit 9
}
capture confirm variable imputation
if (!_rc) {
	display as error "plain output unexpectedly contains imputation"
	exit 9
}

tempfile plain_quality
preserve
keep country variable percentile year data_quality
rename data_quality plain_data_quality
quietly save "`plain_quality'"
restore

// Metadata output uses the compact public schema
wid, areas(FR) indicator(sptinc) perc(p99p100) age(992) pop(j) years(2010/2012) metadata clear

count
if (r(N) == 0) {
	display as error "metadata request returned no observations"
	exit 9
}
local compact_schema country countryname variable percentile year value shortname shortdes pop age source data_quality avg_quality method
ds
if ("`r(varlist)'" != "`compact_schema'") {
	display as error "metadata output schema differs from the expected schema"
	exit 9
}
assert country == "FR"
assert countryname == "France"
assert variable == "sptinc992j"
assert percentile == "p99p100"
assert inrange(year, 2010, 2012)
capture confirm numeric variable data_quality
if (_rc) {
	display as error "metadata output lacks numeric data_quality"
	exit 9
}
capture confirm numeric variable avg_quality
if (_rc) {
	display as error "metadata output lacks numeric avg_quality"
	exit 9
}
count if !missing(avg_quality)
if (r(N) == 0) {
	display as error "metadata output contains no nonmissing avg_quality values"
	exit 9
}
capture confirm variable row_score
if (!_rc) {
	display as error "metadata output unexpectedly contains row_score"
	exit 9
}
capture confirm variable series_score
if (!_rc) {
	display as error "metadata output unexpectedly contains series_score"
	exit 9
}
capture confirm variable quality
if (!_rc) {
	display as error "metadata output unexpectedly contains legacy quality"
	exit 9
}
capture confirm variable imputation
if (!_rc) {
	display as error "metadata output unexpectedly contains imputation"
	exit 9
}
foreach v in unit unitname unitsymbol technicaldes shorttype longtype onlinedes type_rank shortpop pop_rank agecode shortage age_rank {
	capture confirm variable `v'
	if (!_rc) {
		display as error "metadata output unexpectedly contains `v'"
		exit 9
	}
}

quietly merge 1:1 country variable percentile year using "`plain_quality'", assert(match) nogenerate
assert data_quality == plain_data_quality | (missing(data_quality) & missing(plain_data_quality))
drop plain_data_quality

// Metadata is percentile-invariant but still joins to every percentile row
wid, areas(FR) indicator(sptinc) perc(p90p100 p99p100) age(992) pop(j) years(2010/2012) metadata clear

count
if (r(N) == 0) {
	display as error "multi-percentile metadata request returned no observations"
	exit 9
}
assert inlist(percentile, "p90p100", "p99p100")
count if percentile == "p90p100"
if (r(N) == 0) {
	display as error "multi-percentile metadata output lacks p90p100"
	exit 9
}
count if percentile == "p99p100"
if (r(N) == 0) {
	display as error "multi-percentile metadata output lacks p99p100"
	exit 9
}
duplicates tag country variable percentile year, gen(dup)
assert dup == 0
drop dup

// Metadata requests vary by age and population, not just country + indicator
wid, areas(FR) indicator(sptinc) perc(p99p100) age(992 999) pop(j) years(2010/2012) metadata clear

count
if (r(N) == 0) {
	display as error "multi-age metadata request returned no observations"
	exit 9
}
assert inlist(variable, "sptinc992j", "sptinc999j")
count if variable == "sptinc992j"
if (r(N) == 0) {
	display as error "multi-age metadata output lacks age 992"
	exit 9
}
count if variable == "sptinc999j"
if (r(N) == 0) {
	display as error "multi-age metadata output lacks age 999"
	exit 9
}

wid, areas(FR) indicator(sptinc) perc(p99p100) age(992) pop(j i) years(2010/2012) metadata clear

count
if (r(N) == 0) {
	display as error "multi-population metadata request returned no observations"
	exit 9
}
assert inlist(substr(variable, 10, 1), "j", "i")
count if substr(variable, 10, 1) == "j"
if (r(N) == 0) {
	display as error "multi-population metadata output lacks population j"
	exit 9
}
count if substr(variable, 10, 1) == "i"
if (r(N) == 0) {
	display as error "multi-population metadata output lacks population i"
	exit 9
}

// Metadata remains country-specific in multi-country output
wid, areas(FR US) indicator(sptinc) perc(p99p100) age(992) pop(j) years(2010/2012) metadata clear

count
if (r(N) == 0) {
	display as error "multi-country metadata request returned no observations"
	exit 9
}
assert inlist(country, "FR", "US")
assert countryname == "France" if country == "FR"
count if country == "US" & countryname != ""
if (r(N) == 0) {
	display as error "multi-country metadata output lacks a US country name"
	exit 9
}
capture confirm numeric variable avg_quality
if (_rc) {
	display as error "multi-country metadata output lacks numeric avg_quality"
	exit 9
}
count if country == "FR"
if (r(N) == 0) {
	display as error "multi-country metadata output lacks France"
	exit 9
}
count if country == "US"
if (r(N) == 0) {
	display as error "multi-country metadata output lacks the United States"
	exit 9
}

// Unnamed filters apply to data_quality without exposing full metadata
wid, areas(FR) indicator(sptinc) perc(p99p100) age(992) pop(j) years(2010/2018) quality(5) clear

count
if (r(N) == 0) {
	display as error "quality() abbreviation returned no observations"
	exit 9
}
assert !missing(data_quality) & data_quality >= 5
capture confirm variable avg_quality
if (!_rc) {
	display as error "data_quality-only filtering unexpectedly exposed avg_quality"
	exit 9
}
capture confirm variable countryname
if (!_rc) {
	display as error "data_quality-only filtering unexpectedly exposed metadata"
	exit 9
}

wid, areas(FR) indicator(sptinc) perc(p99p100) age(992) pop(j) years(2010/2018) quality_filter(data_quality=5 5) clear

count
if (r(N) == 0) {
	display as error "canonical data_quality filter returned no observations"
	exit 9
}
assert !missing(data_quality) & data_quality == 5

wid, areas(FR) indicator(sptinc) perc(p99p100) age(992) pop(j) years(2010/2018) quality_filter(data_quality={min:5,max:5}) clear

count
if (r(N) == 0) {
	display as error "named data_quality bounds returned no observations"
	exit 9
}
assert !missing(data_quality) & data_quality == 5

// avg_quality filtering fetches metadata internally but does not expose full metadata
wid, areas(FR) indicator(sptinc) perc(p99p100) age(992) pop(j) years(2010/2018) quality_filter(avg_quality=0 5) clear

capture confirm numeric variable avg_quality
if (_rc) {
	display as error "avg_quality filtering did not expose numeric avg_quality"
	exit 9
}
capture confirm numeric variable data_quality
if (_rc) {
	display as error "avg_quality filtering lost numeric data_quality"
	exit 9
}
count
if (r(N) == 0) {
	display as error "avg_quality filter returned no observations"
	exit 9
}
assert !missing(avg_quality) & inrange(avg_quality, 0, 5)
capture confirm variable countryname
if (!_rc) {
	display as error "avg_quality-only filtering unexpectedly exposed countryname"
	exit 9
}
capture confirm variable shortname
if (!_rc) {
	display as error "avg_quality-only filtering unexpectedly exposed shortname"
	exit 9
}
capture confirm variable source
if (!_rc) {
	display as error "avg_quality-only filtering unexpectedly exposed source"
	exit 9
}

// Combined filters expose both scores and enforce both conditions
wid, areas(FR) indicator(sptinc) perc(p99p100) age(992) pop(j) years(2010/2018) quality_filter(data_quality=5 5; avg_quality=0 5) clear

capture confirm numeric variable data_quality
if (_rc) {
	display as error "combined filtering lost numeric data_quality"
	exit 9
}
capture confirm numeric variable avg_quality
if (_rc) {
	display as error "combined filtering did not expose numeric avg_quality"
	exit 9
}
count
if (r(N) > 0) {
	assert !missing(data_quality) & data_quality == 5
	assert !missing(avg_quality) & inrange(avg_quality, 0, 5)
}
capture confirm variable countryname
if (!_rc) {
	display as error "combined filtering unexpectedly exposed full metadata"
	exit 9
}

// An exact zero bound is valid whether or not the API currently has matches
wid, areas(FR) indicator(sptinc) perc(p99p100) age(992) pop(j) years(2010/2018) quality_filter(data_quality=0 0) clear

capture confirm numeric variable data_quality
if (_rc) {
	display as error "exact-zero filtering lost numeric data_quality"
	exit 9
}
assert !missing(data_quality) & data_quality == 0
