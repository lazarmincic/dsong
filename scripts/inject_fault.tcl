
# ideja - nasumicne vrednosti na izlazu modula koji zelimo pokvariti

# promeniti pre simulacije
set pokvari false 

set scope_path "/fir_filter_ft_tb/uut/fir_inst"

set IN_WIDTH [get_value "$scope_path/IN_WIDTH"]
set MAX_FAULT_TOLERANCE [get_value "$scope_path/MAX_FAULT_TOLERANCE"]
set FILTER_ORDER [get_value "$scope_path/FILTER_ORDER"]
set STAGE_NUM [expr {$FILTER_ORDER + 1}]
set MAC_NUM [get_value "$scope_path/MAC_NUM"]
set VOTER_PAIR_NUM [get_value "$scope_path/VOTER_PAIR_NUM"]

set error_num [expr {$pokvari ? $MAX_FAULT_TOLERANCE+1 : $MAX_FAULT_TOLERANCE}]

# prolazi kroz sve stepene filtra
for {set stage_idx 0} {$stage_idx < $STAGE_NUM} {incr stage_idx 1} {

    # prolazi kroz sve mac jedinice
    for {set mac_idx 0} {$mac_idx < $MAC_NUM} {incr mac_idx 1} { 
        
        if {$mac_idx == $error_num} {
            break
        }
    
        if {$stage_idx == 0} {
            set force_path [ format {/fir_filter_ft_tb/uut/fir_inst/gen_stage_0/\gen_mac_units(%d)\/mac_inst/acc_o} $mac_idx]
        } else {
            set force_path [ format {/fir_filter_ft_tb/uut/fir_inst/\gen_stages(%d)\/stage_inst/\gen_mac_units(%d)\/mac_inst/acc_o} $stage_idx $mac_idx]
        }
        
        # generisanje vrednosti za forsiranje za mac jedinicu - badbadbad...

        set bit_len [expr {$IN_WIDTH * 2}]
        # "BAD": B=1011, A=1010, D=1101
        set bad_bin "101110101101"
        
        set force_value ""
        
        while {[string length $force_value] < $bit_len} {
            append force_value $bad_bin
        }
        
        set force_value [string range $force_value 0 [expr {$bit_len - 1}]]
        
        add_force $force_path -radix bin $force_value
    }
        
    # prolazi kroz sve parove glasaca
    for {set pair_idx 0} {$pair_idx < $VOTER_PAIR_NUM} {incr pair_idx 1}  {
    
        # unosi onoliko gresaka koliko je modul tolerantan, i ne vise
        if {$pair_idx == $error_num} {
            break
        }
        
        # biramo a ili b za ubacivanje greske
        set random_num [expr {int(rand() * 2)}]
        if {$random_num == 0} {
            set a_or_b "a"
        } else {
            set a_or_b "b"
        }
        
        # postavljanje hijerarhijske putanje do signala nad kojim vrši forsiranje
        if {$stage_idx == 0} {
            set force_path [ format {/fir_filter_ft_tb/uut/fir_inst/gen_stage_0/voter_inst/\gen_pairs(%d)\/pair_inst/voter_%s/output} $pair_idx $a_or_b]
        } else {
            set force_path [ format {/fir_filter_ft_tb/uut/fir_inst/\gen_stages(%d)\/stage_inst/voter_inst/\gen_pairs(%d)\/pair_inst/voter_%s/output} $stage_idx $pair_idx $a_or_b]
        }
        
        # generisanje vrednosti za forsiranje za voter - deaddeaddead...

        set bit_len [expr {$IN_WIDTH * 2}]
        
        set dead_bin "1101111010101101"
        
        set force_value ""
        
        while {[string length $force_value] < $bit_len} {
            append force_value $dead_bin
        }
        
        set force_value [string range $force_value 0 [expr {$bit_len - 1}]]
        
        add_force $force_path -radix bin $force_value
        
        # forsiranje vrednosti
        add_force $force_path -radix bin $force_value
        
    }
    
}

# ispis u konzoli
if {$error_num < 5} {
    puts "TCL: Ubacivanje $error_num kvara uspesno izvrseno."
} else {
    puts "TCL: Ubacivanje $error_num kvarova uspesno izvrseno."
}

if {$pokvari} {
    puts "TCL: Sistem treba da se pokvari."
} else {
    puts "TCL: Sistem treba da radi kako treba."
}
