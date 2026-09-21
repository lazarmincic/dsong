library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.voter_pkg.all;

entity majority_voter is
    generic (
        NUM_INPUTS : positive;  -- broj ulaznih (mac) modula
        DATA_WIDTH : positive  -- širina ulaznih podataka (izlazi iz mac jedinice)
    );
    port (
        inputs : in  std_logic_vector_array (0 to NUM_INPUTS - 1)(DATA_WIDTH - 1 downto 0);
        output : out std_logic_vector(DATA_WIDTH - 1 downto 0);
        
        clk: in std_logic;
        rst: in std_logic;
        clk_en : in std_logic
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
    
    signal output_s : std_logic_vector(DATA_WIDTH - 1 downto 0);
    signal comb_o: std_logic_vector(DATA_WIDTH - 1 downto 0);
    
    attribute KEEP_HIERARCHY  : string;
    attribute KEEP_HIERARCHY of rtl : architecture is "SOFT";
    
begin

    process(inputs)
    begin
        -- Podrazumevana vrednost ako nema većine
        comb_o <= inputs(0);
        
        for i in inputs'range loop
            if count_matches(inputs(i), inputs) > (NUM_INPUTS / 2) then
                comb_o <= inputs(i);
            end if;
        end loop;
        
    end process;
    
    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '0' then
                output_s <= (others => '0');
            elsif clk_en = '1' then
                output_s <= comb_o;
            end if;
        end if;
    end process;
    
    output <= output_s;

end architecture rtl;