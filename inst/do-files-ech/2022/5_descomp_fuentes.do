*-------------------------------------------------------------------------------
* Se re-definen variables de acuerdo a Iecon
* Asignaciones familiares
drop YTRANSF_2
gen YTRANSF_2 = 0
replace YTRANSF_2=monto_afam_cont if g256==2 			// Se incluyen las asignaciones contributivas solo si son cobradas por fuera del sueldo
replace YTRANSF_2= YTRANSF_2 + monto_afam_pe 			// Todas las asignaciones familiares - plan de equidad son cobradas por fuera del sueldo, por eso no se utiliza la restricción dada por g256==1

*Políticas sociales, ingresos por alimentación
drop DESAYMER ALMYCEN CANASTA YALIMENT YALIMENT_MEN1 YTRANSF_4 YALIMENT_MEN YTRANSF_1 YTRANSF
g DESAYMER = 0
	replace DESAYMER = (e559_1+e582_1+e582_3)*4.3*mto_desa

g ALMYCEN = 0
	replace ALMYCEN = (e559_2+e582_2)*4.3*mto_almu

g CANASTA = 0
	replace CANASTA = e247*indaceli if e246 == 7
	replace CANASTA = e247*indaemer  if e246 == 14
	replace CANASTA = g148_5_1+g148_5_2 if e246 == 11 // Otras canastas, cambió en ECH 2018

*Se genera una variable de alimentos para todos sin importar si son mayores de 14 años o no
g YALIMENT=DESAYMER + ALMYCEN + CANASTA + leche //Monto tus del iecon va para bc_tarjeta

*Variable para menores
g YALIMENT_MEN1 = 0
	replace YALIMENT_MEN1 = YALIMENT if (e27<=13)
	replace YALIMENT =0 if (e27<=13)
g YTRANSF_4 = YALIMENT
egen YALIMENT_MEN = sum(YALIMENT_MEN1), by(bc_correlat)
	replace YALIMENT_MEN=0 if bc_nper>1

*Tansferencias jubilaciones y pensiones.
g YTRANSF_1 = 0
	replace YTRANSF_1 = g148_1_1 + g148_1_2 + g148_1_3 + g148_1_5 + g148_1_6 + g148_1_7 + g148_1_8 + g148_1_9 + g148_1_12 + g148_1_10 + g148_1_11 + g148_2_1+ g148_2_2 + g148_2_3 + g148_2_5+ g148_2_6+ g148_2_7+ g148_2_8+ g148_2_9 + g148_2_12 + g148_2_10+ g148_2_11+ g148_3 + g148_4 + g148_5_1 + g148_5_2+ g153_1+ g153_2
	replace YTRANSF_1 = g148_1_1 + g148_1_2 + g148_1_3 + g148_1_5 + g148_1_6 + g148_1_7 + g148_1_8 + g148_1_9 + g148_1_12 + g148_1_10 + g148_1_11 + g148_2_1+ g148_2_2 + g148_2_3 + g148_2_5+ g148_2_6+ g148_2_7+ g148_2_8+ g148_2_9 + g148_2_12 + g148_2_10+ g148_2_11+ g148_3 + g148_4 + g153_1+ g153_2 if e246==11 	// Sacamos becas, subsidios y donaciones porque están ligadas a canasta "otras"

g YTRANSF =0
	replace YTRANSF = YTRANSF_1+YTRANSF_2+YTRANSF_3+YTRANSF_4

cap drop emerg_otrohog
g emerg_otrohog=mto_emer if e47_cv==3
recode emerg_otrohog .=0
replace emerg_otrohog=0 if bc_pe4==7
cap drop emerg_otrohog_h
egen emerg_otrohog_h=sum(emerg_otrohog), by(bc_correlat)

*- Valor locativo
cap gen loc=substr(loc_agr,3,3)
destring loc, replace

