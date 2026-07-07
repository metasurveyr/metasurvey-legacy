*-------------------------------------------------------------------------------
* Variables de identificación general
rename id bc_correlat
rename nper bc_nper

g bc_pesomen= -15 // no hay ponderador mensual en la base de  implantacion
g bc_pesotri= w_tri
g bc_pesosem= w_sem
g bc_pesoano= w_ano

g bc_area=.
replace bc_area=1 if region_4==1 // Montevideo
replace bc_area=2 if region_4==2 // Interior mayores de 5000
replace bc_area=3 if region_4==3 // Interior menores de 5000
replace bc_area=4 if region_4==4 // rurales - rural dispersa

g bc_filtloc=(region_4<3) // localidades de más de 5000
recode bc_filtloc (0=2)

*-------------------------------------------------------------------------------
* 1- Características generales y de las personas

* sexo
g bc_pe2=e26

* edad
g bc_pe3=e27

* parentesco
g bc_pe4=-9
	replace bc_pe4=1 if e30==1 // jefe
	replace bc_pe4=2 if e30==2 // espose
	replace bc_pe4=3 if inrange(e30,3,5)  // hije
	replace bc_pe4=4 if e30==7 | e30==8 // p(m)adre o suegre
	replace bc_pe4=5 if inrange(e30,6,12)  // yerno, nuera, hermane, cuñade, niete, otre pariente
	replace bc_pe4=6 if e30==13 // no pariente
	replace bc_pe4=7 if e30==14 // Serv domestico o famiilar del mismo

* estado civil.
g bc_pe5=-13
	replace bc_pe5=1 if e35==2 | e35==3
	replace bc_pe5=2 if inrange(e35,4,7)
	replace bc_pe5=3 if e35==0 & (e36==1 | e36==2 | e36==3)
	replace bc_pe5=4 if e35==0 & (e36==4 | e36==6)
	replace bc_pe5=5 if e35==0 & (e36==5)
	replace bc_pe5=0 if bc_pe3<=14

*-------------------------------------------------------------------------------
* 2- Atención de la Salud

g bc_pe6a=-15
	replace bc_pe6a=4 if (e45_cv==1 & (e45_1_1_cv !=1 | e45_1_1_cv!=4)) | e45_cv==4 | e45_cv==5 | e45_cv==6
	replace bc_pe6a=2 if e45_cv==2 & e45_2_1_cv!=1 & e45_2_1_cv!=6
	replace bc_pe6a=3 if (e45_cv==1 & (e45_1_1_cv==1 | e45_1_1_cv==4)) | (e45_cv==2 & (e45_2_1_cv==1 |e45_2_1_cv==6)) | (e45_cv==3 & (e45_3_1_cv==1 | e45_3_1_cv ==6))
	replace bc_pe6a=5 if ((e45_cv==3 & (e45_3_1_cv!=1 | e45_3_1_cv!=6)) | e46_cv==1) & bc_pe6a!=3
	replace bc_pe6a=1 if e45_cv==7

g bc_pe6a1=-15
	replace bc_pe6a1=1 if bc_pe6a==3 & ((pobpcoac==2 & (f82==1|f96==1)) | pobpcoac==5)
	replace bc_pe6a1=2 if bc_pe6a==3 & bc_pe6a1!=1
	replace bc_pe6a1=-9 if bc_pe6a!=3

recode bc_pe6a (2=2) (3=-9) (4=3) (5=4), gen(bc_pe6b)


*-------------------------------------------------------------------------------
* 3- Educación

*asiste
g bc_pe11=2
	replace bc_pe11=1 if e49==3
	replace bc_pe11=-9 if bc_pe3<3 & bc_pe3!=.

*asistió
g bc_pe12=2
	replace bc_pe12=1 if e49==1
	replace bc_pe12=-9 if bc_pe11==1 | bc_pe11==-9

*asistencia actual público o privada
g bc_pe13=-13

/* COMENTARIO VIEJO: La empecé a armar pero vi que hace años que no la hacen. PREGUNTAR

g bc_pe13=.
	replace bc_pe13=1 if bc_pe11==1 & (e581==1|e581==3) & inrange(bc_mes,1,7)		// e581==3 va en público???
	replace bc_pe13=2 if bc_pe11==1 & (e581==2) & inrange(bc_mes,1,7)
	replace bc_pe13=1 if bc_pe11==1 & ( (e239==1|e239==3) | (e194==1|e194==3) | (e198==1|e198==3) ) & inrange(bc_mes,1,6)

	( (e193==1 & (e194==1|e194==3)) | (e197==1 & e198==1) | e201==1

	|e212==1|e215==1|e218==1|e221==1|e224==1) & inrange(bc_mes,1,6)

	replace bc_pe13=2 if bc_pe11==2 & ( e239==2 | e194==2 | e198==2 ) & inrange(bc_mes,1,6)
	replace bc_pe13=-15 if bc_pe11==1 & ( e239==99 | e194==99 | e198==99 ) & inrange(bc_mes,1,6)
*/


*# Nivel
g bc_nivel=-13
g nivel_aux=-15

** Armo una variable similar a la que hacía el INE sobre la exigencia del curso de UTU
g bc_e51_7_1=.
replace bc_e51_7_1=1 if inrange(e214_1,50000,59999) // requisito: secundaria completa
replace bc_e51_7_1=2 if inrange(e214_1,30000,39999) // requisito: ciclo basico
replace bc_e51_7_1=3 if inrange(e214_1,20000,29999) // requisito: secundaria completa
replace bc_e51_7_1=4 if inrange(e214_1,1,19999) // requisito: nada

** Nunca asistió
replace nivel_aux=0 	if bc_pe11==2 & bc_pe12==2
replace nivel_aux=0 	if ((e51_2==0 & e51_3==0) | ((e197_1==2) & e51_2==9)) // Por qué no ponemos la primaria especial??
** Primaria
replace nivel_aux=1  	if ((((e51_2>0 & e51_2<=6) | (e51_3>0 & e51_3<=6)) &  (e51_4_a==0 & e51_4_b==0)) | (e51_2==6 & (e51_4_a==9 | e51_4_b==9)))
** Secundaria
replace nivel_aux=2 	if (((((e51_4_a>0 & e51_4_a<=3) | (e51_4_b>0 & e51_4_b<=3)) | (e51_5>0 & e51_5<=3) | (e51_6>0 & e51_6<=3)) & (e51_8==0 & e51_9==0 & e51_10==0)) | (e51_6a!=0 & bc_e51_7_1==3) | (e51_4_a==3 & e51_8==9) | (e51_4_b==3 & e51_8==9) | (e51_5==3 & e51_8==9))
** UTU
replace nivel_aux=3  	if ((e51_6a>0 & e51_6a<=9 & bc_e51_7_1<3) | (e51_6a!=0 & e51_4_a==0 & e51_4_b==0 & e51_5==0 & e51_6==0) & e51_8==0 & e51_9==0 & e51_10==0)
** Magisterio o profesorado
replace nivel_aux=4  	if (e51_8>0 & e51_8<=5) & e51_9==0 & e51_10==0 & e51_11==0
** Universidad o similar
replace nivel_aux=5  	if ((e51_9>0 & e51_9<=9) | (e51_10>0 & e51_10<=9) | (e51_11>0 & e51_11<=9))

