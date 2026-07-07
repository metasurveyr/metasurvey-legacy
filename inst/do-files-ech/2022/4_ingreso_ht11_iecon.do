
************************* SALUD MILITAR *************************
* Quienes tienen derecho en sanidad militar a traves de un miembro de este hogar y a su vez no generan derecho por FONASA ya sea por miembro del hogar o por otro hogar.
g at_milit=0
replace at_milit=1 if e45_4_1_cv==1

*Quienes tienen derecho a atencion militar y no tienen FONASA ya sea por miembro del hogar o por otro hogar.
g at_milit2=0
replace at_milit2=1 if e45_cv==4

*Se hace un agregado en la base con la suma de la variable anterior
egen cuotmilit1=sum(at_milit), by(bc_correlat e45_4_1_1_cv)

*A los que no son generadores del derecho les adjudico un cero, por lo cual no considero a quienes tiene el derecho por un miembro de otro hogar.
g ramamilit_op=0
replace ramamilit_op=1 if inlist(f72_2,5222,5223,8030,8411,8421,8422,8423,8430,8521,8530,8610)

g cuotmilit_op=0
replace cuotmilit_op=cuotmilit1 if bc_nper==e45_4_1_1_cv & ramamilit_op==1

g ytdop_2=0
replace ytdop_2=cuotmilit_op*mto_cuota

*Cuota militar ocupacion secundaria
g ramamilit_os=0
replace ramamilit_os=1 if inlist(f91_2,5222,5223,8030,8411,8421,8422,8423,8430,8521,8530,8610)

g cuotmilit_os=0
replace cuotmilit_os=cuotmilit1 if bc_nper==e45_4_1_1_cv & ramamilit_os==1
replace cuotmilit_os=0 if cuotmilit_op>0

g ytdos_2=0
replace ytdos_2=cuotmilit_os*mto_cuota

*Se suman todas las cuotas de ocupacion principal, ocupacion secundaria y las totales sin derecho a FONASA a la vez.
egen cuotmilit2 = sum(at_milit2) , by(bc_correlat)
egen tot_cuotmilit_op=sum(cuotmilit_op), by(bc_correlat)
egen tot_cuotmilit_os=sum(cuotmilit_os), by(bc_correlat)

* Defino cuantas cuotas hay que sumarle al hogar, por no captarlas por ocupacion principal u ocupacion secundaria y las cuotas se las asigno al jefe de hogar.
g cuotmilit_hogar=0
replace cuotmilit_hogar=(cuotmilit2-(tot_cuotmilit_op+tot_cuotmilit_os))*mto_cuota if bc_nper==1


************************* FONASA *************************
* FONASA trabajador ocupacion principal
g ytdop_3=0
replace ytdop_3=mto_cuot if (((e27>=14) & (f73<3 | f73==7 | f73==8) & f82==1) & (e45_1_1_cv==1| e45_2_1_cv==1 | e45_3_1_cv==1))

*FONASA trabajador ocupación secundaria.
gen ytdos_3=0
replace ytdos_3=mto_cuot if (((e27>=14 & (f92<3 | f92==7 | f92==8) & ytdop_2==0 & ytdop_3==0) & f96==1) & (e45_1_1_cv==1| e45_2_1_cv==1 | e45_3_1_cv==1))

* FONASA trabajador independiente
* Toma en cuenta la posibilidad de que el trabajo independiente sea principal o secundario
gen YTINDE_2 = 0
replace YTINDE_2=mto_cuot if ((e27>=14 & ((f73==3 | f73==4 | f73==9) & f82==1) | e27>=14 & ((f92==3 | f92==4 | f92==9) & f96==1)) & (e45_1_1_cv==1 | e45_2_1_cv==1 | e45_3_1_cv==1) & ytdop_3==0 & ytdos_3==0 & ytdop_2==0 & ytdos_2==0)

