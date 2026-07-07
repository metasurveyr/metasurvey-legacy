* gen + replace sequence with constant RHS (should become step_recode)
g bc_pe4=-9
	replace bc_pe4=1 if e30==1
	replace bc_pe4=2 if e30==2
	replace bc_pe4=3 if inrange(e30,3,5)
	replace bc_pe4=4 if e30==7 | e30==8
	replace bc_pe4=5 if inrange(e30,6,12)
	replace bc_pe4=6 if e30==13
	replace bc_pe4=7 if e30==14

* simple gen without replace
g bc_pe2=e26
g bc_pe3=e27

* gen with if condition
g bc_filtloc=(region_4<3)