replace nivel_aux=0 	if nivel_aux==-15 & (e51_2==9 | e51_3==9)


*# Años de bc_educación
g bc_edu=-15

*Primaria
replace bc_edu=0 			if nivel_aux==0
replace bc_edu=e51_2 		if nivel_aux==1 & ((e51_2>=e51_3 & e51_2!=9) | (e51_2>0 & e51_2!=9 & e51_3==9))
replace bc_edu=e51_3 		if nivel_aux==1 & ((e51_3>e51_2 & e51_3!=9)  | (e51_3>0 & e51_3!=9 & e51_2==9))

*Secundaria
replace bc_edu=6+e51_4_a 	if nivel_aux==2 & e51_4_a<=3 & e51_4_a>0
replace bc_edu=6+e51_4_b 	if nivel_aux==2 & e51_4_b<=3 & e51_4_b>0
replace bc_edu=9			if nivel_aux==2 & e51_4_a!=0 & e51_4_b!=0 & bc_edu>9
replace bc_edu=9+e51_5 		if nivel_aux==2 & (e51_4_a==3 | e51_4_b==3 | e51_4_a+e51_4_b==3) & e51_5<9 & e51_5>0
replace bc_edu=9+e51_6 		if nivel_aux==2 & (e51_4_a==3 | e51_4_b==3 | e51_4_a+e51_4_b==3) & e51_6<9 & e51_6>0
replace bc_edu=9 			if nivel_aux==2 & (e51_4_a+e51_4_b>0) & (e51_4_a!=. | e51_4_b!=.) & e51_5==0 & e51_6==0 & (e201_1c==1 | e201_1d==1)
replace bc_edu=9			if nivel_aux==2 & (e51_4_a==3 | e51_4_b==3 | e51_4_a+e51_4_b==3) & e51_5==9
replace bc_edu=9 			if nivel_aux==2 & (e51_4_a==3 | e51_4_b==3 | e51_4_a+e51_4_b==3) & e51_6==9
replace bc_edu=6 			if nivel_aux==2 & ((e51_4_a==9 & e51_4_b==0) | (e51_4_b==9 & e51_4_a==0))
replace bc_edu=9 			if nivel_aux==2 & (e51_4_a==9 & e51_4_b==9) & (e201_1a==1 | e201_1b==1)
replace bc_edu=9+e51_5 		if nivel_aux==2 & bc_edu==-15 & e51_5!=0
replace bc_edu=9+e51_6 		if nivel_aux==2 & bc_edu==-15 & e51_6!=0

* UTU actual
replace bc_edu=6+e51_6a 	if nivel_aux==3 & e51_6a<9
replace bc_edu=6 			if nivel_aux==3 & e51_6a==9

*magisterio
replace bc_edu=12+e51_8 	if nivel_aux==4 & e51_8<9 & e51_8>0
replace bc_edu=12 			if nivel_aux==4 & e51_8==9
replace bc_edu=15 			if nivel_aux==4 & e51_8==9 & e215_1==1

*Terciaria
replace bc_edu=12+e51_9				if nivel_aux==5 & e51_9<9 & e51_9>0
replace bc_edu=12+e51_10 			if nivel_aux==5 & e51_10<9 & e51_10>0
replace bc_edu=12+e51_9+e51_11 		if nivel_aux==5 & e51_11<9 & e51_11>0 & e51_9>=e51_10 & e51_9!=9
replace bc_edu=12+e51_10+e51_11		if nivel_aux==5 & e51_11<9 & e51_11>0 & e51_9<e51_10 & e51_10!=9
replace bc_edu=12 					if nivel_aux==5 & e51_9==9
replace bc_edu=12 					if nivel_aux==5 & e51_10==9
replace bc_edu=12+e51_9 			if nivel_aux==5 & e51_11==9 & e51_9>=e51_10 & e51_9!=9
replace bc_edu=12+e51_10 			if nivel_aux==5 & e51_11==9 & e51_9<e51_10 & e51_10!=9

recode bc_edu 23/38=22

tab bc_edu nivel_aux // revisar los que no tienen coherencia

*finalizó
g bc_finalizo=-13


*-------------------------------------------------------------------------------
*- Años de educación. Mejor forma de captar años para 2011-2019
*- (No compatible para 1981-2019)
gen bc_edu_1=.

*Primaria
replace bc_edu_1=0 if nivel_aux==0
replace bc_edu_1=0 if nivel_aux==3 & bc_e51_7_1==4 & e51_6a==9
replace bc_edu_1=e51_2 	if nivel_aux==1 & ((e51_2>=e51_3 & e51_2!=9) | (e51_2>0 & e51_2!=9 & e51_3==9))
replace bc_edu_1=e51_3 	if nivel_aux==1 & ((e51_3>e51_2 & e51_3!=9)  | (e51_3>0 & e51_3!=9 & e51_2==9))

*Secundaria
replace bc_edu_1=6+e51_4_a 	if nivel_aux==2 & e51_4_a<=3 & e51_4_a>0
replace bc_edu_1=6+e51_4_b 	if nivel_aux==2 & e51_4_b<=3 & e51_4_b>0
replace bc_edu_1=9			if nivel_aux==2 & e51_4_a!=0 & e51_4_b!=0 & bc_edu>9
replace bc_edu_1=9+e51_5 	if nivel_aux==2 & (e51_4_a==3 | e51_4_b==3 | e51_4_a+e51_4_b==3) & e51_5<9 & e51_5>0
replace bc_edu_1=9+e51_6 	if nivel_aux==2 & (e51_4_a==3 | e51_4_b==3 | e51_4_a+e51_4_b==3) & e51_6<9 & e51_6>0
replace bc_edu_1=9 			if nivel_aux==2 & (e51_4_a+e51_4_b>0) & (e51_4_a!=. | e51_4_b!=.) & e51_5==0 & e51_6==0 & (e201_1c==1 | e201_1d==1)
replace bc_edu_1=9			if nivel_aux==2 & (e51_4_a==3 | e51_4_b==3 | e51_4_a+e51_4_b==3) & e51_5==9
replace bc_edu_1=9 			if nivel_aux==2 & (e51_4_a==3 | e51_4_b==3 | e51_4_a+e51_4_b==3) & e51_6==9
replace bc_edu_1=6 			if nivel_aux==2 & ((e51_4_a==9 & e51_4_b==0) | (e51_4_b==9 & e51_4_a==0))
replace bc_edu_1=9 			if nivel_aux==2 & (e51_4_a==9 & e51_4_b==9) & (e201_1a==1 | e201_1b==1)
replace bc_edu_1=9+e51_5 	if nivel_aux==2 & bc_edu_1==. & e51_5!=0
replace bc_edu_1=9+e51_6 	if nivel_aux==2 & bc_edu_1==. & e51_6!=0