* FONASA para todos quienes generan derecho por FONASA y no son adjudicables al trabajo
g tienefonasaHOG=0
replace tienefonasaHOG=1 if (e45_1_1_cv==1 | e45_1_1_cv==4 | e45_2_1_cv==1 | e45_2_1_cv==6 | e45_3_1_cv==1 | e45_3_1_cv==6) & ytdop_3 ==0 & ytdos_3==0 & YTINDE_2==0
egen totfonasa_hogar = sum(tienefonasaHOG), by(bc_correlat)

* Solo FONASA adjudicables al hogar
replace totfonasa_hogar=0 if bc_nper!=1
replace totfonasa_hogar=totfonasa_hogar*mto_cuota

* Cuota mutual paga por el empleador de algun miembro del hogar
* Para todas las cuotas pagas por el empleador uso la condicion de que no tengan atencion de salud ni por MSP, seguro privado y Hospital Militar
gen CUOT_EMP_IAMC1 =0
replace CUOT_EMP_IAMC1=1 if e45_2_1_cv==5

egen CUOT_EMP_IAMC = sum(CUOT_EMP_IAMC1), by (bc_correlat e45_2_1_1_cv)

foreach i of num 1/14 {
	generate aux`i'=0
	replace aux`i'=CUOT_EMP_IAMC if e45_2_1_1_cv==`i'
}
foreach i of num 1/14 {
	egen aux`i'_max = max(aux`i'), by(bc_correlat)
}
gen	 CuotasGeneradas=0
replace  CuotasGeneradas  = aux1_max  if bc_nper==1
replace  CuotasGeneradas  = aux2_max  if bc_nper==2
replace  CuotasGeneradas  = aux3_max  if bc_nper==3
replace  CuotasGeneradas  = aux4_max  if bc_nper==4
replace  CuotasGeneradas  = aux5_max  if bc_nper==5
replace  CuotasGeneradas  = aux6_max  if bc_nper==6
replace  CuotasGeneradas  = aux7_max  if bc_nper==7
replace  CuotasGeneradas  = aux8_max  if bc_nper==8
replace  CuotasGeneradas  = aux9_max  if bc_nper==9
replace  CuotasGeneradas  = aux10_max if bc_nper==10
replace  CuotasGeneradas  = aux11_max if bc_nper==11
replace  CuotasGeneradas  = aux12_max if bc_nper==12
replace  CuotasGeneradas  = aux13_max if bc_nper==13
replace  CuotasGeneradas  = aux14_max if bc_nper==14

g CUOT_EMP_IAMC_TOT=0
replace CUOT_EMP_IAMC_TOT=CuotasGeneradas*mto_cuot
drop aux1-aux14_max

* Cuota seguro privado paga por el empleador
gen CUOT_EMP_PRIV1=0
replace CUOT_EMP_PRIV1=1 if e45_3_1_cv==5

egen CUOT_EMP_PRIV = sum(CUOT_EMP_PRIV1), by (bc_correlat e45_3_1_1_cv)

foreach i of num 1/14 {
	generate aux`i'=0
	replace aux`i'=CUOT_EMP_PRIV if e45_3_1_1_cv==`i'
}
foreach i of num 1/14 {
	egen aux`i'_max = max(aux`i'), by(bc_correlat)
}

gen CuotasGeneradas2=0
replace CuotasGeneradas2  = aux1_max  if bc_nper==1
replace CuotasGeneradas2  = aux2_max  if bc_nper==2
replace CuotasGeneradas2  = aux3_max  if bc_nper==3
replace CuotasGeneradas2  = aux4_max  if bc_nper==4
replace CuotasGeneradas2  = aux5_max  if bc_nper==5
replace CuotasGeneradas2  = aux6_max  if bc_nper==6
replace CuotasGeneradas2  = aux7_max  if bc_nper==7
replace CuotasGeneradas2  = aux8_max  if bc_nper==8
replace CuotasGeneradas2  = aux9_max  if bc_nper==9
replace CuotasGeneradas2  = aux10_max if bc_nper==10
replace CuotasGeneradas2  = aux11_max if bc_nper==11
replace CuotasGeneradas2  = aux12_max if bc_nper==12
replace CuotasGeneradas2  = aux13_max if bc_nper==13
replace CuotasGeneradas2  = aux14_max if bc_nper==14

