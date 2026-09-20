
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
 
entity fifo is
    generic (
        DATA_WIDTH : natural := 2*24;
        DEPTH : integer := 40
    );
    port (
        rst : in std_logic;
        clk      : in std_logic;
        
        -- citanje
        wr_en   : in  std_logic;
        din : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        full    : out std_logic;
        
        -- pisanje
        rd_en   : in  std_logic;
        dout : out std_logic_vector(DATA_WIDTH-1 downto 0);
        empty   : out std_logic
    );
end fifo;
 
architecture rtl of fifo is
 
    type fifo_data_t is array (0 to DEPTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal fifo_data : fifo_data_t := (others => (others => '0'));
    
    signal wr_idx   : integer range 0 to DEPTH-1 := 0;
    signal rd_idx   : integer range 0 to DEPTH-1 := 0;
    
    signal count  : integer range 0 to DEPTH   := 0;
    
    signal is_full  : std_logic;
    signal is_empty : std_logic;
   
begin

    is_full <= '1' when count = DEPTH else '0';
    is_empty <= '1' when count = 0  else '0';
    
    full <= is_full;
    empty <= is_empty;
    
    -- FWFT
    dout <= fifo_data(rd_idx);
 
    process (clk) is
        variable v_count : integer range 0 to DEPTH;
    begin
        if rising_edge(clk) then
            if rst = '0' then
                count  <= 0;
                wr_idx   <= 0;
                rd_idx   <= 0;
            else 
            
            v_count := count;
        
            -- upis
            if (wr_en = '1' and is_full = '0') then
                fifo_data(wr_idx) <= din;
                if wr_idx = DEPTH-1 then
                    wr_idx <= 0;
                else
                    wr_idx <= wr_idx + 1;
                end if;
                v_count := v_count + 1;
            end if;
        
            -- pop
            if (rd_en = '1' and is_empty = '0') then
                if rd_idx = DEPTH-1 then
                    rd_idx <= 0;
                else
                    rd_idx <= rd_idx + 1;
                end if;
                v_count := v_count - 1;
            end if;
             
            count <= v_count;
             
            end if;
        end if; 
    end process;
    
end rtl;