library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
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
    
    signal s_axis_tdata  : std_logic_vector(IN_WIDTH - 1 downto 0) := (others => '0');
    signal s_axis_tvalid : std_logic := '0';
    signal s_axis_tready : std_logic;
    signal s_axis_tlast  : std_logic := '0';
    
    signal m_axis_tdata  : std_logic_vector(OUT_WIDTH - 1 downto 0);
    signal m_axis_tvalid : std_logic;
    signal m_axis_tready : std_logic := '1';
    signal m_axis_tlast  : std_logic;
    
    signal write_en : std_logic := '0';
    signal coef_addr_i : std_logic_vector(log2c(FILTER_ORDER+1)-1 downto 0);
    signal coef_i : STD_LOGIC_VECTOR (IN_WIDTH-1 downto 0);

    -- Datoteke (po potrebi podesiti odgovarajuće putanje)
    file input_test_vector   : text open read_mode is "input.txt";
    file output_check_vector : text open read_mode is "expected.txt";
    file input_coef          : text open read_mode is "coef.txt";
    
    constant LATENCY : natural := FILTER_ORDER + 2;

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
            s_axis_tdata => s_axis_tdata,
            s_axis_tvalid => s_axis_tvalid,
            s_axis_tready => s_axis_tready,
            s_axis_tlast => s_axis_tlast,
            m_axis_tdata => m_axis_tdata,
            m_axis_tvalid => m_axis_tvalid,
            m_axis_tready => m_axis_tready,
            m_axis_tlast => m_axis_tlast,
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

    -- stimulus
    stim_process : process
        variable tv : line;
    begin
        -- reset sekvenca
        reset <= '0';
        wait for PERIOD * 5;
        wait until falling_edge(clk);
        reset <= '1';
    
        --upis koeficijenata
        s_axis_tdata <= (others=>'0');
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
    
            readline(input_test_vector, tv);
            s_axis_tdata  <= to_std_logic_vector(string(tv));
            s_axis_tvalid <= '1';
            
            if endfile(input_test_vector) then
                s_axis_tlast <= '1';
            else
                s_axis_tlast <= '0';
            end if;
    
            wait until rising_edge(clk) and s_axis_tready = '1';
        end loop;
    
        wait until falling_edge(clk);
        s_axis_tvalid <= '0';
        s_axis_tlast  <= '0';
    
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
            
            if m_axis_tvalid = '1' and m_axis_tready = '1' then
                if not endfile(output_check_vector) then
                    readline(output_check_vector, check_v);
                    expected_val := to_std_logic_vector(string(check_v));

                    if(abs(signed(expected_val) - signed(m_axis_tdata)) > "000000000000000000000111") then
                        report "result mismatch!" severity error;
                    end if;
                end if;
            end if;
        end loop;
    end process;

end architecture behavioral;