gen CUOT_EMP_PRIV_TOT=0
replace CUOT_EMP_PRIV_TOT = CuotasGeneradas2*mto_cuot
drop aux1-aux14_max

* Cuota mutual para por empleador total, suma de la mutualista y seguro privado de salud
gen CUOT_EMP_TOT = CUOT_EMP_PRIV_TOT + CUOT_EMP_IAMC_TOT

* Cuota ASSE paga por el empleador por actividad principal
gen CUOT_EMP_ASSE1 =0
replace CUOT_EMP_ASSE1=1 if e45_1_1_cv==5

egen CUOT_EMP_ASSE = sum(CUOT_EMP_ASSE1), by (bc_correlat e45_1_1_1_cv)

foreach i of num 1/14 {
	generate aux`i'=0
	replace aux`i'=CUOT_EMP_ASSE if e45_1_1_1==`i'
}
foreach i of num 1/14 {
	egen aux`i'_max = max(aux`i'), by(bc_correlat)
}
gen CuotasGeneradas3=0
replace CuotasGeneradas3 = aux1_max if bc_nper==1
replace CuotasGeneradas3 = aux2_max if bc_nper==2
replace CuotasGeneradas3 = aux3_max if bc_nper==3
replace CuotasGeneradas3 = aux4_max if bc_nper==4
replace CuotasGeneradas3 = aux5_max if bc_nper==5
replace CuotasGeneradas3 = aux6_max if bc_nper==6
replace CuotasGeneradas3 = aux7_max if bc_nper==7
replace CuotasGeneradas3 = aux8_max if bc_nper==8
replace CuotasGeneradas3 = aux9_max if bc_nper==9
replace CuotasGeneradas3 = aux10_max if bc_nper==10
replace CuotasGeneradas3 = aux11_max if bc_nper==11
replace CuotasGeneradas3 = aux12_max if bc_nper==12
replace CuotasGeneradas3 = aux13_max if bc_nper==13
replace CuotasGeneradas3 = aux14_max if bc_nper==14

gen CUOT_EMP_ASSE_TOT=0
replace CUOT_EMP_ASSE_TOT = CuotasGeneradas3*mto_cuot
drop aux1-aux14_max


************************* EMERGENCIA MOVIL *************************
* Paga por el empleador
gen EMER_EMP=0
replace EMER_EMP=1 if e47_cv==4
egen EMER_EMP2 = sum(EMER_EMP), by (bc_correlat e47_1_cv)

foreach i of num 1/14 {
	gen aux`i'=0
	replace aux`i'=EMER_EMP2 if e47_1==`i'
}
foreach i of num 1/14 {
	egen aux`i'_max = max(aux`i'), by(bc_correlat)
}

gen	emergeneradas = aux1_max if bc_nper==1
replace emergeneradas = aux2_max if bc_nper==2
replace emergeneradas = aux3_max if bc_nper==3
replace emergeneradas = aux4_max if bc_nper==4
replace emergeneradas = aux5_max if bc_nper==5
replace emergeneradas = aux6_max if bc_nper==6
replace emergeneradas = aux7_max if bc_nper==7
replace emergeneradas = aux8_max if bc_nper==8
replace emergeneradas = aux9_max if bc_nper==9
replace emergeneradas = aux10_max if bc_nper==10
replace emergeneradas = aux11_max if bc_nper==11
replace emergeneradas = aux12_max if bc_nper==12
replace emergeneradas = aux13_max if bc_nper==13
replace emergeneradas = aux14_max if bc_nper==14
recode  emergeneradas .=0

