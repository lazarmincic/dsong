# Fault-Tolerant FIR Filter (Zybo Z7-10)

Jedna implementacija Fault-Tolerant FIR filtra u jeziku VHDL. Na MAC jedinice primenjena je NMR FT tehnika a na glasače *Pair-and-a-Spare* FT tehnika.

## Struktura repozitorijuma

* `src/` — Izvorni VHDL kodovi dizajna.
* `tb/` — Testbench fajlovi za simulaciju.
* `constraints/` — XDC fajlovi sa vremenskim ograničenjima za takt.
* `scripts/` — Tcl skripta za rekonstrukciju projekta i unošenje grešaka.
* `matlab/` — Tekstualni fajlovi neophodni za simulaciju i skripta za njihovo generisanje napisana u jeziku MATLAB.

## Rekonstrukcija projekta u Vivadu

Da biste rekreirali kompletan Vivado projekat:

1. Otvorite **Vivado (2024.1)** i pokrenite **Tcl Console** (ili izaberite `Tools -> Run Tcl Script...`).
2. Pokrenite sledeće komande u tcl konzoli:

```tcl
cd <putanja_do_otpakovanog_foldera>/dsong/scripts
source build_project.tcl