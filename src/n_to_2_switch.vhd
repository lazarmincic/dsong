library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.voter_pkg.all;
use work.util_pkg.all;

entity n_to_2_switch is
    generic (
        NUM_VOTER_PAIRS : positive;  -- broj parova glasača
        DATA_WIDTH : positive  -- širina podataka glasača
    );
    port (
        -- izlazi iz svih glasača
        pair_outputs : in  std_logic_vector_array(0 to NUM_VOTER_PAIRS - 1)(DATA_WIDTH - 1 downto 0);
        pair_errors : in std_logic_vector(0 to NUM_VOTER_PAIRS - 1);
        -- izlaz
        sel_output : out std_logic_vector(DATA_WIDTH - 1 downto 0)
      
    );
end entity n_to_2_switch;

architecture rtl of n_to_2_switch is
begin 
    process(pair_outputs, pair_errors)
    begin
        sel_output <= pair_outputs(0); -- fallback

        for i in 0 to NUM_VOTER_PAIRS - 1 loop
            if pair_errors(i) = '0' then
                sel_output <= pair_outputs(i);
                exit;  
            end if;
        end loop;
    end process;

end architecture rtl;