cap drop bc_pg14
gen bc_pg14=0
	replace bc_pg14=d8_3 if (d8_1!=6 & (d8_1!=5 & loc!=900))	// Código compatible
	replace bc_pg14=0 if ine_ht13==0 & d8_1!=6					// Excepción porque nosotros no podemos identificar zonas rurales en Mdeo, entonces tomamos valor de INE

gen sal_esp_net=0
	replace sal_esp_net=g129_2-bc_pg14 if d8_1==6 & g129_2!=0 // Salario en especie neto de valor locativo para ocupantes en rel. de dependencia

gen corr_sal_esp=0
	replace corr_sal_esp=-bc_pg14 if sal_esp_net>0  // Corrección para salario en especie, es el valor locativo (*-1) si esta diferencia es positiva
	replace corr_sal_esp=-g129_2 if sal_esp_net<=0	// Corrección para salario en especie, es todo el salario en especie si la dif entre valor loc y salario es negativa


* Comienza a generar variables de ingresos para los ocupados en relación de dependencia. ocupación principal
g bc_pg11p=g126_1 if bc_cat2==1 // sueldos o jornales líquidos trabajadores dependientes privados
g bc_pg21p=g126_1 if bc_cat2==2 // sueldos o jornales líquidos trabajadores dependientes públicos
g bc_pg12p=g126_2+g126_3  if bc_cat2==1 // complementos salariales privados
g bc_pg22p=g126_2+g126_3  if bc_cat2==2 // complementos salariales públicos
g bc_pg14p=g126_5 if bc_cat2==1 // aguinaldo
g bc_pg24p=g126_5 if bc_cat2==2 // aguinaldo
g bc_pg15p=g126_6 if bc_cat2==1 // salario vacacional
g bc_pg25p=g126_6 if bc_cat2==2 // salario vacacional
g bc_pg16p=g126_4 if bc_cat2==1 // propinas
g bc_pg26p=g126_4 if bc_cat2==2 // propinas

gen bc_pg17p=g126_8+g127_3+g128_1+g129_2+g130_1+(g127_1*mto_desa)+(g127_2*mto_alm) +g131_1+(g132_1*mto_vac)+(g132_2*mto_ovej)+(g132_3*mto_cab)+g133_1+(g133_2/12)+EMER_EMP_TOT +CUOT_EMP_PRIV_TOT + CUOT_EMP_IAMC_TOT+CUOT_EMP_ASSE_TOT +corr_sal_esp if bc_cat2==1 // en especie
gen bc_pg27p=g126_8+g127_3+g128_1+g129_2+g130_1+(g127_1*mto_desa)+(g127_2*mto_alm)+g131_1+(g132_1*mto_vac)+(g132_2*mto_ovej)+(g132_3*mto_cab)+g133_1+(g133_2/12)+EMER_EMP_TOT+CUOT_EMP_PRIV_TOT+CUOT_EMP_IAMC_TOT+CUOT_EMP_ASSE_TOT +corr_sal_esp if bc_cat2==2 // en especie

replace mto_hogc=0 if g149!=1 | g149_1==1   /*monto hog constituido=0 para los que no cobran o que declaran incluido en el sueldo*/

** ingresos por transferencia: asignaciones básicamente
cap drop bc_pg13p bc_pg23p bc_pg13o bc_pg23o
mvencode YTRANSF_2 g148_4 mto_hogc YTRANSF_4 , mv(0) override

gen bc_pg13p=g148_4+mto_hogc if bc_cat2==1
replace bc_pg13p=YTRANSF_2+g148_4+mto_hogc   if bc_cat2==1&(g150==1&g256!=1)&afam_pe==0
gen bc_pg23p=g148_4+mto_hogc if bc_cat2==2
replace bc_pg23p=YTRANSF_2+g148_4+mto_hogc if bc_cat2==2&(g150==1&g256!=1)&afam_pe==0

