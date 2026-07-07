* Lag/lead patterns with _n subscripts
g nucleo=conyuh
replace nucleo=nucleo[_n-1] if e30==6 & e30[_n-1]==3
replace nucleo=nucleo[_n-1] if e30==7 & e30[_n-1]==7

* _N total count
bysort bc_correlat: gen max_nper = _N

* gen with _N in expression
bysort bc_correlat: gen share = income / _N
