gen bc_pa11 = 0
gen bc_pa12 = 0
gen bc_pa13 = 0
gen bc_pa21 = 0
gen bc_pa22 = 0
gen bc_pa31 = 0
gen bc_pa32 = 0
gen bc_pa33 = 0

* pasamos seguro de desempleo (encubierto)
* son personas que están en el seguro de paro y la ech los identifica como ocupados. suponemos que los ingresos que declaran en su ocupación principal son
* en realidad ingresos por seguro de paro

cap drop bc_seguro
cap g pf04=0
g bc_seguro=0
replace bc_seguro=(bc_pg11p+bc_pg12p+bc_pg14p+bc_pg15p+bc_pg16p+bc_pg17p+bc_pg71p+bc_pg73p+bc_pg71o+bc_pg73o)*bc_ipc if bc_pobp==2 & pf04==7 & (bc_pg101==0 | bc_pg101!=.) // & bc_anio<2001
recode bc_seguro .=0
*-------------------------------------------------------------------------------
*Ingresos laborales

*Asalariados

*Asalariados privados ocupación principal
cap drop bc_as_privados
g bc_as_privados=(bc_pg11p+bc_pg12p+bc_pg14p+bc_pg15p+bc_pg16p+bc_pg17p)*bc_ipc
replace bc_as_privados=(bc_as_privados-bc_seguro) if bc_as_privados>0 & bc_pf41==1
cap drop as_privadosh
egen as_privadosh=sum(bc_as_privados) if bc_pe4!=7 , by(bc_correlat)

*Asalariados públicos ocupación principal
cap drop bc_as_publicos
gen bc_as_publicos=(bc_pg21p+bc_pg22p+bc_pg24p+bc_pg25p+bc_pg26p+bc_pg27p)*bc_ipc
cap drop as_publicosh
egen as_publicosh=sum(bc_as_publicos) if bc_pe4!=7 , by(bc_correlat)

*Asalariados (ocup. secundaria)
cap drop bc_as_otros
gen bc_as_otros=(bc_pg11t+bc_pg12t+bc_pg14t+bc_pg15t+bc_pg16t+bc_pg17t)*bc_ipc
cap drop as_otrosh
egen as_otrosh=sum(bc_as_otros) if bc_pe4!=7, by(bc_correlat)

** Asalariados total ocupaciones
cap drop bc_asalariados
gen bc_asalariados=(bc_pg11p+bc_pg12p+bc_pg14p+bc_pg15p+bc_pg16p+bc_pg17p+bc_pg21p+bc_pg22p+bc_pg24p+bc_pg25p+bc_pg26p+bc_pg27p+bc_pg11t+bc_pg12t+bc_pg14t+bc_pg15t+bc_pg16t+bc_pg17t)*bc_ipc

*Asalariados agropec
cap drop bc_as_agropec
gen bc_as_agropec= 0
cap g cat2=0
replace bc_as_agropec=(bc_pa11 +bc_pa12+ bc_pa13+ bc_pa21+ bc_pa22+ bc_pa31+ bc_pa32)*bc_ipc if bc_anio<1991 & bc_anio>1987 & (cat2==1|cat2==2)
replace bc_as_agropec=((bc_pa11 +bc_pa12+ bc_pa13+ bc_pa21+ bc_pa22+ bc_pa31+ bc_pa32)/1000)*bc_ipc if bc_anio<1988 & (cat2==1|cat2==2)
cap drop as_agropech
egen as_agropech=sum(bc_as_agropec) if bc_pe4!=7, by(bc_correlat)

*-------------------------------------------------------------------------------
*Trabajadores independientes

mvencode bc_pg13p bc_pg23p bc_pg32p bc_pg42p bc_pg72p , mv(0) override
mvencode bc_pg51p bc_pg52p bc_pg31p bc_pg33p bc_pg41p bc_pg43p bc_pg71p bc_pg73p bc_pg60p bc_pg80p bc_pg60p_cpsl bc_pg60p_cpcl bc_pg121 bc_pg122 bc_pg131 bc_pg132, mv(0) override
mvencode bc_pg51o bc_pg52o bc_pg91o bc_pg93o bc_pg71o bc_pg73o bc_pg60o bc_pg80o bc_pg60o_cp, mv(0) override

