* gen + replace with expression RHS (should become step_compute chain)
g bc_edu=-15
replace bc_edu=0 			if nivel_aux==0
replace bc_edu=e51_2 		if nivel_aux==1 & e51_2>=e51_3 & e51_2!=9
replace bc_edu=e51_3 		if nivel_aux==1 & e51_3>e51_2 & e51_3!=9
replace bc_edu=6+e51_4_a 	if nivel_aux==2 & e51_4_a<=3 & e51_4_a>0

* gen + replace where replace overwrites unconditionally
gen sal_esp_net=0
	replace sal_esp_net=g129_2-bc_pg14 if d8_1==6 & g129_2!=0
