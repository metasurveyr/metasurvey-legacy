*8_ ----------------------------------------------------------------------------
* Drop de variables auxiliares
*drop variables intermedias generadas para desagregar por fuentes
*drop cuotas_tot cuot_emp_d cuot_emp cuot_emp_tot pt2priv pt2pub pt2nodep pt1_1 emer_emp emer_emp_tot emer_emp_d ytransf_1 filtas* suma* bpc asig_jefe* asig_con* asig_otro* ytransf_2 ytransf_3 desay almuer comescol comehog canasta yaliment ytransf_4 ytransf_5 ytransf_6 pt2priv_1 pt2priv_2 pt2nodep_1 pt2nodep_2 men18 menor18 men18s cuot_otrohog_d cuot_otrohog cuot_otrohog_tot emer_otro_d emer_otro emer_otro_tot cuotmilit_otro_d cuotmilit_otro cuotmilit_otro_tot yaliment_men1 yaliment_men ht11_iecon_1 cuota_p cuota_o aux_cuotmilit seguro salud_aux ingre_ciud

*drop variables generadas para el hogar que se usan solo a los efectos de calcular ht11_nuev_cf y ht11_nuev
*drop as_privadosh as_publicosh as_otrosh as_agropech patronesh pat_agropech cpropiaslh cpropiaclh cp_agropech cooperath ot_agropech otros_labh ing_labh utilidadesh alqh interesesh ut_agropech otras_utilidadesh ot_utilidadesh otras_capitalh ing_caph jub_penh jub_peneh bs_socialesh ingre_ciudh transf_hogh beneficiosh val_loc val_loch otrh otrosh
*drop otras variables
*drop bc_cuotmilit1 bc_otros bc_otros_ing bc_benef_ocup_secund

sort bc_correlat bc_nper

rename saludh bc_salud
g bc_afam = monto_afam_pe + monto_afam_cont

bysort bc_correlat: egen bc_yciudada= sum(bc_ing_ciud)
replace bc_yciudada=0 if bc_nper!=1

g bc_yalimpan=0

*- Arreglos finales

rename yhog_iecon bc_yhog
rename cuotmilit1 bc_cuotmilit

g bc_cuotabps	= -13
g bc_disse_p	= -13
g bc_disse_o	= -13
g bc_disse		= -13

g bc_ht11_sss = bc_ht11_sss_corr*bc_ipc
g bc_ht11_css = (bc_ht11_sss_corr + bc_salud)*bc_ipc
bysort bc_correlat: gen max_nper = _N
bysort bc_correlat: gen bc_percap_iecon = bc_ht11_sss/max_nper

foreach var in bc_pg14 bc_ht11_sss bc_ht11_css bc_percap_iecon bc_ht11_sss_corr bc_salud { 	// Esto es para corregir variables a nivel de hogar
																							// que varían a nivel de personas. Se asigna el valor
																							// que toma para el jefe de hogar
bysort bc_correlat: egen `var'_aux = max(`var')
replace `var' = `var'_aux
drop `var'_aux
}


*-------------------------------------------------------------------------------
* Append servicio doméstico y sin hogar

append using "$rutainterm/servdom22", nol
sort bc_correlat bc_nper

*-------------------------------------------------------------------------------
*- Se retoman etiquetas originales de variables de ingreso de INE
*- que fueron previamente cambiadas en el paso 2.

rename ine_pt1 pt1
rename ine_pt2 pt2
rename ine_pt4 pt4
rename ine_ht13 ht13
rename ine_yhog yhog
rename ine_ysvl ysvl

*-------------------------------------------------------------------------------
* Order
order bc_correlat bc_nper bc_filtloc bc_pesoan bc_mes bc_anio bc_dpto bc_ccz bc_area bc_pe2 bc_pe3 bc_pe4 bc_pe5 bc_pe6a bc_pe6b bc_pe6a1 bc_pe11 bc_pe12 bc_pe13 bc_edu bc_edu_1 bc_finalizo bc_pobp bc_pf41 bc_cat2 bc_pf081 bc_pf082 bc_pf40 bc_rama bc_pf39 bc_tipo_ocup bc_pf07 bc_pf051 bc_pf052 bc_pf053 bc_pf06 bc_horas_sp bc_horas_sp_1 bc_horas_hab_1 bc_horas_hab_1 bc_pf04 bc_pf21 bc_pf22 bc_pf26 bc_pf34 bc_reg_disse bc_register bc_register2 bc_subocupado bc_subocupado1 bc_pg11p bc_pg12p bc_pg13p bc_pg14p  bc_pg15p bc_pg16p bc_pg17p bc_pg11o bc_pg12o bc_pg13o bc_pg14o bc_pg15o bc_pg16o bc_pg17o bc_pg21p bc_pg22p bc_pg23p bc_pg24p bc_pg25p bc_pg26p bc_pg27p bc_pg21o bc_pg22o bc_pg23o bc_pg24o bc_pg25o bc_pg26o bc_pg27o bc_pg11t bc_pg12t bc_pg13t bc_pg14t bc_pg15t bc_pg16t bc_pg17t bc_pg31p bc_pg32p bc_pg33p bc_pg31o bc_pg32o bc_pg33o bc_pg41p bc_pg42p bc_pg43p bc_pg41o bc_pg42o bc_pg43o  bc_pg91o bc_pg92o bc_pg93o bc_pg51p bc_pg52p bc_pg51o bc_pg52o bc_pg71p bc_pg72p bc_pg73p bc_pg71o bc_pg72o bc_pg73o bc_pg60p bc_pg60p_cpcl bc_pg60p_cpsl bc_pg60o bc_pg60o_cpcl bc_pg60o_cpsl bc_pg60o_cp bc_pg80p bc_pg80o bc_pg121 bc_pg122 bc_pg131 bc_pg132 bc_otras_utilidades bc_ot_utilidades bc_otras_capital bc_otros_lab bc_otros_benef bc_pag_at bc_pg91 bc_pg92 bc_pg911 bc_pg912 bc_pg921 bc_pg922 bc_pg101 bc_pg102 bc_pg111 bc_pg112 bc_pa11 bc_pa12 bc_pa13 bc_pa21 bc_pa22 bc_pa31 bc_pa32 bc_pa33 bc_pg191 bc_pg192 bc_afam afam_pe afam_cont afam_pe_hog afam_cont_hog monto_afam_pe monto_afam_cont bc_yciudada bc_yalimpan bc_yhog bc_pg14 bc_as_privados bc_as_publicos bc_as_otros bc_asalariados bc_as_agropec bc_patrones bc_pat_agropec bc_cpropiasl bc_cpropiacl bc_cp_agropec bc_cooperat bc_ot_agropec bc_principal bc_ing_lab bc_utilidades bc_alq bc_intereses bc_ut_agropec bc_ing_cap bc_jub_pen bc_jub_pene bc_tarjeta bc_bs_sociales bc_transf_hog bc_beneficios bc_ipc bc_ipc_nuevo bc_ipc_tot bc_cuotmilit bc_cuotabps bc_disse_p bc_disse_o bc_disse bc_ht11_sss bc_salud bc_ht11_css bc_percap_iecon
