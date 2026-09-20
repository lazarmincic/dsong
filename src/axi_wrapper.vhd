library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.util_pkg.all;
use work.voter_pkg.all;  

entity axi_wrapper is
    generic (
        FILTER_ORDER : positive := 20;
        IN_WIDTH : positive := 24;
        OUT_WIDTH : positive := 24
        );
    port (
        clk : in  std_logic;
        reset : in  std_logic; -- aktivan na '0'
        
        -- axi stream slave
        in_tdata    : in  std_logic_vector(IN_WIDTH - 1 downto 0);
        in_tvalid   : in  std_logic;
        in_tready   : out std_logic;
        in_tlast    : in  std_logic;
        
        -- axi stream master
        out_tdata    : out std_logic_vector(OUT_WIDTH - 1 downto 0);
        out_tvalid   : out std_logic;
        out_tready   : in  std_logic;
        out_tlast    : out std_logic;
        
        write_en : in std_logic;
        coef_addr_i : std_logic_vector(log2c(FILTER_ORDER+1)-1 downto 0);
        coef_i : in STD_LOGIC_VECTOR (IN_WIDTH-1 downto 0)
        
        );
end entity axi_wrapper;

architecture rtl of axi_wrapper is
    
    signal coeffs : std_logic_vector_array (FILTER_ORDER downto 0)(IN_WIDTH-1 downto 0) := (others=>(others=>'0')); 
    
        -- ulazni FIFO
    signal in_fifo_full  : std_logic;
    signal in_fifo_empty : std_logic;
    signal in_fifo_rd_en : std_logic;
    signal in_fifo_dout  : std_logic_vector(IN_WIDTH downto 0);

    -- izlazni FIFO
    signal out_fifo_full        : std_logic;
    signal out_fifo_empty       : std_logic;
    signal out_fifo_wr_en       : std_logic;
    signal out_fifo_din         : std_logic_vector(OUT_WIDTH downto 0);
    signal out_fifo_dout         : std_logic_vector(OUT_WIDTH downto 0);
    
    constant FIFO_DEPTH : positive := (FILTER_ORDER + 2)*2;
    -- vazi samo za izlazni fifo, ulazni ne mora biti toliko dubok
    
    signal pipeline_en : std_logic;
    signal valid_o : std_logic;
    signal valid_i: std_logic;
    
    signal flush_pipeline : std_logic;
    
    signal fir_input: std_logic_vector (IN_WIDTH-1 downto 0);
    
    signal last_i: std_logic;
    
begin

    -- fsm - eventualno moze da se doda.

    -- memorija za koeficijente
    process(clk)
    begin
        if rising_edge(clk) then
            if write_en = '1' then
                coeffs(to_integer(unsigned(coef_addr_i))) <= coef_i;
            end if;
        end if;
    end process;
    
    -- modul
     
    fir_inst: entity work.fir_filter_ft
        generic map (
            FILTER_ORDER => FILTER_ORDER,
            IN_WIDTH => IN_WIDTH,
            OUT_WIDTH => OUT_WIDTH
        )
        port map (
            clk => clk,
            reset => reset,
            input => fir_input,
            output => out_fifo_din(OUT_WIDTH-1 downto 0),
            coeffs => coeffs,
            valid_i => valid_i,
            valid_o => valid_o,
            last_i => last_i,
            last_o => out_fifo_din(OUT_WIDTH),
            clk_en => pipeline_en,
            last_in_pipeline => flush_pipeline
        );
        
     fir_input <= in_fifo_dout(IN_WIDTH-1 downto 0) when flush_pipeline = '0' else (others => '0');
     
     last_i <= in_fifo_dout (IN_WIDTH) and not flush_pipeline;
        
     valid_i <= not in_fifo_empty;
          
     -- ulazni fifo
     in_fifo_inst : entity work.fifo
        generic map (
            DATA_WIDTH => IN_WIDTH + 1, -- za last
            DEPTH => 2 -- mala da bi se u verifikaciji desilo da se napuni.
        )
        port map (  
            clk => clk,
            rst => reset,
            din => in_tlast & in_tdata,
            wr_en => in_tvalid and (not in_fifo_full),
            full => in_fifo_full,
            dout => in_fifo_dout,
            rd_en => in_fifo_rd_en,
            empty  => in_fifo_empty
        );
        
    -- izlazni fifo
    
    out_fifo_inst : entity work.fifo
        generic map (
            DATA_WIDTH => OUT_WIDTH + 1,
            DEPTH => FIFO_DEPTH
        )
        port map (
            clk => clk,
            rst => reset,
            din => out_fifo_din,
            wr_en => out_fifo_wr_en,
            full => out_fifo_full,
            dout => out_fifo_dout,
            rd_en => out_tready and (not out_fifo_empty),
            empty => out_fifo_empty
        );
    
    --axi
    out_tdata <= out_fifo_dout(OUT_WIDTH-1 downto 0);
    
    out_tlast <= out_fifo_dout(OUT_WIDTH) and not out_fifo_empty;
    
    in_tready <= not in_fifo_full; 
    
    in_fifo_rd_en <= pipeline_en and not flush_pipeline;    
    
    pipeline_en <= not out_fifo_full and (not in_fifo_empty or flush_pipeline);
    
    out_tvalid <= not out_fifo_empty; 
                         
    out_fifo_wr_en <= valid_o and pipeline_en;
    

end architecture rtl;