*bc_patrones
cap drop bc_patrones
gen bc_patrones=0
replace bc_patrones=(bc_pg51p+bc_pg52p+bc_pg51o+bc_pg52o)*bc_ipc
cap drop patronesh
egen patronesh=sum(bc_patrones) if bc_pe4!=7, by(bc_correlat)

*patrones agropec
cap drop bc_pat_agropec
gen bc_pat_agropec= 0
replace bc_pat_agropec=(bc_pa11 +bc_pa12+ bc_pa13+ bc_pa21+ bc_pa22+ bc_pa31+ bc_pa32)*bc_ipc if bc_anio<1991 & bc_anio>1987 & cat2==4
replace bc_pat_agropec=((bc_pa11 +bc_pa12+ bc_pa13+ bc_pa21+ bc_pa22+ bc_pa31+ bc_pa32)/1000)*bc_ipc if bc_anio<1988 & cat2==4
cap drop pat_agropech
egen pat_agropech=sum(bc_pat_agropec) if bc_pe4!=7, by(bc_correlat)

* Las siguientes lineas no se pueden hacer porque las variables bc_pg31o bc_pg33o y bc_pg41o bc_pg43o no se pueden hacer - no tenemos cómo distinguir con y sin local en la ocupación secundaria

/*cuenta propistas sin local
cap drop bc_cpropiasl
gen bc_cpropiasl=0
replace bc_cpropiasl=(bc_pg31p+bc_pg33p+bc_pg31o+bc_pg33o)*bc_ipc
cap drop cpropiaslh
egen cpropiaslh=sum(bc_cpropiasl) if bc_pe4!=7, by(bc_correlat)

*cuenta propistas con local
cap drop bc_cpropiacl
gen bc_cpropiacl=0
replace bc_cpropiacl=(bc_pg41p+bc_pg43p+bc_pg41o+bc_pg43o)*bc_ipc
cap drop cpropiaclh
egen cpropiaclh=sum(bc_cpropiacl) if bc_pe4!=7, by(bc_correlat)


gen bc_cpropiasl=-13
g cpropiaslh=-13
gen bc_cpropiacl=-13
g cpropiaclh=-13
*/

* opción: poner los ingresos de ocupación principal cl o sl y los ingresos de oc secundaria cl y sl mezclado
cap drop bc_cpropiasl
gen bc_cpropiasl=0
replace bc_cpropiasl=(bc_pg31p+bc_pg33p+bc_pg91o+bc_pg93o)*bc_ipc
cap drop cpropiaslh
egen cpropiaslh=sum(bc_cpropiasl) if bc_pe4!=7, by(bc_correlat)

*cuenta propistas con local
cap drop bc_cpropiacl
gen bc_cpropiacl=0
replace bc_cpropiacl=(bc_pg41p+bc_pg43p+bc_pg91o+bc_pg93o)*bc_ipc
cap drop cpropiaclh
egen cpropiaclh=sum(bc_cpropiacl) if bc_pe4!=7, by(bc_correlat)

*Cuenta propista agropec
cap drop bc_cp_agropec
gen bc_cp_agropec= 0
replace bc_cp_agropec=(bc_pa11 +bc_pa12+ bc_pa13+ bc_pa21+ bc_pa22+ bc_pa31+ bc_pa32)*bc_ipc if bc_anio<1991 & bc_anio>1987 & cat2==6
replace bc_cp_agropec=((bc_pa11 +bc_pa12+ bc_pa13+ bc_pa21+ bc_pa22+ bc_pa31+ bc_pa32)/1000)*bc_ipc if bc_anio<1988 & cat2==6
cap drop cp_agropech
egen cp_agropech=sum(bc_cp_agropec) if bc_pe4!=7, by(bc_correlat)

*cooperativas
cap drop bc_cooperat
gen bc_cooperat=0
replace bc_cooperat=(bc_pg71p+bc_pg73p+bc_pg71o+bc_pg73o)*bc_ipc
replace bc_cooperat=bc_cooperat-bc_seguro if bc_cooperat>0 & bc_pf41==3
cap drop cooperath
egen cooperath=sum(bc_cooperat) if bc_pe4!=7, by(bc_correlat)

