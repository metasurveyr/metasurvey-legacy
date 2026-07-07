* recode with gen() option
recode bc_pe6a (2=2) (3=-9) (4=3) (5=4), gen(bc_pe6b)

* simple inline recode (missing to zero)
recode bc_filtloc (0=2)

* recode with ranges
recode bc_edu 23/38=22

* recode missing to zero
recode emerg_otrohog .=0
