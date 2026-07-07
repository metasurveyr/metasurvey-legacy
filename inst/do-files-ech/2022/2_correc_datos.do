*-------------------------------------------------------------------------------
* Base original

u "$ruta\originales/p22", clear

*-------------------------------------------------------------------------------
* Se renombran variables del ine (para variables de ingreso se deshace el rename
* en paso 8.)
cap rename ytdop ine_ytdop
cap rename ytdos ine_ytdos
cap rename ytinde ine_ytinde
cap rename ytransf ine_ytransf
cap rename pt1 ine_pt1
cap rename pt2 ine_pt2
cap rename pt4 ine_pt4
cap rename ht13 ine_ht13
cap rename yhog ine_yhog
cap rename ysvl ine_ysvl
cap rename ysvl_sag ine_ysvl_sag
cap rename ypat_tot ine_ypat_tot
cap rename ytot_sinagui ine_ytot_sinagui
cap rename ypas_tot ine_ypas_tot
cap rename mes bc_mes
cap rename anio bc_anio
cap replace bc_anio=2021 if bc_anio==.
cap rename dpto bc_dpto
cap rename ccz bc_ccz
cap rename INDAEMER indaemer
recode bc_ccz (0=-9)

cap recode mto_cuot (.=0)
cap recode mto_emer (.=0)
cap recode mto_hogc (.=0)

*-------------------------------------------------------------------------------
* Recodificación de datos

*-------------------------------------------------------------------------------
* Cambios de variables
destring region_4, replace
destring bc_dpto, replace
destring bc_mes, replace
destring bc_anio, replace
destring bc_ccz, replace
cap destring f72_2, replace force
cap destring f91_2, replace
cap destring f71_2, replace force