*otros ingresos laborales agropecuarios
cap drop bc_ot_agropec
gen bc_ot_agropec= 0
replace bc_ot_agropec=(bc_pa11 +bc_pa12+ bc_pa13+ bc_pa21+ bc_pa22+ bc_pa31+ bc_pa32)*bc_ipc if bc_anio<1991 & bc_anio>1987 & cat2==9
replace bc_ot_agropec=((bc_pa11 +bc_pa12+ bc_pa13+ bc_pa21+ bc_pa22+ bc_pa31+ bc_pa32)/1000)*bc_ipc if bc_anio<1988 & cat2==9
cap drop ot_agropech
egen ot_agropech=sum(bc_ot_agropec) if bc_pe4!=7, by(bc_correlat)

*otros ingresos laborales ya generados
capture gen bc_otros_lab=0
capture gen bc_otros_lab2=0
cap drop otros_labh
egen otros_labh=sum(bc_otros_lab) if bc_pe4!=7, by(bc_correlat)
cap drop otros_lab2h
egen otros_lab2h=sum(bc_otros_lab2) if bc_pe4!=7, by(bc_correlat)

mvencode bc_as_privados  bc_as_publicos  bc_cpropiasl bc_cpropiacl bc_patrones  bc_cooperat bc_otros_lab bc_otros_lab2 bc_as_otros bc_ot_agropec bc_as_agropec bc_cp_agropec bc_pat_agropec, mv(0) override

** Total ingresos laborales ocupación principal
cap drop bc_principal
g bc_principal=bc_as_privados+bc_as_publicos
replace bc_principal=bc_patrones+bc_cpropiasl+bc_cpropiacl+bc_cooperat if bc_pf41>2 & bc_pf41<7

capture drop bc_ing_lab
gen bc_ing_lab=0
replace bc_ing_lab= bc_as_privados+ bc_as_publicos+ bc_patrones+ bc_cpropiasl+ bc_cpropiacl+ bc_cooperat +bc_as_otros+bc_as_agropec+bc_cp_agropec+ /*
*/ bc_pat_agropec+bc_ot_agropec+(bc_otros_lab+bc_otros_lab2)*bc_ipc

cap drop ing_labh
egen ing_labh=sum(bc_ing_lab) if bc_pe4!=7, by(bc_correlat)

*-------------------------------------------------------------------------------
* Ingresos no laborales

* Ingreso de capital

cap drop bc_utilidades
gen bc_utilidades=(bc_pg60p+bc_pg80p+bc_pg60o+bc_pg80o+bc_pg60p_cpsl+bc_pg60p_cpcl+bc_pg60o_cp)*bc_ipc
cap drop utilidadesh
egen utilidadesh=sum(bc_utilidades) if bc_pe4!=7, by(bc_correlat)

cap drop bc_alq /*Es una variable a nivel de hogar*/
gen bc_alq=(bc_pg121+bc_pg122)*bc_ipc
cap drop alqh
gen alqh=bc_alq

cap drop bc_intereses /*Es una variable a nivel de hogar*/
gen bc_intereses=(bc_pg131+bc_pg132)*bc_ipc
cap drop interesesh
gen interesesh=bc_intereses

* Utilidades de agropecuarios
cap drop bc_ut_agropec
gen bc_ut_agropec= 0
replace bc_ut_agropec=(bc_pa33)*bc_ipc if bc_anio<1991 & bc_anio>1987
replace bc_ut_agropec=((bc_pa33)/1000)*bc_ipc if bc_anio<1988
cap drop ut_agropech
egen ut_agropech=sum(bc_ut_agropec)if bc_pe4!=7, by(bc_correlat)

* Otros ingresos de capital
replace bc_otras_utilidades	=bc_otras_utilidades*bc_ipc
replace bc_ot_utilidades	=bc_ot_utilidades*bc_ipc
replace bc_otras_capital	=bc_otras_capital*bc_ipc

capture gen bc_pg91=0
capture gen bc_pg91=bc_pg91

mvencode bc_utilidades bc_alq bc_intereses bc_otras_utilidades bc_otras_capital bc_ut_agropec bc_pg91 bc_pg92, mv(0) override

cap drop bc_ing_cap
gen bc_ing_cap=0
replace bc_ing_cap=(bc_utilidades+bc_alq+bc_intereses+bc_ut_agropec+bc_otras_utilidades+bc_otras_capital+bc_ot_utilidades)
cap drop ing_caph
by bc_correlat: egen ing_caph=sum(bc_utilidades+bc_ut_agropec+bc_otras_utilidades+bc_otras_capital+bc_ot_utilidades)
replace ing_caph=ing_caph+bc_alq+bc_intereses