* UTU actual
replace bc_edu_1=12+e51_6a 	if nivel_aux==3 & bc_e51_7_1==1 & e51_6a<9 & e51_6a>0
replace bc_edu_1=9+e51_6a 	if nivel_aux==3 & bc_e51_7_1==2 & e51_6a<9 & e51_6a>0
replace bc_edu_1=6+e51_6a 	if nivel_aux==3 & bc_e51_7_1==3 & e51_6a<9 & e51_6a>0
replace bc_edu_1=e51_6a 	if nivel_aux==3 & bc_e51_7_1==4 & e51_6a<9 & e51_6a>0
replace bc_edu_1=16 		if nivel_aux==3 & bc_e51_7_1==1 & e51_6a>0 & e51_6b==1
replace bc_edu_1=12 		if nivel_aux==3 & bc_e51_7_1==2 & e51_6a>0 & e51_6b==1
replace bc_edu_1=9 			if nivel_aux==3 & bc_e51_7_1==3 & e51_6a>0 & e51_6b==1
replace bc_edu_1=6 			if nivel_aux==3 & bc_e51_7_1==4 & e51_6a>0 & e51_6b==1
replace bc_edu_1=12 		if nivel_aux==3 & bc_e51_7_1==1 & e51_6a==9
replace bc_edu_1=15 		if nivel_aux==3 & bc_e51_7_1==1 & e51_6a==9 & e51_6b==1
replace bc_edu_1=9 			if nivel_aux==3 & bc_e51_7_1==2 & e51_6a==9
replace bc_edu_1=12 		if nivel_aux==3 & bc_e51_7_1==2 & e51_6a==9 & e51_6b==1
replace bc_edu_1=6 			if nivel_aux==3 & bc_e51_7_1==3 & e51_6a==9
replace bc_edu_1=9 			if nivel_aux==3 & bc_e51_7_1==3 & e51_6a==9 & e51_6b==1

*magisterio
replace bc_edu_1=12+e51_8 	if nivel_aux==4 & e51_8<9 & e51_8>0
replace bc_edu_1=12 		if nivel_aux==4 & e51_8==9
replace bc_edu_1=15 		if nivel_aux==4 & e51_8==9 & e215_1==1

*Terciaria
replace bc_edu_1=12+e51_9			if nivel_aux==5 & e51_9<9 & e51_9>0
replace bc_edu_1=12+e51_10 			if nivel_aux==5 & e51_10<9 & e51_10>0
replace bc_edu_1=12+e51_9+e51_11 	if nivel_aux==5 & e51_11<9 & e51_11>0 & e51_9>=e51_10 & e51_9!=9
replace bc_edu_1=12+e51_10+e51_11	if nivel_aux==5 & e51_11<9 & e51_11>0 & e51_9<e51_10 & e51_10!=9
replace bc_edu_1=12 				if nivel_aux==5 & e51_9==9
replace bc_edu_1=12 				if nivel_aux==5 & e51_10==9
replace bc_edu_1=15 				if nivel_aux==5 & e51_9==9 & (e218_1==1 | e221_1==1)
replace bc_edu_1=16 				if nivel_aux==5 & e51_10==9 & (e218_1==1 | e221_1==1)
replace bc_edu_1=12+e51_9 			if nivel_aux==5 & e51_11==9 & e51_9>=e51_10 & e51_9!=9
replace bc_edu_1=12+e51_10 			if nivel_aux==5 & e51_11==9 & e51_9<e51_10 & e51_10!=9

recode bc_edu_1 23/38=22


*-------------------------------------------------------------------------------
*-------------------------------------------------------------------------------
* 4- Mercado de trabajo

* Condición de actividad
g bc_pobp = pobpcoac
recode bc_pobp (10=9)

* Categoría de ocupación
g bc_pf41= -9 // no se pregunta por separado si el/la cuenta propia es con o sin local
	replace bc_pf41=1 if f73==1
	replace bc_pf41=2 if f73==2
	replace bc_pf41=3 if f73==3
	replace bc_pf41=4 if f73==4
	replace bc_pf41=5 if (f73==9 & (f281_1==2 & f281_2==2 & f281_3==2 & f281_4==2))
	replace bc_pf41=6 if (f73==9 & (f281_1==1 | f281_2==1 | f281_3==1 | f281_4==1))
	replace bc_pf41=7 if f73==7|f73==8

g bc_cat2=-9
	replace bc_cat2=1 if f73==1
	replace bc_cat2=2 if f73==2
	replace bc_cat2=3 if f73==4
	replace bc_cat2=4 if f73==9
	replace bc_cat2=5 if f73==3|f73==7|f73==8

* Tamaño del establecimiento
g bc_pf081=-9
	replace bc_pf081=1 if inrange(f77,1,3) //tamaño chico
	replace bc_pf081=2 if inrange(f77,4,9) //tamaño grande

g bc_pf082=-9
	replace bc_pf082=1 if f77==1
	replace bc_pf082=2 if f77==2
	replace bc_pf082=3 if f77==3

* Rama del establecimiento
g bc_pf40=f72_2

g bc_rama=-9
	replace bc_rama=1 if f72_2>0000 & f72_2<1000 & bc_pobp==2
	replace bc_rama=2 if f72_2>1000 & f72_2<3500
	replace bc_rama=3 if f72_2>3500 & f72_2<3700
	replace bc_rama=4 if f72_2>4000 & f72_2<4500
	replace bc_rama=5 if (f72_2>=4500&f72_2<4900)|(f72_2>=5500&f72_2<5700)
	replace bc_rama=6 if (f72_2>=4900&f72_2<5500)|(f72_2>=5800&f72_2<6400)
	replace bc_rama=7 if f72_2>=6400&f72_2<8300
	replace bc_rama=8 if f72_2>=8300&f72_2<9910 | (f72_2>= 3700 & f72_2<=3900)

* Tipo de ocupación
g bc_pf39=f71_2
	replace bc_pf39=-9  if bc_pf39==. & bc_pobp!=2
	replace bc_pf39=-9  if bc_pf39==0 & bc_pobp!=2
	replace bc_pf39=-15 if bc_pf39==. & bc_pobp==2

g bc_tipo_ocup=trunc(bc_pf39/1000)
	replace bc_tipo_ocup=-9 if bc_tipo_ocup==0&bc_pobp!=2

* Cantidad de empleos
g bc_pf07=f70
recode bc_pf07 (0=-9)

* Horas trabajadas
g bc_pf051=-13
g bc_pf052=-13
g bc_pf053=-13
g bc_pf06=-13
g bc_horas_sp=-13
g bc_horas_sp_1=-13

recode f85 f98 (.=0)
g bc_horas_hab=f85+f98 // horas semanales trabajadas habitualmente en total
replace bc_horas_hab=-9 if bc_pobp!=2
g bc_horas_hab_1=f85   // horas semanales trabajadas habitualmente en trabajo principal
replace bc_horas_hab_1=-9 if bc_pobp!=2

* Motivo por el que no trabaja
g bc_pf04=f69
recode bc_pf04 (3=4) (7/8=3) (5/6=4) (9/14=4) (0=-9)

