* Variable range expansion in recode
gen suma1 = 10
gen suma2 = 20
gen suma3 = 30
gen suma4 = .
recode suma1-suma4 (.=0)

* Variable range in mvencode
mvencode suma1-suma4, mv(0) override