foreach var in bc_pg11p bc_pg21p bc_pg12p bc_pg22p bc_pg13p bc_pg23p bc_pg14p bc_pg24p bc_pg15p bc_pg25p bc_pg16p bc_pg26p bc_pg17p bc_pg27p {
recode `var' .=0
}

* Otras ocupaciones en relación de dependencia
capture drop bc_pg11o bc_pg12o bc_pg14o bc_pg15o bc_pg16o pg17o_cf pg17o_sf bc_pg21o bc_pg22o  bc_pg24o bc_pg25o bc_pg26o pg27o_cf pg27o_sf bc_pg13o bc_pg23o
gen bc_pg11o=g134_1 if f92==1 // sueldos o jornales líquidos trabajadores dependientes privados
gen bc_pg21o=g134_1 if f92==2 // sueldos o jornales líquidos trabajadores dependientes públicos
gen bc_pg12o=g134_2+g134_3+g139_1 if f92==1 // complementos salariales privados
gen bc_pg22o=g134_2+g134_3+g139_1  if f92==2 // complementos salariales públicos
gen bc_pg14o=g134_5 if f92==1 // aguinaldo
gen bc_pg24o=g134_5 if f92==2 // aguinaldo
gen bc_pg15o=g134_6 if f92==1 // salario vacacional
gen bc_pg25o=g134_6 if f92==2 // salario vacacional
gen bc_pg16o=g134_4 if f92==1 // propinas
gen bc_pg26o=g134_4 if f92==2 // propinas

gen bc_pg17o = g134_8+g135_3+g136_1+g137_2+g138_1+(g135_1*mto_des)+(g135_2*mto_alm)+(g140_1*mto_vac)+(g140_2*mto_ove)+(g140_3*mto_cab)+g141_1+(g141_2/12) if f92==1
replace bc_pg17o = bc_pg17o + EMER_EMP_TOT + CUOT_EMP_PRIV_TOT + CUOT_EMP_IAMC_TOT + CUOT_EMP_ASSE_TOT if f92==1 & (bc_cat2!=1 & bc_cat2!=2)

gen bc_pg27o = g134_8+g135_3+g136_1+g137_2+g138_1+(g135_1*mto_des)+(g135_2*mto_alm)+(g140_1*mto_vac)+(g140_2*mto_ove)+(g140_3*mto_cab)+g141_1+(g141_2/12) if f92==2

gen bc_pg13o=g148_4+mto_hogc if f92==1 & (bc_cat2!=4 & f73!=3 & bc_cat2!=2 & bc_cat2!=1)
replace bc_pg13o=YTRANSF_2+g148_4+mto_hogc if f92==1&(bc_cat2!=4 & f73!=3 & bc_cat2!=2 & bc_cat2!=1)&(g150==1&g256!=1)&afam_pe==0
*asignaciones de ocupación secundaria no declaradas en el sueldo

gen bc_pg23o=g148_4+mto_hogc if f92==2 & (bc_cat2!=4 & f73!=3 & bc_cat2!=2 & bc_cat2!=1)
replace bc_pg23o=YTRANSF_2+g148_4+mto_hogc  if f92==2&(bc_cat2!=4 & f73!=3 & bc_cat2!=2 & bc_cat2!=1)&(g150==1&g256!=1)&afam_pe==0
*asignaciones de ocupación secundaria no declaradas en el sueldo

foreach var in bc_pg11o bc_pg12o bc_pg14o bc_pg15o bc_pg16o bc_pg17o bc_pg17o bc_pg21o bc_pg22o  bc_pg24o bc_pg25o bc_pg26o bc_pg27o bc_pg27o bc_pg13o bc_pg23o {
recode `var' .=0
}

*total
capture drop bc_pg11t bc_pg12t bc_pg13t bc_pg14t bc_pg15t bc_pg16t bc_pg17t_cf bc_pg17t_sf
mvencode bc_pg11p bc_pg12p bc_pg13p bc_pg14p bc_pg15p bc_pg16p bc_pg17p bc_pg27p bc_pg11o bc_pg12o bc_pg13o bc_pg14o bc_pg15o bc_pg16o bc_pg17o bc_pg21o bc_pg22o bc_pg23o bc_pg24o bc_pg25o bc_pg26o bc_pg27o, mv(0) override
gen bc_pg11t=bc_pg11o+bc_pg21o
gen bc_pg12t=bc_pg12o+bc_pg22o
gen bc_pg13t=bc_pg13o+bc_pg23o
gen bc_pg14t=bc_pg14o+bc_pg24o
gen bc_pg15t=bc_pg15o+bc_pg25o
gen bc_pg16t=bc_pg16o+bc_pg26o
gen bc_pg17t=bc_pg17o+bc_pg27o // Se introduce el cambio por no descomponer fonasa por fuentes


