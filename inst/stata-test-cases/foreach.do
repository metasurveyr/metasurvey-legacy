* foreach with in list
foreach var in bc_pg11p bc_pg21p bc_pg12p bc_pg22p {
recode `var' .=0
}

* foreach with of numlist
foreach i of numlist 1/3 {
gen aux`i'=0
replace aux`i'=amount if category==`i'
}
