library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity mac_unit is
    generic (
        SAMPLE_WIDTH  : natural
    );
    port (
        clk_i : in  std_logic;
        rst_i : in std_logic;
        sample_i : in std_logic_vector(SAMPLE_WIDTH-1 downto 0);
        coeff_i : in std_logic_vector(SAMPLE_WIDTH-1 downto 0);
        acc_i : in std_logic_vector(SAMPLE_WIDTH*2-1 downto 0);
        acc_o : out std_logic_vector(SAMPLE_WIDTH*2-1 downto 0);
        
        clk_en : in std_logic
    );
end entity mac_unit;

architecture rtl of mac_unit is

    attribute use_dsp : string;
    attribute use_dsp of rtl : architecture is "yes";

    signal acc_i_s : std_logic_vector(2*SAMPLE_WIDTH-1 downto 0) := (others => '0');
    signal mult_s : std_logic_vector(2*SAMPLE_WIDTH-1 downto 0) := (others => '0');
    signal acc_s : std_logic_vector(2*SAMPLE_WIDTH-1 downto 0) := (others => '0');

    signal sample_i_s : std_logic_vector(SAMPLE_WIDTH-1 downto 0);
    signal coeff_i_s : std_logic_vector(SAMPLE_WIDTH-1 downto 0);
    
    attribute KEEP_HIERARCHY  : string;
    attribute KEEP_HIERARCHY of rtl : architecture is "SOFT";

begin

    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '0' then  -- AXI reset aktivan na '0'
                mult_s <= (others => '0');
                acc_s <= (others => '0');
                acc_i_s <= (others => '0');
                sample_i_s <= (others => '0');
                coeff_i_s <= (others => '0');
            elsif clk_en = '1' then
                -- Ulazni registri
                acc_i_s <= acc_i;
                sample_i_s <= sample_i;
                coeff_i_s <= coeff_i;
                
                -- množenje
                mult_s <= std_logic_vector(signed(sample_i_s) * signed(coeff_i_s));
                
                -- sabiranje
                acc_s <= std_logic_vector(signed(mult_s) + signed(acc_i_s));
                
            end if;
        end if;
    end process;
    
    -- 
    acc_o <= acc_s;

end architecture rtl;