* Ingresos laborales en ocupaciones no dependientes

* ingresos por transferencia para ocupación principal
capture drop  bc_pg32p
capture drop  bc_pg42p
capture drop  bc_pg72p
gen bc_pg32p= 0
replace bc_pg32p=g148_4+mto_hogc  if bc_pf41==5  // Cuenta propia sin local
replace bc_pg32p=YTRANSF_2+g148_4+mto_hogc if bc_pf41==5 & (g150==1&g256!=1)&afam_pe==0 // Cuenta propia sin local
gen bc_pg42p= 0
replace bc_pg42p=g148_4+mto_hogc if bc_pf41==6   // Cuenta propia con local
replace bc_pg42p=YTRANSF_2+g148_4+mto_hogc  if bc_pf41==6 & (g150==1&g256!=1)&afam_pe==0 // Cuenta propia con local
gen bc_pg72p=0
replace bc_pg72p=g148_4+mto_hogc if bc_pf41==3 // Cooperativista
replace bc_pg72p=YTRANSF_2+g148_4+mto_hogc if bc_pf41==3 & (g150==1&g256!=1)&afam_pe==0 // Cooperativista

* ingresos por transferencias ocupaciones secundarias
capture drop  bc_pg32o
capture drop  bc_pg42o
capture drop  bc_pg72o
gen bc_pg32o=-13 // a partir de 2022 no se puede distinguir cta propia con o sin local en ocupacion secundaria, por eso hago una variable nueva para cuenta propistas
gen bc_pg42o=-13
gen bc_pg92o=0
replace bc_pg92o=g148_4+mto_hogc if f92==9 & (bc_pf41!=5 & bc_pf41!=6 & bc_pf41!=3 & bc_pf41!=2 & bc_pf41!=1)
replace bc_pg92o=YTRANSF_2+g148_4+mto_hogc  if f92==9 & (g150==1&g256!=1)&(bc_pf41!=5 & bc_pf41!=6 & bc_pf41!=3 & bc_pf41!=2 & bc_pf41!=1)&afam_pe==0

gen bc_pg72o=0
replace bc_pg72o=g148_4+mto_hogc if f92==3 & (bc_cat2!=4 & f73!=3 & bc_cat2!=2 & bc_cat2!=1)
replace bc_pg72o=YTRANSF_2+g148_4+mto_hogc if f92==3 &(g150==1&g256!=1)&(bc_cat2!=4 & f73!=3 & bc_cat2!=2 & bc_cat2!=1)&afam_pe==0

