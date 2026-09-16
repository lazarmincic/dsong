library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.voter_pkg.all;

entity pair_and_a_spare_voter is
    generic ( 
        NUM_VOTER_PAIRS : positive := 3;  -- broj parova glasača
        NUM_INPUTS : positive := 3;  -- broj ulaza svakog glasača
        DATA_WIDTH : positive := 2*24  -- širina svakog ulaza
    );
    port (
        inputs : in  std_logic_vector_array(0 to (NUM_VOTER_PAIRS * NUM_INPUTS) - 1)(DATA_WIDTH - 1 downto 0);
        output : out std_logic_vector(DATA_WIDTH - 1 downto 0)
    );
end entity pair_and_a_spare_voter;

architecture rtl of pair_and_a_spare_voter is
    -- signali za povezivanje 
    signal pair_outputs : std_logic_vector_array(0 to NUM_VOTER_PAIRS - 1)(DATA_WIDTH - 1 downto 0);
    signal pair_errors : std_logic_vector(0 to NUM_VOTER_PAIRS - 1);
    
begin

    -- parovi glasaca 
    gen_pairs : for i in 0 to NUM_VOTER_PAIRS - 1 generate
        signal current_pair_inputs : std_logic_vector_array(0 to NUM_INPUTS - 1)(DATA_WIDTH - 1 downto 0);
    begin
    
        -- mapiranje ulaznog niza na i-ti glasac
        gen_inputs : for j in 0 to NUM_INPUTS - 1 generate
            current_pair_inputs(j) <= inputs(i * NUM_INPUTS + j);
        end generate gen_inputs;

        pair_inst : entity work.voter_pair
            generic map ( 
                NUM_INPUTS => NUM_INPUTS,
                DATA_WIDTH => DATA_WIDTH
            )
            port map (
                inputs => current_pair_inputs,
                output => pair_outputs(i),
                error_detected => pair_errors(i)
            );

    end generate gen_pairs;

    -- prekidač
    switch_inst : entity work.n_to_2_switch
        generic map (
            NUM_VOTER_PAIRS => NUM_VOTER_PAIRS,
            DATA_WIDTH => DATA_WIDTH
        )
        port map ( 
            pair_outputs  => pair_outputs,
            pair_errors  => pair_errors,
            sel_output => output
        );
        
end architecture rtl;