* Busqueda de trabajo
g bc_pf21= -13 // buscó trabajo la semana pasada -- no se pregunta, lo que si se pregunta en ambos es si buscó en las últimas 4 semanas

g bc_pf22= -13 // causa por la que no buscó trabajo // Chequear que hacer con nuevas cat en 2020-2021 // En segundo semestre de 2021 no existe el f108=2

* Duración desempleo (semanas)
g bc_pf26=f113
replace bc_pf26=-9 if bc_pobp<3|bc_pobp>5

* Causas por las que dejó último trabajo
g bc_pf34=f122
recode bc_pf34 (1=2) (2=1) (4/9=3) (0=-9) (99=-15)

* Trabajo registrado
 g bc_reg_disse=-9
	replace bc_reg_disse=2 if bc_pobp==2
	replace bc_reg_disse=1 if (e45_1_1_cv==1 | e45_2_1_cv==1 | e45_3_1_cv==1 | bc_cat2==2) & bc_pobp==2

g bc_register=-9
	replace bc_register=2 if bc_pobp==2
	replace bc_register=1 if bc_pobp==2 & f82==1

g bc_register2=-9
	replace bc_register2=2 if bc_pobp==2
	replace bc_register2=1 if bc_pobp==2 & (f82==1|f96==1)

* Subocupado
g bc_subocupado=-9
	replace bc_subocupado=2 if bc_pobp==2
	replace bc_subocupado=1 if f102==1 & f104==5 & bc_horas_hab>0 & bc_horas_hab<40 & bc_horas_hab!=.

g bc_subocupado1=-9
	replace bc_subocupado1=2 if bc_pobp==2
	replace bc_subocupado1=1 if (f101==1|f102==1) & f103==1 & f104==5 & bc_horas_hab>0 & bc_horas_hab<40 & bc_horas_hab!=.


*-------------------------------------------------------------------------------
* ipc

cap drop bc_ipc
g bc_ipc=.
replace	bc_ipc=	0.42445305 if bc_mes==1 & bc_anio==2018
replace	bc_ipc=	0.41391656 if bc_mes==2 & bc_anio==2018
replace	bc_ipc=	0.41022597 if bc_mes==3 & bc_anio==2018
replace	bc_ipc=	0.40914506 if bc_mes==4 & bc_anio==2018
replace	bc_ipc=	0.40862914 if bc_mes==5 & bc_anio==2018
replace	bc_ipc=	0.40481184 if bc_mes==6 & bc_anio==2018
replace	bc_ipc=	0.40110836 if bc_mes==7 & bc_anio==2018
replace	bc_ipc=	0.39832170 if bc_mes==8 & bc_anio==2018
replace	bc_ipc=	0.39548952 if bc_mes==9 & bc_anio==2018
replace	bc_ipc=	0.39360982 if bc_mes==10 & bc_anio==2018
replace	bc_ipc=	0.39259392 if bc_mes==11 & bc_anio==2018
replace	bc_ipc=	0.39065966 if bc_mes==12 & bc_anio==2018
replace	bc_ipc=	0.39170673 if bc_mes==1 & bc_anio==2019
replace	bc_ipc=	0.38368144 if bc_mes==2 & bc_anio==2019
replace	bc_ipc=	0.37992637 if bc_mes==3 & bc_anio==2019
replace	bc_ipc=	0.37798040 if bc_mes==4 & bc_anio==2019
replace	bc_ipc=	0.37613018 if bc_mes==5 & bc_anio==2019
replace	bc_ipc=	0.37491929 if bc_mes==6 & bc_anio==2019
replace	bc_ipc=	0.37272569 if bc_mes==7 & bc_anio==2019
replace	bc_ipc=	0.36978545 if bc_mes==8 & bc_anio==2019
replace	bc_ipc=	0.36676486 if bc_mes==9 & bc_anio==2019
replace	bc_ipc=	0.36489746 if bc_mes==10 & bc_anio==2019
replace	bc_ipc=	0.36232539 if bc_mes==11 & bc_anio==2019
replace	bc_ipc=	0.36083441 if bc_mes==12 & bc_anio==2019
replace bc_ipc= 0.36059001 if bc_mes==1 & bc_anio==2020
replace bc_ipc= 0.35334197 if bc_mes==2 & bc_anio==2020
replace bc_ipc= 0.35086361 if bc_mes==3 & bc_anio==2020
replace bc_ipc= 0.34697619 if bc_mes==4 & bc_anio==2020
replace bc_ipc= 0.34116334 if bc_mes==5 & bc_anio==2020
replace bc_ipc= 0.33934600 if bc_mes==6 & bc_anio==2020
replace bc_ipc= 0.33951604 if bc_mes==7 & bc_anio==2020
replace bc_ipc= 0.33722720 if bc_mes==8 & bc_anio==2020
replace bc_ipc= 0.33493891 if bc_mes==9 & bc_anio==2020
replace bc_ipc= 0.33247371 if bc_mes==10 & bc_anio==2020
replace bc_ipc= 0.33051286 if bc_mes==11 & bc_anio==2020
replace bc_ipc= 0.32932997 if bc_mes==12 & bc_anio==2020
replace bc_ipc= 0.32970873  if bc_mes==1 & bc_anio==2021
replace bc_ipc= 0.325120853 if bc_mes==2 & bc_anio==2021
replace bc_ipc= 0.321933118 if bc_mes==3 & bc_anio==2021
replace bc_ipc= 0.320163039 if bc_mes==4 & bc_anio==2021
replace bc_ipc= 0.318357917 if bc_mes==5 & bc_anio==2021
replace bc_ipc= 0.316774855 if bc_mes==6 & bc_anio==2021
replace bc_ipc= 0.314794761 if bc_mes==7 & bc_anio==2021
replace bc_ipc= 0.313062649 if bc_mes==8 & bc_anio==2021
replace bc_ipc= 0.310558148 if bc_mes==9 & bc_anio==2021
replace bc_ipc= 0.309333702 if bc_mes==10 & bc_anio==2021
replace bc_ipc= 0.306270363 if bc_mes==11 & bc_anio==2021
replace bc_ipc= 0.305191858 if bc_mes==12 & bc_anio==2021
replace bc_ipc= 0.305304369 if bc_mes==1 & bc_anio==2022
replace bc_ipc= 0.300249579 if bc_mes==2 & bc_anio==2022
replace bc_ipc= 0.296416606 if bc_mes==3 & bc_anio==2022
replace bc_ipc= 0.293521662 if bc_mes==4 & bc_anio==2022
replace bc_ipc= 0.291695192 if bc_mes==5 & bc_anio==2022
replace bc_ipc= 0.289981541 if bc_mes==6 & bc_anio==2022
replace bc_ipc= 0.288299058 if bc_mes==7 & bc_anio==2022
replace bc_ipc= 0.285976118 if bc_mes==8 & bc_anio==2022
replace bc_ipc= 0.28362554  if bc_mes==9 & bc_anio==2022
replace bc_ipc= 0.281727985 if bc_mes==10 & bc_anio==2022
replace bc_ipc= 0.281058696 if bc_mes==11 & bc_anio==2022
replace bc_ipc= 0.281772318 if bc_mes==12 & bc_anio==2022
replace bc_ipc= 0.282491271 if bc_mes==1 & bc_anio==2023
replace bc_ipc= 0.278492031 if bc_mes==2 & bc_anio==2023
replace bc_ipc= 0.275598806 if bc_mes==3 & bc_anio==2023
replace bc_ipc= 0.272895809 if bc_mes==4 & bc_anio==2023
replace bc_ipc= 0.270937488 if bc_mes==5 & bc_anio==2023
replace bc_ipc= 0.271089587 if bc_mes==6 & bc_anio==2023
replace bc_ipc= 0.271973819 if bc_mes==7 & bc_anio==2023
replace bc_ipc= 0.272476136 if bc_mes==8 & bc_anio==2023

