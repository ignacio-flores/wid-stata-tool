// -------------------------------------------------------------------------- //
// Small live WID API integration tests
// -------------------------------------------------------------------------- //

clear all
discard

if "$root" == "" {
	global root "/Users/iflores/Documents/GitHub/wid-stata-tool"
}

cd "$root"
sysdir set PERSONAL "$root"

// Plain output stays minimal
wid, areas(FR) indicator(sptinc) perc(p99p100) age(992) pop(j) years(2010/2012) clear

local base_schema country variable percentile year value age pop
ds
assert "`r(varlist)'" == "`base_schema'"
assert country == "FR"
assert variable == "sptinc992j"
assert percentile == "p99p100"
assert inrange(year, 2010, 2012)
capture confirm variable row_score
assert _rc
capture confirm variable series_score
assert _rc
capture confirm variable countryname
assert _rc
capture confirm variable quality
assert _rc
capture confirm variable data_quality
assert _rc
capture confirm variable imputation
assert _rc

// Metadata output uses the compact public schema
wid, areas(FR) indicator(sptinc) perc(p99p100) age(992) pop(j) years(2010/2012) metadata clear

local compact_schema country countryname variable percentile year value shortname shortdes pop age source row_score series_score method
ds
assert "`r(varlist)'" == "`compact_schema'"
assert country == "FR"
assert countryname == "France"
assert variable == "sptinc992j"
assert percentile == "p99p100"
assert inrange(year, 2010, 2012)
capture confirm numeric variable row_score
assert !_rc
capture confirm numeric variable series_score
assert !_rc
capture confirm variable quality
assert _rc
capture confirm variable data_quality
assert _rc
capture confirm variable imputation
assert _rc
foreach v in unit unitname unitsymbol technicaldes shorttype longtype onlinedes type_rank shortpop pop_rank agecode shortage age_rank {
	capture confirm variable `v'
	assert _rc
}

// Metadata is percentile-invariant but still joins to every percentile row
wid, areas(FR) indicator(sptinc) perc(p90p100 p99p100) age(992) pop(j) years(2010/2012) metadata clear

assert inlist(percentile, "p90p100", "p99p100")
count if percentile == "p90p100"
assert r(N) > 0
count if percentile == "p99p100"
assert r(N) > 0
duplicates tag country variable percentile year, gen(dup)
assert dup == 0
drop dup

// Metadata requests vary by age and population, not just country + indicator
wid, areas(FR) indicator(sptinc) perc(p99p100) age(992 999) pop(j) years(2010/2012) metadata clear

assert inlist(variable, "sptinc992j", "sptinc999j")
count if variable == "sptinc992j"
assert r(N) > 0
count if variable == "sptinc999j"
assert r(N) > 0

wid, areas(FR) indicator(sptinc) perc(p99p100) age(992) pop(j i) years(2010/2012) metadata clear

assert inlist(substr(variable, 10, 1), "j", "i")
count if substr(variable, 10, 1) == "j"
assert r(N) > 0
count if substr(variable, 10, 1) == "i"
assert r(N) > 0

// Metadata remains country-specific in multi-country output
wid, areas(FR US) indicator(sptinc) perc(p99p100) age(992) pop(j) years(2010/2012) metadata clear

assert inlist(country, "FR", "US")
assert countryname == "France" if country == "FR"
count if country == "US" & countryname != ""
assert r(N) > 0
capture confirm numeric variable series_score
assert !_rc
count if country == "FR"
assert r(N) > 0
count if country == "US"
assert r(N) > 0

// Row score filters expose only row_score, not full metadata
wid, areas(FR) indicator(sptinc) perc(p99p100) age(992) pop(j) years(2010/2018) score_filter(5) clear

assert !missing(row_score) & row_score >= 5
capture confirm variable series_score
assert _rc
capture confirm variable countryname
assert _rc

wid, areas(FR) indicator(sptinc) perc(p99p100) age(992) pop(j) years(2010/2018) score_filter(row_score=5 5) clear

assert !missing(row_score) & row_score == 5

wid, areas(FR) indicator(sptinc) perc(p99p100) age(992) pop(j) years(2010/2018) score_filter(row_score={min:5,max:5}) clear

assert !missing(row_score) & row_score == 5

// series_score filtering fetches metadata internally but does not expose full metadata
wid, areas(FR) indicator(sptinc) perc(p99p100) age(992) pop(j) years(2010/2018) score_filter(series_score=0 5) clear

capture confirm numeric variable series_score
assert !_rc
capture confirm variable row_score
assert _rc
capture confirm variable countryname
assert _rc
capture confirm variable shortname
assert _rc
capture confirm variable source
assert _rc

// Combined filters expose both scores and enforce both conditions
wid, areas(FR) indicator(sptinc) perc(p99p100) age(992) pop(j) years(2010/2018) score_filter(row_score=5 5; series_score=0 5) clear

capture confirm numeric variable row_score
assert !_rc
capture confirm numeric variable series_score
assert !_rc
count
if (r(N) > 0) {
	assert !missing(row_score) & row_score == 5
	assert !missing(series_score) & inrange(series_score, 0, 5)
}
capture confirm variable countryname
assert _rc

// Empty valid result is stable
wid, areas(FR) indicator(sptinc) perc(p99p100) age(992) pop(j) years(2010/2018) score_filter(row_score=0 0) clear

count
assert r(N) == 0
capture confirm numeric variable row_score
assert !_rc