* trabajador no dependiente - ingresos por negocios propios
gen bc_pg31p=g142 +((g145+g146+g147)/12) if bc_pf41==5 // Cp sin local - Dinero
gen bc_pg33p=g144_1+g144_2_1+g144_2_2+g144_2_3+g144_2_4+g144_2_5+EMER_EMP_TOT +CUOT_EMP_PRIV_TOT +CUOT_EMP_IAMC_TOT+CUOT_EMP_ASSE_TOT if bc_pf41==5  // Cp sin local - Especie
gen bc_pg41p=g142 + ((g145+g146+g147)/12) if bc_pf41==6  // Cp con local - Dinero
gen bc_pg43p=g144_1+g144_2_1+g144_2_2+g144_2_3+g144_2_4+g144_2_5+EMER_EMP_TOT +CUOT_EMP_PRIV_TOT +CUOT_EMP_IAMC_TOT+CUOT_EMP_ASSE_TOT if bc_pf41==6  // Cp con local - Especie
gen bc_pg51p=g142 + ((g145+g146+g147)/12) if bc_pf41==4  // patrón - Dinero
gen bc_pg52p=g144_1+g144_2_1+g144_2_2+g144_2_3+g144_2_4+g144_2_5+EMER_EMP_TOT +CUOT_EMP_PRIV_TOT +CUOT_EMP_IAMC_TOT+CUOT_EMP_ASSE_TOT if bc_cat2==3 // patrón - Especie
gen bc_pg71p=g142 + ((g145+g146+g147)/12) if bc_pf41==3  // cooperativista
gen bc_pg73p=g144_1+g144_2_1+g144_2_2+g144_2_3+g144_2_4+g144_2_5+EMER_EMP_TOT +CUOT_EMP_PRIV_TOT +CUOT_EMP_IAMC_TOT+CUOT_EMP_ASSE_TOT if bc_pf41==3 // cooperativista - Especie

* ocupación secundaria
gen bc_pg31o=-13
gen bc_pg33o=-13
gen bc_pg41o=-13
gen bc_pg43o=-13
gen bc_pg91o=g142 + ((g145+g146+g147)/12) if ((bc_pg31p==0|bc_pg31p==.) | (bc_pg41p==0|bc_pg41p==.)) & f92==9 & (bc_pf41!=3 & bc_pf41!=4 & bc_pf41!=5 & bc_pf41!=6)
gen bc_pg93o=g144_1+g144_2_1+g144_2_2+g144_2_3+g144_2_4+g144_2_5 if f92==9 & (bc_pf41!=3 & bc_pf41!=4 & bc_pf41!=5 & bc_pf41!=6)
gen bc_pg51o=g142 + ((g145+g146+g147)/12) if (bc_pg51p==0|bc_pg51p==.) & f92==4 & (f73!=3 & bc_cat2!=3 & bc_cat2!=4)
gen bc_pg52o=g144_1+g144_2_1+g144_2_2+g144_2_3+g144_2_4+g144_2_5 if f92==4 & (f73!=3 & bc_cat2!=3 & bc_cat2!=4)
gen bc_pg71o=g142 + ((g145+g146+g147)/12) if (bc_pg71p==0|bc_pg71p==.) & f92==3 & (f73!=3 & bc_cat2!=3 & bc_cat2!=4)
gen bc_pg73o=g144_1+g144_2_1+g144_2_2+g144_2_3+g144_2_4+g144_2_5 if f92==3 & (f73!=3 & bc_cat2!=3 & bc_cat2!=4)

* otros ingresos laborales, ocupación principal
* cambio 6/7/11. sacamos 153_24 y mto_hogc porque ya están sumados cuando se crean las variables de beneficios sociales
cap drop bc_otros_lab
gen bc_otros_lab=0
replace bc_otros_lab=g126_1+g126_2+g126_3+g126_4+g126_5+g126_6+g126_8+g127_3+g128_1+g129_2+g130_1+(g127_1*mto_des)+(g127_2*mto_alm)+(g132_1*mto_vac)+(g132_2*mto_ove)+(g132_3*mto_cab)+ g133_1+(g133_2/12)+g131_1+corr_sal_esp  if (bc_pf41!=1 & bc_pf41!=2)
replace bc_otros_lab=g142+g144_1 + ((g145+g146+g147)/12) if (bc_pf41!=3 & bc_pf41!=4 & bc_pf41!=5 & bc_pf41!=6 & f92!=3 & f92!=4 & f92!=9)
replace bc_otros_lab=g126_1+g126_2+g126_3+g126_4+g126_5+g126_6+g126_8+g127_3+g128_1+g129_2+g130_1+(g127_1*mto_des)+(g127_2*mto_alm)+(g132_1*mto_vac)+(g132_2*mto_ove)+(g132_3*mto_cab)+ g133_1+(g133_2/12) + g142+g144_1 + ((g145+g146+g147)/12) +corr_sal_esp if (bc_pf41!=1 & bc_pf41!=2) & (bc_pf41!=3 & bc_pf41!=4 & bc_pf41!=5 & bc_pf41!=6 & f92!=3 & f92!=4 & f92!=9) // Otras actividades
replace bc_otros_lab=g126_1+g126_2+g126_3+g126_4+g126_5+g126_6+g126_8+g127_3+g128_1+g129_2+g130_1+(g127_1*mto_des)+(g127_2*mto_alm)+(g132_1*mto_vac)+(g132_2*mto_ove)+(g132_3*mto_cab)+ g133_1+(g133_2/12)  + g142+g144_1 + ((g145+g146+g147)/12) + g144_2_1 + g144_2_2 + g144_2_3 + g144_2_4 + g144_2_5 + g131_1 +corr_sal_esp if bc_pf41==-9 // Monto a sin clasficación en bc_pf41