cap drop bc_ipc_nuevo
g bc_ipc_nuevo=.
replace	bc_ipc_nuevo=	0.56947608 if bc_mes==1 & bc_dpto==1 & bc_anio==2018
replace	bc_ipc_nuevo=	0.55533959 if bc_mes==2 & bc_dpto==1 & bc_anio==2018
replace	bc_ipc_nuevo=	0.55038802 if bc_mes==3 & bc_dpto==1 & bc_anio==2018
replace	bc_ipc_nuevo=	0.54893781 if bc_mes==4 & bc_dpto==1 & bc_anio==2018
replace	bc_ipc_nuevo=	0.54824561 if bc_mes==5 & bc_dpto==1 & bc_anio==2018
replace	bc_ipc_nuevo=	0.54312405 if bc_mes==6 & bc_dpto==1 & bc_anio==2018
replace	bc_ipc_nuevo=	0.53815520 if bc_mes==7 & bc_dpto==1 & bc_anio==2018
replace	bc_ipc_nuevo=	0.53441642 if bc_mes==8 & bc_dpto==1 & bc_anio==2018
replace	bc_ipc_nuevo=	0.53061658 if bc_mes==9 & bc_dpto==1 & bc_anio==2018
replace	bc_ipc_nuevo=	0.52809463 if bc_mes==10 & bc_dpto==1 & bc_anio==2018
replace	bc_ipc_nuevo=	0.52673163 if bc_mes==11 & bc_dpto==1 & bc_anio==2018
replace	bc_ipc_nuevo=	0.52413649 if bc_mes==12 & bc_dpto==1 & bc_anio==2018
replace	bc_ipc_nuevo=	0.52554131 if bc_mes==1 & bc_dpto==1 & bc_anio==2019
replace	bc_ipc_nuevo=	0.51477401 if bc_mes==2 & bc_dpto==1 & bc_anio==2019
replace	bc_ipc_nuevo=	0.50973596 if bc_mes==3 & bc_dpto==1 & bc_anio==2019
replace	bc_ipc_nuevo=	0.50712511 if bc_mes==4 & bc_dpto==1 & bc_anio==2019
replace	bc_ipc_nuevo=	0.50464271 if bc_mes==5 & bc_dpto==1 & bc_anio==2019
replace	bc_ipc_nuevo=	0.50301811 if bc_mes==6 & bc_dpto==1 & bc_anio==2019
replace	bc_ipc_nuevo=	0.50007501 if bc_mes==7 & bc_dpto==1 & bc_anio==2019
replace	bc_ipc_nuevo=	0.49613018 if bc_mes==8 & bc_dpto==1 & bc_anio==2019
replace	bc_ipc_nuevo=	0.49207755 if bc_mes==9 & bc_dpto==1 & bc_anio==2019
replace	bc_ipc_nuevo=	0.48957211 if bc_mes==10 & bc_dpto==1 & bc_anio==2019
replace	bc_ipc_nuevo=	0.48612124 if bc_mes==11 & bc_dpto==1 & bc_anio==2019
replace	bc_ipc_nuevo=	0.48412084 if bc_mes==12 & bc_dpto==1 & bc_anio==2019
replace	bc_ipc_nuevo=	0.48379294 if bc_mes==1 & bc_dpto==1 & bc_anio==2020
replace	bc_ipc_nuevo=	0.47406846 if bc_mes==2 & bc_dpto==1 & bc_anio==2020
replace	bc_ipc_nuevo=	0.47074330 if bc_mes==3 & bc_dpto==1 & bc_anio==2020
replace	bc_ipc_nuevo=	0.46552768 if bc_mes==4 & bc_dpto==1 & bc_anio==2020
replace	bc_ipc_nuevo=	0.45772875 if bc_mes==5 & bc_dpto==1 & bc_anio==2020
replace	bc_ipc_nuevo=	0.45529048 if bc_mes==6 & bc_dpto==1 & bc_anio==2020
replace	bc_ipc_nuevo=	0.45551861 if bc_mes==7 & bc_dpto==1 & bc_anio==2020
replace	bc_ipc_nuevo=	0.45244774 if bc_mes==8 & bc_dpto==1 & bc_anio==2020
replace	bc_ipc_nuevo=	0.44937761 if bc_mes==9	& bc_dpto==1 & bc_anio==2020
replace	bc_ipc_nuevo=	0.44607012 if bc_mes==10 & bc_dpto==1 & bc_anio==2020
replace	bc_ipc_nuevo=	0.44343932 if bc_mes==11 & bc_dpto==1 & bc_anio==2020
replace	bc_ipc_nuevo=	0.44185224 if bc_mes==12 & bc_dpto==1 & bc_anio==2020
replace	bc_ipc_nuevo=	0.442360435 if bc_mes==1 & bc_dpto==1 & bc_anio==2021
replace	bc_ipc_nuevo=	0.436205016 if bc_mes==2 & bc_dpto==1 & bc_anio==2021
replace	bc_ipc_nuevo=	0.431928127 if bc_mes==3 & bc_dpto==1 & bc_anio==2021
replace	bc_ipc_nuevo=	0.429553265 if bc_mes==4 & bc_dpto==1 & bc_anio==2021
replace	bc_ipc_nuevo=	0.427131386 if bc_mes==5 & bc_dpto==1 & bc_anio==2021
replace	bc_ipc_nuevo=	0.425007438 if bc_mes==6 & bc_dpto==1 & bc_anio==2021
replace	bc_ipc_nuevo=	0.422350805 if bc_mes==7 & bc_dpto==1 & bc_anio==2021
replace	bc_ipc_nuevo=	0.420026882 if bc_mes==8 & bc_dpto==1 & bc_anio==2021
replace	bc_ipc_nuevo=	0.416666667 if bc_mes==9 & bc_dpto==1 & bc_anio==2021
replace	bc_ipc_nuevo=	0.415023864 if bc_mes==10 & bc_dpto==1 & bc_anio==2021
replace	bc_ipc_nuevo=	0.410913872 if bc_mes==11 & bc_dpto==1 & bc_anio==2021
replace	bc_ipc_nuevo=	0.409466874 if bc_mes==12 & bc_dpto==1 & bc_anio==2021
replace	bc_ipc_nuevo=	0.409617827 if bc_mes==1 & bc_dpto==1 & bc_anio==2022
replace	bc_ipc_nuevo=	0.402835965 if bc_mes==2 & bc_dpto==1 & bc_anio==2022
replace	bc_ipc_nuevo=	0.397693378 if bc_mes==3 & bc_dpto==1 & bc_anio==2022
replace	bc_ipc_nuevo=	0.393809318 if bc_mes==4 & bc_dpto==1 & bc_anio==2022
replace	bc_ipc_nuevo=	0.391358798 if bc_mes==5 & bc_dpto==1 & bc_anio==2022
replace	bc_ipc_nuevo=	0.389059643 if bc_mes==6 & bc_dpto==1 & bc_anio==2022
replace	bc_ipc_nuevo=	0.386802305 if bc_mes==7 & bc_dpto==1 & bc_anio==2022
replace	bc_ipc_nuevo=	0.383685685 if bc_mes==8 & bc_dpto==1 & bc_anio==2022
replace	bc_ipc_nuevo=	0.380531984 if bc_mes==9 & bc_dpto==1 & bc_anio==2022
replace	bc_ipc_nuevo=	0.37798609  if bc_mes==10 & bc_dpto==1 & bc_anio==2022
replace	bc_ipc_nuevo=	0.377088125 if bc_mes==11 & bc_dpto==1 & bc_anio==2022
replace	bc_ipc_nuevo=	0.378045571 if bc_mes==12 & bc_dpto==1 & bc_anio==2022
replace	bc_ipc_nuevo=	0.379010169 if bc_mes==1 & bc_dpto==1 & bc_anio==2023
replace	bc_ipc_nuevo=	0.373644507 if bc_mes==2 & bc_dpto==1 & bc_anio==2023
replace	bc_ipc_nuevo=	0.369762754 if bc_mes==3 & bc_dpto==1 & bc_anio==2023
replace	bc_ipc_nuevo=	0.366136222 if bc_mes==4 & bc_dpto==1 & bc_anio==2023
replace	bc_ipc_nuevo=	0.3635088   if bc_mes==5 & bc_dpto==1 & bc_anio==2023
replace	bc_ipc_nuevo=	0.363712867 if bc_mes==6 & bc_dpto==1 & bc_anio==2023
replace	bc_ipc_nuevo=	0.364899215 if bc_mes==7 & bc_dpto==1 & bc_anio==2023
replace	bc_ipc_nuevo=	0.365573159 if bc_mes==8 & bc_dpto==1 & bc_anio==2023