gen EMER_EMP_TOT=0
replace EMER_EMP_TOT = emergeneradas*mto_emer
drop aux1-aux14_max

** Paga por otro hogar
gen EMER_OTRO=0
replace EMER_OTRO=1 if e47_cv==3
egen EMER_OTRO2 = sum(EMER_OTRO), by (bc_correlat)
replace EMER_OTRO2=0 if bc_nper!=1
gen EMER_OTRO_TOT = EMER_OTRO2*mto_emer


************************* INGRESOS POR TRABAJO *************************
* Ingresos por trabajo: ocupacion principal dependiente
g ytdop_1=g126_1+g126_2+g126_3+g126_4+g126_5+g126_6+g126_7+g126_8+(g127_1*mto_desa)+(g127_2*mto_almu)+g127_3+g128_1+g129_2+g130_1+g131_1+(g132_1*mto_vaca)+(g132_2*mto_ovej)+(g132_3*mto_caba)+g133_1+(g133_2/12)

g  YTDOP =  ytdop_1 + ytdop_2 + ytdop_3 + CUOT_EMP_TOT + EMER_EMP_TOT + CUOT_EMP_ASSE_TOT

* Ingresos por trabajo: ocupacion secundaria dependiente
g ytdos_1 = g134_1+g134_2+g134_3+g134_4+g134_5+g134_6+g134_7+g134_8+(g135_1*mto_desa)+(g135_2*mto_almu)+g135_3+g136_1 + g137_2+g138_1+g139_1+(g140_1*mto_vaca)+(g140_2*mto_ovej)+(g140_3*mto_caba)+g141_1+(g141_2/12)

g  YTDOS =  ytdos_1 + ytdos_2 + ytdos_3 // ver missings en ytdos_2

* Ingresos por trabajo: ocupacion independiente
replace g144_1="0" if g144_1=="NA"
destring g144_1, replace
g YTINDE_1 = g142 + (g143/12) + g144_1 + g144_2_1 + g144_2_2  + g144_2_3 + g144_2_4 + g144_2_5 + (g145/12) + (g146/12) + (g147/12)
g YTINDE = YTINDE_1 + YTINDE_2


************************* ASIGNACIONES Y HOGAR CONSTITUIDO *************************
* Asignaciones
destring g261 g261_1, force replace
recode g261 g261_1 (.=0)
g YTRANSF_2=0
replace YTRANSF_2= g257 if g256!=1
replace YTRANSF_2= YTRANSF_2+g261_1 if g256==2 & g261==2

* Hogar constituido
g YTRANSF_3=0
replace YTRANSF_3=mto_hogc if (g149==1 & g149_1==2)


************************* TRANSFERENCIAS *************************
* Politicas sociales: ingresos por alimentacion
g DESAYMER = 0
	replace DESAYMER = (e559_1+e582_1+e582_3)*4.3*mto_desa
g ALMYCEN = 0
	replace ALMYCEN = (e559_2+e582_2)*4.3*mto_almu
g CANASTA = 0
	replace CANASTA = e247*indaceli if e246 == 7
	replace CANASTA = e247*indaemer if e246 == 14

* Tarjetas TUS-MIDES y TUS-INDA
g tusmides = e560_1_1
g tusinda = e560_2_1
g tus = tusmides + tusinda

* Genero variable "LECHE"
g leche = e561_1*lecheenpol

* Creo una variable de alimentos para todos sin importar si son mayores de 14 años o no
g YALIMENT=DESAYMER + ALMYCEN + tus + CANASTA + leche

*Variable para menores
g YALIMENT_MEN1 = 0
	replace YALIMENT_MEN1 = YALIMENT if (e27<=13)
	replace YALIMENT =0 if (e27<=13)

* Esta es la variable para agregar por alimentacion en personas
g YTRANSF_4 = YALIMENT
egen YALIMENT_MEN = sum(YALIMENT_MEN1), by(bc_correlat)