* otros ingresos laborales, otras ocupaciones
capture drop bc_otros_lab2
gen bc_otros_lab2=0
replace bc_otros_lab2=g134_1+g134_2+g134_3+g134_4+g134_5+g134_6+g134_8+g135_3+g136_1+g137_2+g138_1+(g135_1*mto_des)+(g135_2*mto_alm)+(g140_1*mto_vac)+(g140_2*mto_ove)+(g140_3*mto_cab)+g141_1+(g141_2/12)+g139_1 if (f92!=1 & f92!=2) | f92==0

capture drop bc_otros_benef
gen bc_otros_benef=0

replace bc_otros_benef=YTRANSF_4+YALIMENT_MEN1
replace bc_otros_benef=YTRANSF_4+YALIMENT_MEN1+YTRANSF_2 if afam_pe>0 // 2/6/20 cambio hay que ver si no está duplicando para bc_pf41 = 7 o 4????
replace bc_otros_benef=YTRANSF_2+g148_4+mto_hogc+YTRANSF_4+YALIMENT_MEN1 if bc_cat2!=1 & bc_cat2!=2 & f73!=3 & bc_cat2!=4 & f92!=1 & f92!=2 & f92!=3 & f92!=9

replace bc_otros_benef=YTRANSF_4+YALIMENT_MEN1
replace bc_otros_benef=YTRANSF_2+g148_4+mto_hogc+YTRANSF_4+YALIMENT_MEN1 if bc_cat2!=1 & bc_cat2!=2 & f73!=3 & bc_cat2!=4 & f92!=1 & f92!=2 & f92!=3 & f92!=9
replace bc_otros_benef=YTRANSF_4+YALIMENT_MEN1+YTRANSF_2 if (g150==1|g257>0)&(afam_pe>0) // 08/04/19 cambio
replace bc_otros_benef=g148_4+mto_hogc+YTRANSF_4+YALIMENT_MEN1 if bc_cat2!=1 & bc_cat2!=2 & f73!=3 & bc_cat2!=4 & f92!=1 & f92!=2 & f92!=3 & f92!=9 & bc_pe4==1
replace bc_otros_benef=YTRANSF_2+g148_4+mto_hogc+YTRANSF_4+YALIMENT_MEN1 if bc_cat2!=1 & bc_cat2!=2 & f73!=3 & bc_cat2!=4 & f92!=1 & f92!=2 & f92!=3 & f92!=9 & bc_pe4==1

* pagos atrasados
cap drop bc_pag_at
gen bc_pag_at=g126_7+g134_7
*-------------------------------------------------------------------------------
*- Jubilaciones

gen bc_pg911=0
replace bc_pg911 = g148_1_1+ g148_1_2+g148_1_3+g148_1_5+g148_1_6+g148_1_7+g148_1_8+g148_1_9+g148_1_10+g148_1_12 if f124_1==1
gen bc_pg921=0
replace bc_pg921=g148_1_11
gen bc_pg912=0
replace bc_pg912=g148_2_1+g148_2_2+g148_2_3+g148_2_5+g148_2_6+g148_2_7+g148_2_8+g148_2_9+g148_2_10+g148_2_12 if f124_2==1
gen bc_pg922=0
replace bc_pg922=g148_2_11
gen bc_pg91 = bc_pg911+bc_pg912
gen bc_pg92 = bc_pg921+bc_pg922