replace	bc_ipc_nuevo=	0.59077214 if	bc_mes==1 & bc_dpto!=1	& bc_anio==2018
replace	bc_ipc_nuevo=	0.57392103 if	bc_mes==2 & bc_dpto!=1	& bc_anio==2018
replace	bc_ipc_nuevo=	0.56905480 if	bc_mes==3 & bc_dpto!=1	& bc_anio==2018
replace	bc_ipc_nuevo=	0.56734370 if	bc_mes==4 & bc_dpto!=1	& bc_anio==2018
replace	bc_ipc_nuevo=	0.56740808 if	bc_mes==5 & bc_dpto!=1	& bc_anio==2018
replace	bc_ipc_nuevo=	0.56388858 if	bc_mes==6 & bc_dpto!=1	& bc_anio==2018
replace	bc_ipc_nuevo=	0.55784893 if	bc_mes==7 & bc_dpto!=1	& bc_anio==2018
replace	bc_ipc_nuevo=	0.55533959 if	bc_mes==8 & bc_dpto!=1	& bc_anio==2018
replace	bc_ipc_nuevo=	0.55199823 if	bc_mes==9 & bc_dpto!=1	& bc_anio==2018
replace	bc_ipc_nuevo=	0.54911866 if	bc_mes==10 & bc_dpto!=1	& bc_anio==2018
replace	bc_ipc_nuevo=	0.54803529 if	bc_mes==11 & bc_dpto!=1	& bc_anio==2018
replace	bc_ipc_nuevo=	0.54698611 if	bc_mes==12 & bc_dpto!=1	& bc_anio==2018
replace	bc_ipc_nuevo=	0.54999450 if	bc_mes==1 & bc_dpto!=1	& bc_anio==2019
replace	bc_ipc_nuevo=	0.53777897 if	bc_mes==2 & bc_dpto!=1	& bc_anio==2019
replace	bc_ipc_nuevo=	0.53262317 if	bc_mes==3 & bc_dpto!=1	& bc_anio==2019
replace	bc_ipc_nuevo=	0.52943668 if	bc_mes==4 & bc_dpto!=1	& bc_anio==2019
replace	bc_ipc_nuevo=	0.52767664 if	bc_mes==5 & bc_dpto!=1	& bc_anio==2019
replace	bc_ipc_nuevo=	0.52507220 if	bc_mes==6 & bc_dpto!=1	& bc_anio==2019
replace	bc_ipc_nuevo=	0.52137643 if	bc_mes==7 & bc_dpto!=1	& bc_anio==2019
replace	bc_ipc_nuevo=	0.51759834 if	bc_mes==8 & bc_dpto!=1	& bc_anio==2019
replace	bc_ipc_nuevo=	0.51266277 if	bc_mes==9 & bc_dpto!=1	& bc_anio==2019
replace	bc_ipc_nuevo=	0.50996991 if	bc_mes==10 & bc_dpto!=1	& bc_anio==2019
replace	bc_ipc_nuevo=	0.50589366 if	bc_mes==11 & bc_dpto!=1	& bc_anio==2019
replace	bc_ipc_nuevo=	0.50377834 if	bc_mes==12 & bc_dpto!=1	& bc_anio==2019
replace	bc_ipc_nuevo=	0.50459179 if	bc_mes==1 & bc_dpto!=1	& bc_anio==2020
replace	bc_ipc_nuevo=	0.49394912 if	bc_mes==2 & bc_dpto!=1	& bc_anio==2020
replace	bc_ipc_nuevo=	0.49154542 if	bc_mes==3 & bc_dpto!=1	& bc_anio==2020
replace	bc_ipc_nuevo=	0.48369933 if	bc_mes==4 & bc_dpto!=1	& bc_anio==2020
replace	bc_ipc_nuevo=	0.47236656 if	bc_mes==5 & bc_dpto!=1	& bc_anio==2020
replace	bc_ipc_nuevo=	0.46954970 if	bc_mes==6 & bc_dpto!=1	& bc_anio==2020
replace	bc_ipc_nuevo=	0.46899916 if	bc_mes==7 & bc_dpto!=1	& bc_anio==2020
replace	bc_ipc_nuevo=	0.46728972 if	bc_mes==8 & bc_dpto!=1	& bc_anio==2020
replace	bc_ipc_nuevo=	0.46524612 if	bc_mes==9 & bc_dpto!=1	& bc_anio==2020
replace	bc_ipc_nuevo=	0.46294153 if	bc_mes==10 & bc_dpto!=1	& bc_anio==2020
replace	bc_ipc_nuevo=	0.46034157 if	bc_mes==11 & bc_dpto!=1	& bc_anio==2020
replace	bc_ipc_nuevo=	0.45955882 if	bc_mes==12 & bc_dpto!=1	& bc_anio==2020
replace	bc_ipc_nuevo=	0.460914454 if bc_mes==1 & bc_dpto!=1 & bc_anio==2021
replace	bc_ipc_nuevo=	0.452468214 if bc_mes==2 & bc_dpto!=1 & bc_anio==2021
replace	bc_ipc_nuevo=	0.449741399 if bc_mes==3 & bc_dpto!=1 & bc_anio==2021
replace	bc_ipc_nuevo=	0.44482007  if bc_mes==4 & bc_dpto!=1 & bc_anio==2021
replace	bc_ipc_nuevo=	0.443007132 if bc_mes==5 & bc_dpto!=1 & bc_anio==2021
replace	bc_ipc_nuevo=	0.439850451 if bc_mes==6 & bc_dpto!=1 & bc_anio==2021
replace	bc_ipc_nuevo=	0.437828371 if bc_mes==7 & bc_dpto!=1 & bc_anio==2021
replace	bc_ipc_nuevo=	0.433839479 if bc_mes==8 & bc_dpto!=1 & bc_anio==2021
replace	bc_ipc_nuevo=	0.431462225 if bc_mes==9	& bc_dpto!=1 & bc_anio==2021
replace	bc_ipc_nuevo=	0.426839679 if bc_mes==10 & bc_dpto!=1 & bc_anio==2021
replace	bc_ipc_nuevo=	0.42627563  if bc_mes==11 & bc_dpto!=1 & bc_anio==2021
replace	bc_ipc_nuevo=	0.427058422 if bc_mes==12 & bc_dpto!=1 & bc_anio==2021
replace	bc_ipc_nuevo=	0.419041234 if bc_mes==1 & bc_dpto!=1 & bc_anio==2022
replace	bc_ipc_nuevo=	0.41198039  if bc_mes==2 & bc_dpto!=1 & bc_anio==2022
replace	bc_ipc_nuevo=	0.406834825 if bc_mes==3 & bc_dpto!=1 & bc_anio==2022
replace	bc_ipc_nuevo=	0.405564343 if bc_mes==4 & bc_dpto!=1 & bc_anio==2022
replace	bc_ipc_nuevo=	0.404367165 if bc_mes==5 & bc_dpto!=1 & bc_anio==2022
replace	bc_ipc_nuevo=	0.40199389  if bc_mes==6 & bc_dpto!=1 & bc_anio==2022
replace	bc_ipc_nuevo=	0.399153794 if bc_mes==7 & bc_dpto!=1 & bc_anio==2022
replace	bc_ipc_nuevo=	0.395882819 if bc_mes==8 & bc_dpto!=1 & bc_anio==2022
replace	bc_ipc_nuevo=	0.395882819 if bc_mes==9	& bc_dpto!=1 & bc_anio==2022
replace	bc_ipc_nuevo=	0.391711387 if bc_mes==10 & bc_dpto!=1 & bc_anio==2022
replace	bc_ipc_nuevo=	0.391037422 if bc_mes==11 & bc_dpto!=1 & bc_anio==2022
replace	bc_ipc_nuevo=	0.392243024 if bc_mes==12 & bc_dpto!=1 & bc_anio==2022
replace	bc_ipc_nuevo=	0.393250234 if bc_mes==1 & bc_dpto!=1 & bc_anio==2023
replace	bc_ipc_nuevo=	0.386775846 if bc_mes==2 & bc_dpto!=1 & bc_anio==2023
replace	bc_ipc_nuevo=	0.383113328 if bc_mes==3 & bc_dpto!=1 & bc_anio==2023
replace	bc_ipc_nuevo=	0.380034309 if bc_mes==4 & bc_dpto!=1 & bc_anio==2023
replace	bc_ipc_nuevo=	0.377116591 if bc_mes==5 & bc_dpto!=1 & bc_anio==2023
replace	bc_ipc_nuevo=	0.376977417 if bc_mes==6 & bc_dpto!=1 & bc_anio==2023
replace	bc_ipc_nuevo=	0.379271146 if bc_mes==7 & bc_dpto!=1 & bc_anio==2023
replace	bc_ipc_nuevo=	0.381343593 if bc_mes==8 & bc_dpto!=1 & bc_anio==2023