* Esta es la variable de alimentacin para agregar a hogares
replace YALIMENT_MEN=0 if bc_nper>1

* Transferencias: jubilaciones y pensiones
g YTRANSF_1 = 0
	replace YTRANSF_1 = g148_1_1 + g148_1_2 + g148_1_3 + g148_1_5 + g148_1_6 + g148_1_7 + g148_1_8 + g148_1_9 + g148_1_12 + g148_1_10 + g148_1_11 + g148_2_1+ g148_2_2 + g148_2_3 + g148_2_5+ g148_2_6+ g148_2_7+ g148_2_8+ g148_2_9 + g148_2_12 + g148_2_10+ g148_2_11+ g148_3 + g148_4 + g148_5_1 + g148_5_2+ g153_1+ g153_2

g YTRANSF=0
	replace YTRANSF = YTRANSF_1+YTRANSF_2+YTRANSF_3+YTRANSF_4

*Transferencias imputables al hogar
*Cuota para otro hogar
g CUOT_OTROHOG=0
replace CUOT_OTROHOG=mto_cuota if e45_1_1_cv==6
replace CUOT_OTROHOG=mto_cuota if e45_2_1_cv==3
replace CUOT_OTROHOG=mto_cuota if e45_3_1_cv==3

*Se suman a los ingresos del hogar, sea mayor de 14 años o no.
egen CUOT_OTROHOG2 = sum(CUOT_OTROHOG), by(bc_correlat)
	replace CUOT_OTROHOG2=0 if bc_nper!=1


************************* INGRESOS PERSONALES (PT) *************************
* Genero otros ingresos a nivel de persona que no calcule en ningun lado
* Agregamos devolucion de FONASA a otros ingresos.
g OTROSY= 0
	replace OTROSY = (g258_1/12) + g154_1

* PT1: Total de ingresos personales por todo concepto
g pt1_iecon=0
	replace pt1_iecon = YTDOP + YTDOS + YTINDE + YTRANSF + OTROSY

* Hay que hacerlo agregado para sumarlo a HT
egen HPT1=sum(pt1_iecon), by(bc_correlat)
	replace HPT1 =0 if bc_nper!=1

* PT2: Ingresos de la ocupacion principal
* Privados:
g PT2PRIV = 0
	replace PT2PRIV=YTDOP if f73==1
* Publicos:
g PT2PUB = 0
	replace PT2PUB=YTDOP if (f73==2 | f73==8)
* Independientes:
g PT2NODEP= 0
	replace PT2NODEP=YTINDE if (f73==3 | f73==4 | f73==9)

* PT2 total
g pt2_iecon= 0
	replace pt2_iecon= PT2PRIV + PT2PUB + PT2NODEP

* PT4: Total de ingresos por trabajo (para actividad primaria y secundaria, tanto privada, publica e independiente)
g pt4_iecon = 0
	replace pt4_iecon = YTDOP + YTDOS + YTINDE


************************* INGRESOS DEL HOGAR (YHOG, HT13 Y HT11) *************************
* YHOG
g yhog_iecon = 0
replace yhog_iecon= h155_1+h156_1+h252_1+((h160_1+h160_2+h163_1+h163_2+h164+h165+h166+h269_1+h167_1_1+h167_1_2+h167_2_1+ h167_2_2+h167_3_1+h167_3_2+h167_4_1+h167_4_2+h170_1+h170_2+h271_1+h171_1+h172_1)/12)+cuotmilit_hogar+YALIMENT_MEN+totfonasa_hogar+EMER_OTRO_TOT+CUOT_OTROHOG2

egen YHOG_MAX=max(yhog_iecon), by(bc_correlat)
replace yhog_iecon=YHOG_MAX

