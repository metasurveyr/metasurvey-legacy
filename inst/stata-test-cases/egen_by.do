* egen with by
egen bc_yciudada = sum(bc_ing_ciud), by(bc_correlat)

* bysort with egen
bysort bc_correlat: egen YALIMENT_MEN = sum(YALIMENT_MEN1)

* egen max
egen max_income = max(ht11), by(bc_correlat)
