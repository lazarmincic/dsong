library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.voter_pkg.all;

entity fir_stage_ft is
    generic (
        MAC_NUM : natural := 3;  -- broj mac jedinica
        VOTER_PAIR_NUM : natural := 3;  -- broj glasača 
        SAMPLE_WIDTH : natural := 24
    ); 
    port (
        clk_i : in  std_logic;
        rst_i : in  std_logic;
        sample_i : in  std_logic_vector(SAMPLE_WIDTH - 1 downto 0);
        coeff_i : in  std_logic_vector(SAMPLE_WIDTH - 1 downto 0);
        acc_i : in  std_logic_vector(2*SAMPLE_WIDTH - 1 downto 0);
         
        acc_o : out std_logic_vector(2*SAMPLE_WIDTH - 1 downto 0);
        
        clk_en: in std_logic
    );
end entity fir_stage_ft;

architecture rtl of fir_stage_ft is

    -- niz izlaza mac jedinica
    type mac_outputs_t is array (0 to MAC_NUM - 1) of std_logic_vector(2*SAMPLE_WIDTH - 1 downto 0);
    signal mac_outputs : mac_outputs_t;

    -- niz ulaza za glasač
    signal voter_inputs : std_logic_vector_array(0 to (VOTER_PAIR_NUM * MAC_NUM) - 1)(2*SAMPLE_WIDTH - 1 downto 0);

begin

    -- NMR
    gen_mac_units : for i in 0 to MAC_NUM - 1 generate
        mac_inst : entity work.mac_unit
            generic map (
                SAMPLE_WIDTH  => SAMPLE_WIDTH
            )
            port map (
                clk_i => clk_i,
                rst_i => rst_i,
                sample_i => sample_i,
                coeff_i => coeff_i,
                acc_i => acc_i,
                acc_o => mac_outputs(i),
                clk_en => clk_en
            );
    end generate gen_mac_units;

    -- ulazi svakog glasača su izlazi svaki mac jedinice 
    gen_voter_input_map : for v in 0 to VOTER_PAIR_NUM - 1 generate
        gen_mac_map : for m in 0 to MAC_NUM - 1 generate
            voter_inputs(v * MAC_NUM + m) <= mac_outputs(m);
        end generate gen_mac_map;
    end generate gen_voter_input_map;

    -- glasač
    voter_inst : entity work.pair_and_a_spare_voter
        generic map (
            NUM_VOTER_PAIRS => VOTER_PAIR_NUM,
            NUM_INPUTS => MAC_NUM, -- broj ulaza svakog glasača je broj MAC jedinica
            DATA_WIDTH => 2*SAMPLE_WIDTH -- širina podataka glasača je širina akumulatora
        )
        port map (
            inputs => voter_inputs,
            output => acc_o
        );

end architecture rtl;