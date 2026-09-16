library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.voter_pkg.all;

entity majority_voter is
    generic (
        NUM_INPUTS : positive := 3;  -- broj ulaznih (mac) modula
        DATA_WIDTH : positive := 2*24  -- širina ulaznih podataka (izlazi iz mac jedinice)
    );
    port (
        inputs : in  std_logic_vector_array (0 to NUM_INPUTS - 1)(DATA_WIDTH - 1 downto 0);
        output : out std_logic_vector(DATA_WIDTH - 1 downto 0)
    );
end entity majority_voter;

architecture rtl of majority_voter is
    function count_matches(val : std_logic_vector; arr : std_logic_vector_array) return natural is
        variable count : natural := 0;
    begin
        for k in arr'range loop
            if arr(k) = val then
                count := count + 1;
            end if;
        end loop;
        return count;
    end function;
begin

    process(inputs)
    begin
        -- Podrazumevana vrednost ako nema većine
        output <= inputs(0);
        
        for i in inputs'range loop
            if count_matches(inputs(i), inputs) > (NUM_INPUTS / 2) then
                output <= inputs(i);
            end if;
        end loop;
        
    end process;

end architecture rtl;