*-------------------------------------------------------------------------------
* Transferencias
* Jubilaciones y pensiones

cap drop bc_jub_pen
gen bc_jub_pen=(bc_pg91)
cap drop jub_penh
egen jub_penh=sum(bc_jub_pen) if bc_pe4!=7, by(bc_correlat)
cap drop bc_jub_pene
gen bc_jub_pene=(bc_pg92) // exterior
cap drop jub_peneh
egen jub_peneh=sum(bc_jub_pene) if bc_pe4!=7, by(bc_correlat)

*beneficios sociales

capture gen bc_pg32p=0
capture gen bc_pg42p=0
capture gen bc_pg72p=0
capture gen bc_otros_benef=0
cap g bc_tarjeta=monto_tus_iecon

cap g bc_pg13o=0

cap g bc_pg23o=0
cap drop benef_ocup_secund
g benef_ocup_secund=0
replace benef_ocup_secund=bc_pg13t if bc_anio<1991
replace benef_ocup_secund=bc_pg13o+bc_pg23o+bc_pg92o+bc_pg72o if bc_anio>1990


mvencode bc_pg32p bc_pg42p bc_pg72p bc_pg13p bc_pg23p bc_pg101 bc_pg102 bc_jub_pen bc_jub_pene bc_otros_benef bc_pg111 bc_pg112 bc_pg14, mv(0) override
* le agregamos los beneficios de la ocupación secundaria
cap drop bc_bs_sociales
gen bc_bs_sociales=(bc_pg13p+bc_pg23p+bc_pg32p+bc_pg42p+bc_pg72p+bc_otros_benef+ bc_pg101+ bc_pg102+benef_ocup_secund+bc_seguro+bc_tarjeta)
cap drop bs_socialesh
egen bs_socialesh=sum(bc_bs_sociales) if bc_pe4!=7, by(bc_correlat)

*variables de beneficios sociales que no figuran todos los años
capture gen bc_ing_ciud=0
cap drop ingre_ciud
gen ingre_ciud=(bc_ing_ciud)
cap drop ingre_ciudh
egen ingre_ciudh=sum(ingre_ciud) if bc_pe4!=7, by(bc_correlat)

* antes se llamaba otr_ben, le cambiamos el nombre para no confundir
cap drop bc_transf_hog
gen bc_transf_hog=0
replace bc_transf_hog=(bc_pg111+bc_pg112) // transferencias entre hogares
cap drop transf_hogh
egen transf_hogh=sum(bc_transf_hog) if bc_pe4!=7, by(bc_correlat)

cap drop bc_beneficios
gen bc_beneficios=ingre_ciud+bc_bs_sociales
cap drop beneficiosh
gen beneficiosh=ingre_ciudh+bs_socialesh

*valor locativo
cap drop val_loc
gen val_loc=0
replace val_loc=(bc_pg14) if bc_pe4==1
cap drop val_loch
egen val_loch=sum(val_loc) if bc_pe4!=7, by(bc_correlat)


*otros ingresos
capture gen bc_pg191=0
capture gen bc_pg192=0

mvencode bc_pg191 bc_pg192, mv(0) override
capture gen otros=0
cap gen otros_ing=0
replace otros=(bc_pg191+bc_pg192)/1000 if bc_anio<1988
replace otros=(bc_pg191+bc_pg192) if bc_anio>1987 & bc_anio<1991
cap drop otros_ing
g otros_ing=otros
cap drop otrh
egen otrh=sum(otros_ing) if bc_pe4!=7, by(bc_correlat)
cap drop otrosh
gen otrosh=otrh

mvencode ing_labh ing_caph bs_socialesh jub_penh jub_peneh beneficiosh ht11  val_loch  otrosh bc_transf_hog transf_hogh, mv(0) override
* Las variables ing_labh, ing_caph están en términos reales
gen bc_ht11_sss_corr=0

replace bc_ht11_sss_corr=((ing_labh+ing_caph+cuota_otrohog_h)/bc_ipc +beneficiosh+jub_penh+jub_peneh+ val_loch+otrosh+transf_hogh) if bc_pe4==1
order ht11, before(bc_ht11_sss_corr)
order saludh, before(bc_ht11_sss_corr)