* HT13: valor locativo
destring d8_3, replace force
recode d8_3 (.=0)
g HT13=0
replace HT13=d8_3 if d8_1==1
replace HT13=d8_3 if d8_1==2
replace HT13=d8_3 if d8_1==3
replace HT13=d8_3 if d8_1==4
*replace HT13=d8_3 if d8_1==5
*replace HT13=d8_3 if d8_1==6
replace HT13=d8_3 if d8_1==7
replace HT13=d8_3 if d8_1==8
replace HT13=d8_3 if d8_1==9
replace HT13=d8_3 if d8_1==10

* HT11
g ht11_iecon= HPT1+HT13+yhog_iecon
replace ht11_iecon=0 if bc_nper!=1

* Ingreso sin valor locativo
g ysvl_iecon= ht11_iecon-HT13
replace ysvl_iecon=0 if bc_nper!=1

compare ine_pt1 pt1_iecon if abs( ine_pt1- pt1_iecon)>1
compare ine_pt2 pt2_iecon if abs( ine_pt2- pt2_iecon)>1
compare ine_pt4 pt4_iecon if abs( ine_pt4- pt4_iecon)>1
compare ht11 ht11_iecon if abs( ht11- ht11_iecon)>1 & bc_nper==1

*Hasta aquí se replican resultados de INE







*-------------------------------------------------------------------------------
* ASIGNACIONES
* Sintaxis del Mides
*AFAM-PE
g afam_pe=0
	replace afam_pe=1 if g256==2 & g152==1 // Cobra asignación por separado del sueldo en local de cobranza todos los meses
	replace afam_pe=1 if g150==1 & (pobpcoac== 1 | pobpcoac== 3 | pobpcoac== 4 | pobpcoac== 6 | pobpcoac== 7 | /* // Cobra asignaciones familiares, son inactivos
	*/ pobpcoac== 8 | pobpcoac== 11 | (pobpcoac== 2 & f82!= 1 & f96!= 1)) // (a excepción de jubilados y pensionistas), desempleaods que no están en seguro de paro o menores de 14 años.
	replace afam_pe=1 if (g255==1)	// Declaran recibir asignación familiar-plan de equidad

*Otras AFAM
g afam_cont=0
	replace afam_cont=1 if (g150==1) & afam_pe==0
g afam_cont_pub=0
	replace afam_cont_pub=1 if afam_cont==1 & (f73==2 | f92==2)
g afam_cont_priv=0
	replace afam_cont_priv=1 if afam_cont==1 & afam_cont_pub==0
gen afam_total=(afam_pe==1 | afam_cont==1)

*** BENEFICIARIOS ***
g cant_af=(g151_6+g151_3+g151_4)

*** HOGARES ***
egen afam_pe_hog=max(afam_pe), by (bc_correlat)
egen afam_cont_hog=max(afam_cont), by (bc_correlat)
egen afam_cont_pub_hog=max(afam_cont_pub), by (bc_correlat)
egen afam_cont_priv_hog=max(afam_cont_priv), by (bc_correlat)
egen afam_total_hog=max(afam_total), by (bc_correlat)

*** MONTO AFAM-PE (con pregunta de complemento) ***
g monto_afam_pe=0
	replace monto_afam_pe=((1757.21*((g151_6+g151_3)^0.6)+753.1*(g151_3^0.6))+g151_4*(1757.21+753.1)) if bc_mes==1 & afam_pe==1 // enero
	replace monto_afam_pe=((1922.6*((g151_6+g151_3)^0.6)+823.9*(g151_3^0.6))+g151_4*(1922.6+823.9)) if bc_mes>1 & afam_pe==1 // febrero a diciembre

*-------------------------------------------------------------------------------
* AFAM_CON - Código Iecon

g jefeh=0
replace jefeh=1 if bc_pe4==1
g conyu=0
replace conyu=1 if bc_pe4==2
egen conyuh=max(conyu) if inrange(bc_pe4,1,2), by(bc_correlat)

