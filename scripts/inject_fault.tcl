# SA1 na izlazu nulte MAC jedinice nultog stepena

# MAC jedinice
# 0 0
add_force {/fir_filter_ft_tb/uut/\GEN_FIR_STAGES(0)\/stage_inst/\gen_mac_units(0)\/mac_inst/acc_o} -radix hex {111111111111 0us} -cancel_after 2.2us
# 0 1
#add_force {/fir_filter_ft_tb/uut/\GEN_FIR_STAGES(0)\/stage_inst/\gen_mac_units(1)\/mac_inst/acc_o} -radix hex {111111111111 0us} -cancel_after 2.2us
# 0 2
#add_force {/fir_filter_ft_tb/uut/\GEN_FIR_STAGES(0)\/stage_inst/\gen_mac_units(2)\/mac_inst/acc_o} -radix hex {111111111111 0us} -cancel_after 2.2us

# glasači
# 0 a
add_force {/fir_filter_ft_tb/uut/\GEN_FIR_STAGES(0)\/stage_inst/voter_inst/\gen_pairs(0)\/pair_inst/voter_a/output} -radix hex {111111111111 0us} -cancel_after 2.2us
# 0 b
#add_force {/fir_filter_ft_tb/uut/\GEN_FIR_STAGES(0)\/stage_inst/voter_inst/\gen_pairs(0)\/pair_inst/voter_b/output} -radix hex {111111111111 0us} -cancel_after 2.2us
# 1 a
#add_force {/fir_filter_ft_tb/uut/\GEN_FIR_STAGES(0)\/stage_inst/voter_inst/\gen_pairs(1)\/pair_inst/voter_a/output} -radix hex {111111111111 0us} -cancel_after 2.2us
# 1 b
add_force {/fir_filter_ft_tb/uut/\GEN_FIR_STAGES(0)\/stage_inst/voter_inst/\gen_pairs(1)\/pair_inst/voter_b/output} -radix hex {111111111111 0us} -cancel_after 2.2us
# 2 a
#add_force {/fir_filter_ft_tb/uut/\GEN_FIR_STAGES(0)\/stage_inst/voter_inst/\gen_pairs(2)\/pair_inst/voter_a/output} -radix hex {111111111111 0us} -cancel_after 2.2us
# 2 b
#add_force {/fir_filter_ft_tb/uut/\GEN_FIR_STAGES(0)\/stage_inst/voter_inst/\gen_pairs(2)\/pair_inst/voter_b/output} -radix hex {111111111111 0us} -cancel_after 2.2us

# ispis u konzoli
puts "TCL: Ubacivanje kvara u MAC[0] uspesno izvrseno u intervalu od 0us do 2.2us."

#