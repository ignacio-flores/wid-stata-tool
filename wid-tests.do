// -------------------------------------------------------------------------- //
// Unit test for the WID Stata command
// -------------------------------------------------------------------------- //

clear all

global root "/Users/iflores/Documents/GitHub/wid-stata-tool"

cd "$root"
sysdir set PERSONAL "$root"

// -------------------------------------------------------------------------- //
// Check command that used to fail
// -------------------------------------------------------------------------- //

wid, indicators(aptinc inyixx xlcusp) perc(p0p1 p1p2 p2p3 p3p4 p4p5 p5p6 p6p7 p7p8 p8p9 p9p10 p10p11 p11p12 p12p13 p13p14 p14p15 p15p16 p16p17 p17p18 p18p19 p19p20 p20p21 p21p22 p22p23 p23p24 p24p25 p25p26 p26p27 p27p28 p28p29 p29p30 p30p31 p31p32 p32p33 p33p34 p34p35 p35p36 p36p37 p37p38 p38p39 p39p40 p40p41 p41p42 p42p43 p43p44 p44p45 p45p46 p46p47 p47p48 p48p49 p49p50 p50p51 p51p52 p52p53 p53p54 p54p55 p55p56 p56p57 p57p58 p58p59 p59p60 p60p61 p61p62 p62p63 p63p64 p64p65 p65p66 p66p67 p67p68 p68p69 p69p70 p70p71 p71p72 p72p73 p73p74 p74p75 p75p76 p76p77 p77p78 p78p79 p79p80 p80p81 p81p82 p82p83 p83p84 p84p85 p85p86 p86p87 p87p88 p88p89 p89p90 p90p91 p91p92 p92p93 p93p94 p94p95 p95p96 p96p97 p97p98 p98p99 p99p100 p0p100 p99.1p99.2 p99.2p99.3 p99.3p99.4 p99.4p99.5 p99.5p99.6 p99.6p99.7 p99.7p99.8 p99.8p99.9 p99.9p100 p0p10 p10p20 p20p30 p30p40 p40p50 p50p60 p60p70 p70p80 p80p90 p90p100)  age(992 999) pop(j i) year(1980/2020) areas(AD AT BE CH CY DE DK ES FI  FR GB GR IE IS IT LI LU MT NL NO PT SE AL AM AZ BA BG BY CZ EE GE HR HU LT LV MD ME MK PL RO RS SI SK UA US SU YU RU) clear 

// -------------------------------------------------------------------------- //
// We can download mutliple indicators for a single country
// -------------------------------------------------------------------------- //

wid, ind(sfiinc aptinc) perc(p90p100 p20p30) areas(FR) years(1990/2000) clear

assert inrange(year, 1990, 2000)
assert country == "FR"
assert inlist(percentile, "p20p30", "p90p100")
assert inlist(substr(variable, 1, 6), "aptinc", "sfiinc")

// -------------------------------------------------------------------------- //
// We can download a single indicator for multiple countries
// -------------------------------------------------------------------------- //

wid, areas(FR US) ind(sptinc) perc(p90p100) age(992) pop(j) years(1990/2000) clear

assert percentile == "p90p100"
assert inlist(country, "FR", "US")
assert inrange(year, 1990, 2000)
assert substr(variable, 10, 1) == "j"
assert substr(variable, 7, 3) == "992"
assert substr(variable, 1, 6) == "sptinc"
capture confirm variable row_score
assert _rc
capture confirm variable series_score
assert _rc
capture confirm variable quality
assert _rc
capture confirm variable data_quality
assert _rc
capture confirm variable imputation
assert _rc

// -------------------------------------------------------------------------- //
// We can download population data
// -------------------------------------------------------------------------- //

wid, area(DE) ind(npopul) clear

assert country == "DE"
assert percentile == "p0p100"
assert substr(variable, 1, 6) == "npopul"
assert inlist(substr(variable, 10, 1), "i", "f", "m")

// -------------------------------------------------------------------------- //
// We can download metadata
// -------------------------------------------------------------------------- //

wid, areas(FR) indicator(sptinc) perc(p99p100) age(992) pop(j) metadata clear

// The R-tool broader internal metadata schema is:
// variable unit unitname unitsymbol shortname shortdes technicaldes shorttype
// longtype onlinedes type_rank shortpop pop pop_rank agecode shortage age
// age_rank country countryname method source series_score
// Deliberate Stata difference: download output uses the compact schema below
// and does not materialize broader metadata fields that are not returned.
local compact_schema country countryname variable percentile year value shortname shortdes pop age source row_score series_score method
ds
assert "`r(varlist)'" == "`compact_schema'"
assert country == "FR"
assert countryname == "France"
assert variable == "sptinc992j"
assert percentile == "p99p100"
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

// -------------------------------------------------------------------------- //
// Metadata requests vary by age/pop but not by percentile
// -------------------------------------------------------------------------- //

wid, areas(FR) indicator(sptinc) perc(p90p100 p99p100) age(992 999) pop(j) metadata clear

assert inlist(variable, "sptinc992j", "sptinc999j")
assert inlist(percentile, "p90p100", "p99p100")
count if variable == "sptinc992j"
assert r(N) > 0
count if variable == "sptinc999j"
assert r(N) > 0

// -------------------------------------------------------------------------- //
// score_filter can filter row_score without public metadata
// -------------------------------------------------------------------------- //

wid, areas(FR) indicator(sptinc) perc(p99p100) age(992) pop(j) years(2010/2018) score_filter(5) clear

assert !missing(row_score) & row_score >= 5
capture confirm variable series_score
assert _rc
capture confirm variable countryname
assert _rc

// -------------------------------------------------------------------------- //
// score_filter can use series_score internally without full metadata output
// -------------------------------------------------------------------------- //

wid, areas(FR) indicator(sptinc) perc(p99p100) age(992) pop(j) years(2010/2018) score_filter(series_score=0 5) clear

capture confirm numeric variable series_score
assert !_rc
capture confirm variable countryname
assert _rc
capture confirm variable shortname
assert _rc

// -------------------------------------------------------------------------- //
// Invalid score filters fail before API requests
// -------------------------------------------------------------------------- //

capture noisily wid, areas(FR) indicator(sptinc) score_filter(row_score=6) clear
assert _rc == 198

capture noisily wid, areas(FR) indicator(sptinc) score_filter(series_score=5 3) clear
assert _rc == 198

capture noisily wid, areas(FR) indicator(sptinc) score_filter(quality=3) clear
assert _rc == 198