gen bc_pg101=0
	replace bc_pg101=g148_3+g148_5_1
	replace bc_pg101=g148_3 if e246==11 // Monto g148_5_1 va a canasta
gen bc_pg102=g148_5_2
	replace bc_pg102=0 if e246==11 // Monto g148_5_2 va a canasta

gen bc_pg111=0
replace bc_pg111=g153_1
replace bc_pg111= bc_pg111+emerg_otrohog_h+h155_1+h156_1 if bc_pe4==1
gen bc_pg112=0
replace bc_pg112=g153_2
replace bc_pg112 = bc_pg112+h172_1/12 if bc_pe4==1

gen bc_pg121=0
replace bc_pg121=h160_1/12+h163_1/12+h252_1+h269_1/12
gen bc_pg122=0
replace bc_pg122=h163_2/12+h160_2/12
gen bc_pg131=0
replace bc_pg131=h167_1_1/12+h167_2_1/12+h167_3_1/12+h167_4_1/12
gen bc_pg132=0
replace bc_pg132=h167_1_2/12+h167_2_2/12+h167_3_2/12+h167_4_2/12

*-------------------------------------------------------------------------------
*- Ingresos de capital

mvencode  h170_2 h170_1  h164  h166  h171_1 , mv(0) override

gen bc_pg60p=g143/12 if bc_cat2==3
gen bc_pg80p=g143/12 if f73==3
gen bc_pg60p_cpsl=g143/12 if bc_pf41==5
gen bc_pg60p_cpcl=g143/12 if bc_pf41==6

gen bc_pg60o=g143/12 if (bc_pg60p==0|bc_pg60p==.) & f92==4 & (f73!=3 & bc_cat2!=3 & bc_cat2!=4)
gen bc_pg80o=g143/12 if (bc_pg80p==0|bc_pg80p==.) & f92==3 & (f73!=3 & bc_cat2!=3 & bc_cat2!=4)
gen bc_pg60o_cpsl=-13
gen bc_pg60o_cpcl=-13
gen bc_pg60o_cp=g143/12 if ((bc_pg60p_cpsl==0|bc_pg60p_cpsl==.) | (bc_pg60p_cpcl==0|bc_pg60p_cpcl==.)) & f92==9 & (bc_pf41!=3 & bc_pf41!=4 & bc_pf41!=5 & bc_pf41!=6)

capture drop bc_otras_utilidades // Utilidades para quienes no son patrón, cooperativista o cuenta propia c/s local
gen bc_otras_utilidades=0
replace bc_otras_utilidades=g143/12 if (f73!=3&bc_cat2!=3&bc_cat2!=4&f92!=3&f92!=4&f92!=9)|(bc_cat2==-9 & f92==0)
replace bc_otras_utilidades=h170_1/12+h170_2/12+g143/12+h271_1/12 if ((f73!=3&bc_cat2!=3&bc_cat2!=4&f92!=3&f92!=4&f92!=9)|(bc_cat2==-9 & f92==0)) & bc_pe4==1

capture drop bc_ot_utilidades // Utilidades a nivel de hogar de patrón, cooperativista o cuenta propia c/s local
gen bc_ot_utilidades=0
replace bc_ot_utilidades=h170_1/12+h170_2/12+h271_1/12 if (f73==3|bc_cat2==3|bc_cat2==4|f92==3|f92==4|f92==9) & bc_pe4==1

gen bc_otras_capital=0 // Medianería, pastoreo y ganado a capitalizar a nivel de hogar
replace bc_otras_capital=(h164+h165+h166)/12 if bc_pe4==1
gen otros=0
replace otros=bc_pag_at+g154_1+g258_1/12
replace otros=(h171_1)/12+bc_pag_at+g154_1+g258_1/12  if bc_pe4==1