cap drop bc_ipc_tot
g bc_ipc_tot=.
replace	bc_ipc_tot= 0.43118105 if bc_mes==1 & bc_anio==2018
replace	bc_ipc_tot= 0.41979136 if bc_mes==2 & bc_anio==2018
replace	bc_ipc_tot= 0.41613509 if bc_mes==3 & bc_anio==2018
replace	bc_ipc_tot= 0.41497665 if bc_mes==4 & bc_anio==2018
replace	bc_ipc_tot= 0.41469958 if bc_mes==5 & bc_anio==2018
replace	bc_ipc_tot= 0.41135800 if bc_mes==6 & bc_anio==2018
replace	bc_ipc_tot= 0.40733389 if bc_mes==7 & bc_anio==2018
replace	bc_ipc_tot= 0.40492180 if bc_mes==8 & bc_anio==2018
replace	bc_ipc_tot= 0.40221227 if bc_mes==9 & bc_anio==2018
replace	bc_ipc_tot= 0.40022529 if bc_mes==10 & bc_anio==2018
replace	bc_ipc_tot= 0.39930331 if bc_mes==11 & bc_anio==2018
replace	bc_ipc_tot= 0.39785393 if bc_mes==12 & bc_anio==2018
replace	bc_ipc_tot= 0.39938890 if bc_mes==1 & bc_anio==2019
replace	bc_ipc_tot= 0.39090552 if bc_mes==2 & bc_anio==2019
replace	bc_ipc_tot= 0.38712905 if bc_mes==3 & bc_anio==2019
replace	bc_ipc_tot= 0.38500933 if bc_mes==4 & bc_anio==2019
replace	bc_ipc_tot= 0.38336568 if bc_mes==5 & bc_anio==2019
replace	bc_ipc_tot= 0.38185335 if bc_mes==6 & bc_anio==2019
replace	bc_ipc_tot= 0.37942352 if bc_mes==7 & bc_anio==2019
replace	bc_ipc_tot= 0.37654823 if bc_mes==8 & bc_anio==2019
replace	bc_ipc_tot= 0.37324831 if bc_mes==9 & bc_anio==2019
replace	bc_ipc_tot= 0.37133298 if bc_mes==10 & bc_anio==2019
replace	bc_ipc_tot= 0.36856033 if bc_mes==11 & bc_anio==2019
replace	bc_ipc_tot= 0.36701771 if bc_mes==12 & bc_anio==2019
replace	bc_ipc_tot= 0.36712617 if bc_mes==1 & bc_anio==2020
replace	bc_ipc_tot= 0.35959838 if bc_mes==2 & bc_anio==2020
replace	bc_ipc_tot= 0.35740844 if bc_mes==3 & bc_anio==2020
replace	bc_ipc_tot= 0.35270659 if bc_mes==4 & bc_anio==2020
replace	bc_ipc_tot= 0.34580104 if bc_mes==5 & bc_anio==2020
replace	bc_ipc_tot= 0.34385475 if bc_mes==6 & bc_anio==2020
replace	bc_ipc_tot= 0.34379131 if bc_mes==7 & bc_anio==2020
replace	bc_ipc_tot= 0.34191456 if bc_mes==8 & bc_anio==2020
replace	bc_ipc_tot= 0.33996513 if bc_mes==9 & bc_anio==2020
replace	bc_ipc_tot= 0.33780799 if bc_mes==10 & bc_anio==2020
replace	bc_ipc_tot= 0.33585957 if bc_mes==11 & bc_anio==2020
replace	bc_ipc_tot= 0.33490881 if bc_mes==12 & bc_anio==2020
replace	bc_ipc_tot= 0.335542051 if bc_mes==1 & bc_anio==2021
replace	bc_ipc_tot= 0.330249262 if bc_mes==2 & bc_anio==2021
replace	bc_ipc_tot= 0.327549795 if bc_mes==3 & bc_anio==2021
replace	bc_ipc_tot= 0.32554687  if bc_mes==4 & bc_anio==2021
replace	bc_ipc_tot= 0.323919843 if bc_mes==5 & bc_anio==2021
replace	bc_ipc_tot= 0.322448435 if bc_mes==6 & bc_anio==2021
replace	bc_ipc_tot= 0.320314392 if bc_mes==7 & bc_anio==2021
replace	bc_ipc_tot= 0.318657357 if bc_mes==8 & bc_anio==2021
replace	bc_ipc_tot= 0.31596912  if bc_mes==9 & bc_anio==2021
replace	bc_ipc_tot= 0.314515807 if bc_mes==10 & bc_anio==2021
replace	bc_ipc_tot= 0.31128448  if bc_mes==11 & bc_anio==2021
replace	bc_ipc_tot= 0.310493463 if bc_mes==12 & bc_anio==2021
replace	bc_ipc_tot= 0.310804203 if bc_mes==1 & bc_anio==2022
replace	bc_ipc_tot= 0.305354401 if bc_mes==2 & bc_anio==2022
replace	bc_ipc_tot= 0.300928439 if bc_mes==3 & bc_anio==2022
replace	bc_ipc_tot= 0.297635795 if bc_mes==4 & bc_anio==2022
replace	bc_ipc_tot= 0.296181029 if bc_mes==5 & bc_anio==2022
replace	bc_ipc_tot= 0.294810362 if bc_mes==6 & bc_anio==2022
replace	bc_ipc_tot= 0.293094596 if bc_mes==7 & bc_anio==2022
replace	bc_ipc_tot= 0.290852868 if bc_mes==8 & bc_anio==2022
replace	bc_ipc_tot= 0.288466429 if bc_mes==9 & bc_anio==2022
replace	bc_ipc_tot= 0.286063926 if bc_mes==10 & bc_anio==2022
replace	bc_ipc_tot= 0.28546134  if bc_mes==11 & bc_anio==2022
replace	bc_ipc_tot= 0.286262936 if bc_mes==12 & bc_anio==2022
replace	bc_ipc_tot= 0.286995721 if bc_mes==1 & bc_anio==2023
replace	bc_ipc_tot= 0.282605309 if bc_mes==2 & bc_anio==2023
replace	bc_ipc_tot= 0.279798078 if bc_mes==3 & bc_anio==2023
replace	bc_ipc_tot= 0.277298982 if bc_mes==4 & bc_anio==2023
replace	bc_ipc_tot= 0.275240151 if bc_mes==5 & bc_anio==2023
replace	bc_ipc_tot= 0.275267734 if bc_mes==6 & bc_anio==2023
replace	bc_ipc_tot= 0.276549203 if bc_mes==7 & bc_anio==2023
replace	bc_ipc_tot= 0.277553197 if bc_mes==8 & bc_anio==2023


