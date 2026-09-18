library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use ieee.math_real.all;
use std.textio.all;

use work.voter_pkg.all;
use work.txt_util.all;
use work.util_pkg.all;

entity fir_filter_ft_tb is
    generic (
        FILTER_ORDER : positive := 20;
        IN_WIDTH     : positive := 24;
        OUT_WIDTH    : positive := 24;
        
        MAC_NUM : positive := 3;
        VOTER_PAIR_NUM : positive := 3
    );
end entity fir_filter_ft_tb;

architecture behavioral of fir_filter_ft_tb is

    constant PERIOD : time := 10 ns; -- (100MHz+)

    signal clk           : std_logic := '0';
    signal reset         : std_logic := '0';
    
    signal in_tdata  : std_logic_vector(IN_WIDTH - 1 downto 0) := (others => '0');
    signal in_tvalid : std_logic := '0';
    signal in_tready : std_logic;
    signal in_tlast  : std_logic := '0';
    
    signal out_tdata  : std_logic_vector(OUT_WIDTH - 1 downto 0);
    signal out_tvalid : std_logic;
    signal out_tready : std_logic := '0';
    signal out_tlast  : std_logic;
    
    signal write_en : std_logic := '0';
    signal coef_addr_i : std_logic_vector(log2c(FILTER_ORDER+1)-1 downto 0);
    signal coef_i : STD_LOGIC_VECTOR (IN_WIDTH-1 downto 0);

    -- Datoteke (po potrebi podesiti odgovarajuće putanje)
    file input_test_vector   : text open read_mode is "input.txt";
    file output_check_vector : text open read_mode is "expected.txt";
    file input_coef          : text open read_mode is "coef.txt";
    
    constant LATENCY : natural := FILTER_ORDER + 4;
    
    

begin

    -- top modul
    uut : entity work.fir_filter_ft
        generic map (
            FILTER_ORDER => FILTER_ORDER,
            IN_WIDTH => IN_WIDTH,
            OUT_WIDTH => OUT_WIDTH,
            MAC_NUM => MAC_NUM,
            VOTER_PAIR_NUM => VOTER_PAIR_NUM 
        )
        port map (
            clk => clk,
            reset => reset,
            in_tdata => in_tdata,
            in_tvalid => in_tvalid,
            in_tready => in_tready,
            in_tlast => in_tlast,
            out_tdata => out_tdata,
            out_tvalid => out_tvalid,
            out_tready => out_tready,
            out_tlast => out_tlast,
            write_en => write_en,
            coef_addr_i => coef_addr_i,
            coef_i => coef_i
        );

    -- generator takta
    clk_process : process
    begin
        clk <= '0';
        wait for PERIOD / 2;
        clk <= '1';
        wait for PERIOD / 2;
    end process;
    
    m_ready_gen_process : process
        variable seed1, seed2 : positive := 1234;
        variable rand         : real;
    begin
        wait until reset = '1';
        while true loop
            wait until falling_edge(clk);
            uniform(seed1, seed2, rand);
            -- ~70% vremena ready je '1', ~30% vremena pravi backpressure ('0')
            if rand > 0.3 then
                out_tready <= '1';
            else
                out_tready <= '0';
            end if;
        end loop;
    end process;

    -- stimulus
    stim_process : process
        variable tv : line;
        variable seed1, seed2 : positive := 5678;
        variable rand  : real;
    begin
        -- reset sekvenca
        reset <= '0';
        wait for PERIOD * 5;
        wait until falling_edge(clk);
        reset <= '1';
    
        --upis koeficijenata
        in_tdata <= (others=>'0');
        wait until falling_edge(clk);
        for i in 0 to FILTER_ORDER loop
            write_en <= '1';
            coef_addr_i <= std_logic_vector(to_unsigned(i,log2c(FILTER_ORDER+1)));
            readline(input_coef,tv);
            coef_i <= to_std_logic_vector(string(tv));
            wait until falling_edge(clk);
        end loop;
    
        wait for PERIOD * 2;
    
        -- slanje ulaznih odbiraka
        while not endfile(input_test_vector) loop
            wait until falling_edge(clk);
            
            -- Povremeno pauziraj slanje 
            uniform(seed1, seed2, rand);
            if rand < 0.2 then
                in_tvalid <= '0';
                wait for PERIOD * 2;
                wait until falling_edge(clk);
            end if;
        
            readline(input_test_vector, tv);
            in_tdata  <= to_std_logic_vector(string(tv));
            in_tvalid <= '1';
            
            if endfile(input_test_vector) then
                in_tlast <= '1';
            else
                in_tlast <= '0';
            end if;
            
            -- Čekaj na uzlaznoj ivici i proveri da li je prihvaćen
            loop
                wait until rising_edge(clk);
                -- Ako je in_tready bio '1' dok je in_tvalid bio '1', handshake je uspeo!
                if in_tready = '1' then
                    exit;
                end if;
            end loop;
        end loop;
    
        wait until falling_edge(clk);
        in_tvalid <= '0';
        in_tlast  <= '0';
    
        -- čekanje da izlazni podaci prođu kroz pipeline
        wait for PERIOD * LATENCY;
        report "VERIFIKACIJA USPESNO ZAVRSENA!" severity note;
        wait;
    end process;

    -- provera izlaza
    check_process : process
        variable check_v : line;
        variable expected_val : std_logic_vector(OUT_WIDTH - 1 downto 0);
        variable diff : signed (OUT_WIDTH - 1 downto 0);
    begin
        
        while true loop
            wait until rising_edge(clk);
            
            if out_tvalid = '1' and out_tready = '1' then
                if not endfile(output_check_vector) then
                    readline(output_check_vector, check_v);
                    expected_val := to_std_logic_vector(string(check_v));

                    if(abs(signed(expected_val) - signed(out_tdata)) > "000000000000000000000111") then
                        report "Result mismatch! " &
                               "Expected: 0x" & to_hstring(expected_val) & 
                               " | Got: 0x" & to_hstring(out_tdata)
                        severity error;
                    end if;
                end if;
            end if;
        end loop;
    end process;
    
    axi_master_checker : process
        variable prev_data : std_logic_vector(OUT_WIDTH - 1 downto 0);
        variable prev_last : std_logic;
        variable was_stalled : boolean := false;
    begin
        wait until rising_edge(clk);
        
        -- Ako je u prošlom taktu bio validan podatak koji NIJE preuzet
        if was_stalled then
            assert out_tvalid = '1' 
                report "AXI VIOLATION: out_tvalid pao na 0 pre TREADY-ja!" severity failure;
            assert out_tdata = prev_data 
                report "AXI VIOLATION: out_tdata se promenio pre TREADY-ja!" severity failure;
            assert out_tlast = prev_last 
                report "AXI VIOLATION: out_tlast se promenio pre TREADY-ja!" severity failure;
        end if;
    
        -- Proveri trenutno stanje na novoj ivici
        if out_tvalid = '1' and out_tready = '0' then
            was_stalled := true;
            prev_data   := out_tdata;
            prev_last   := out_tlast;
        else
            was_stalled := false;
        end if;
    end process;

end architecture behavioral;