sort bc_correlat bc_nper
g nucleo=conyuh
replace nucleo=1 if bc_pe4==1 & conyuh==0
replace nucleo=bc_nper if conyuh==.
replace nucleo=nucleo[_n-1] if e30==6 & e30[_n-1]==3
replace nucleo=nucleo[_n-1] if e30==6 & e30[_n-1]==4
replace nucleo=nucleo[_n-1] if e30==6 & e30[_n-1]==5
replace nucleo=nucleo[_n-1] if e30==7 & e30[_n-1]==7
replace nucleo=nucleo[_n-1] if e30==8 & e30[_n-1]==8
replace nucleo=nucleo[_n-1] if e30==10 & e30[_n-1]==9

gen suma1=(g126_1+g126_2+g126_3)*1.22 if ((f73==1|f73==2|f73==8)&f82==1) // Suma de ingresos por ocupación principal
gen suma2=(g134_1+g134_2+g134_3)*1.22 if ((f92==1|f92==2)&f96==1) 	// Suma de ingresos por ocupación secundaria
gen suma3=0								// Suma de ingresos trabajador independiente
replace suma3=(g142+g143/12)          if (((f73==3|f73==4|f73==9)&f82==1)|((f92==3|f92==4|f92==9)&f96==1)) // Suma de ingresos trabajador independiente
gen suma4= g148_1_1+g148_1_2+g148_1_3+g148_1_5+g148_1_6+g148_1_7+g148_1_8+g148_1_9+g148_1_10+g148_1_11+g148_1_12+g148_2_1+g148_2_2+g148_2_3+g148_2_5+g148_2_6+g148_2_7+g148_2_8+g148_2_9+g148_2_10+g148_2_11+g148_2_12 // Suma de ingresos jubilados o pensionistas

recode suma1-suma4 (.=0)

gen suma = suma1 + suma2 + suma3 + suma4
drop suma1 suma2 suma3 suma4
sort bc_correlat nucleo
by bc_correlat nucleo: egen suma_n=sum(suma)

recode suma .=0
by bc_correlat nucleo: egen suma1=max(suma_n)

gen corte_afam_contrib = 6*bpc

gen monto_asig =0
replace monto_asig = 0.16*bpc if (suma1<=corte_afam_contrib & afam_cont==1)
replace monto_asig = 0.08*bpc if (suma1>corte_afam_contrib  & afam_cont==1)

generate monto_afam_cont = 0
replace monto_afam_cont= monto_asig*cant_af

*-------------------------------------------------------------------------------
* TUS
* No hay forma de asignar TUS, por lo que se utiliza el monto declarado.
by bc_correlat: egen monto_tus_iecon=sum(tus)
replace monto_tus_iecon=0 if bc_nper!=1

*-------------------------------------------------------------------------------
* Vector salud. Código Iecon

*Cuota otro hogar
gen     cuota_otrohog =mto_cuot if ((e45_1_1_cv==6)&(e45_cv!=2|e45_2_1_cv==2)&(e45_cv!=3|e45_3_1_cv==2))
replace cuota_otrohog =mto_cuot if ((e45_2_1_cv==3)&(e45_cv!=1|e45_1_1_cv==2|e45_1_1_cv==3)&(e45_cv!=3|e45_3_1_cv==2))
replace cuota_otrohog =mto_cuot if ((e45_3_1_cv==3)&(e45_cv!=1|e45_1_1_cv==2|e45_1_1_cv==3)&(e45_cv!=2|e45_2_1_cv==2))
recode  cuota_otrohog .=0
cap drop cuota_otrohog_h
egen cuota_otrohog_h=sum(cuota_otrohog), by(bc_correlat)

gen fonasa = ytdop_3 + ytdos_3 + YTINDE_2 // Se suman cuotas mutuales por fonasa ($)
gen salud = fonasa + ytdos_2 +ytdop_2  // A fonasa, se le suman cuotas mutuales militar ($)

by bc_correlat: egen saludh= sum(salud)
replace saludh=saludh+totfonasa_hogar+cuotmilit_hogar