*-------------------------------------------------------------------------------
* BPC

cap drop bpc
gen bpc=.
replace bpc = 5660 if bc_mes>1	& bc_anio==2023
replace bpc = 5164 if bc_mes==1	& bc_anio==2023
replace bpc = 5164 if bc_mes>1	& bc_anio==2022
replace bpc = 4870 if bc_mes==1	& bc_anio==2022
replace bpc = 4870 if bc_mes>1	& bc_anio==2021
replace bpc = 4519 if bc_mes==1	& bc_anio==2021
replace bpc = 4519 if bc_mes>1	& bc_anio==2020
replace bpc = 4154 if bc_mes==1	& bc_anio==2020
replace bpc = 4154 if bc_mes>1	& bc_anio==2019
replace bpc = 3848 if bc_mes==1 & bc_anio==2019
replace bpc = 3848 if bc_mes>1  & bc_anio==2018
replace bpc = 3611 if bc_mes==1 & bc_anio==2018
replace bpc = 3611 if bc_mes>1  & bc_anio==2017
replace bpc = 3340 if bc_mes==1 & bc_anio==2017
replace bpc = 3340 if bc_mes>1  & bc_anio==2016
replace bpc = 3052 if bc_mes==1 & bc_anio==2016
replace bpc = 3052 if bc_mes>1  & bc_anio==2015
replace bpc = 2819 if bc_mes==1 & bc_anio==2015
replace bpc = 2819 if bc_mes>1  & bc_anio==2014
replace bpc = 2598 if bc_mes==1 & bc_anio==2014
replace bpc = 2598 if bc_mes>1  & bc_anio==2013
replace bpc = 2417 if bc_mes==1 & bc_anio==2013
replace bpc = 2417 if bc_mes>1  & bc_anio==2012
replace bpc = 2226 if bc_mes==1 & bc_anio==2012
replace bpc = 2226 if bc_mes>1  & bc_anio==2011
replace bpc = 2061 if bc_mes==1 & bc_anio==2011
replace bpc = 2061 if bc_mes>1  & bc_anio==2010
replace bpc = 1944 if bc_mes==1 & bc_anio==2010
replace bpc = 1944 if bc_mes>1  & bc_anio==2009
replace bpc = 1775 if bc_mes==1 & bc_anio==2009
replace bpc = 1775 if bc_mes>1  & bc_anio==2008
replace bpc = 1636 if bc_mes==1 & bc_anio==2008
replace bpc = 1636 if bc_mes>1  & bc_anio==2007
replace bpc = 1482 if bc_mes==1 & bc_anio==2007
replace bpc = 1482 if bc_mes>1  & bc_anio==2006
replace bpc = 1397 if bc_mes==1 & bc_anio==2006

*-------------------------------------------------------------------------------
* Drop servicio doméstico
preserve
keep if e30==14

destring d8_3, replace
destring g144_1 g261 g261_1, replace force
recode g144_1 g261 g261_1 (.=0)
save "$rutainterm/servdom22.dta", replace
restore
drop if e30==14
