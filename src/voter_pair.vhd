library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.voter_pkg.all;

entity voter_pair is
    generic (
        NUM_INPUTS : positive;  -- broj ulaza glasača (broj mac jedinica)
        DATA_WIDTH : positive  -- širina ulaznih podataka (izlaz iz mac jedinice)
    );
    port (
        inputs : in std_logic_vector_array(0 to NUM_INPUTS - 1)(DATA_WIDTH - 1 downto 0);
        output : out std_logic_vector(DATA_WIDTH - 1 downto 0);
        -- izlazni signal greške
        error_detected : out std_logic;
        
        clk: in std_logic;
        rst: in std_logic;
        clk_en : in std_logic
    );
end entity voter_pair;

architecture rtl of voter_pair is
    signal out_a : std_logic_vector(DATA_WIDTH - 1 downto 0);
    signal out_b : std_logic_vector(DATA_WIDTH - 1 downto 0);
begin

    voter_a: entity work.majority_voter
        generic map (
            NUM_INPUTS => NUM_INPUTS,
            DATA_WIDTH => DATA_WIDTH
        )
        port map (
            inputs => inputs,
            output => out_a,
            clk => clk,
            rst => rst,
            clk_en => clk_en
        );

    voter_b : entity work.majority_voter
        generic map (
            NUM_INPUTS => NUM_INPUTS,
            DATA_WIDTH => DATA_WIDTH
        )
        port map (
            inputs => inputs,
            output => out_b,
            clk => clk,
            rst => rst,
            clk_en => clk_en
        );

    -- komparator
    error_detected <= '0' when (out_a = out_b) else '1';
    output <= out_a;

end architecture rtl;