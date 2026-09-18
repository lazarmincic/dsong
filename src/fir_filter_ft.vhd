library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.util_pkg.all;

entity fir_filter_ft is
    generic (
        FILTER_ORDER : positive := 20; -- red filtra (stepen filtra je FILTER_ORDER + 1)
        IN_WIDTH : positive := 24; -- širina ulaznih podataka (umnožak 8)
        OUT_WIDTH : positive := 24; -- širina izlaznih podataka (umnožak 8)
 
        MAC_NUM : positive := 3;  -- broj MAC jedinica (neparan broj)
        VOTER_PAIR_NUM : positive := 3   -- broj glasača (neparan broj)
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
end entity fir_filter_ft;

architecture rtl of fir_filter_ft is

    -- broj stepena u transponovanoj formi
    constant NUM_STAGES : positive := FILTER_ORDER + 1;
    
    -- signali za kaskadno povezivanje akumulatora
    type acc_chain_type is array (0 to NUM_STAGES) of std_logic_vector(2*IN_WIDTH - 1 downto 0);
    signal acc_chain : acc_chain_type := (others=>(others=>'0')); 
    
    -- odsecanje izlaza
    constant MSB_IDX : natural := (2 * IN_WIDTH) - 2;
    constant LSB_IDX : natural := (2 * IN_WIDTH) - OUT_WIDTH - 1;

    -- pipeline kašnjenje : 2 registra u DSP-u + 0 u glasaču
    constant LATENCY : positive := FILTER_ORDER + 4 ; 
    -- shift registar dužine LATENCY za tlast signal
    signal in_tlast_sr : std_logic_vector(LATENCY-1 downto 0);
    signal in_tvalid_sr : std_logic_vector(LATENCY-1 downto 0);

    signal clk_en: std_logic;
    
    type coef_t is array (FILTER_ORDER downto 0) of std_logic_vector(IN_WIDTH-1 downto 0);
    signal coeffs : coef_t := (others=>(others=>'0')); 
    
    type sample_chain_type is array (0 to NUM_STAGES-1) of std_logic_vector(IN_WIDTH - 1 downto 0);
    signal sample_chain : sample_chain_type := (others=>(others=>'0')); 
    
begin

    -- memorija za koeficijente
    process(clk)
    begin
        if rising_edge(clk) then
            if write_en = '1' then
                coeffs(to_integer(unsigned(coef_addr_i))) <= coef_i;
            end if;
        end if;
    end process;
    
    -- registri za pipeline
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '0' then
                sample_chain <= (others => (others => '0'));
            elsif clk_en = '1' then
                sample_chain(0) <= in_tdata; 
                for i in 1 to NUM_STAGES-1 loop
                    sample_chain(i) <= sample_chain(i - 1);
                end loop;
            end if;
        end if;
    end process;

    -- prvi stepen
    acc_chain(0) <= (others => '0');

    -- povezivanje 
    GEN_FIR_STAGES : for i in 0 to FILTER_ORDER generate
    begin
        stage_inst : entity work.fir_stage_ft
            generic map (
                MAC_NUM => MAC_NUM, 
                VOTER_PAIR_NUM => VOTER_PAIR_NUM,
                SAMPLE_WIDTH => IN_WIDTH
            )
            port map (
                clk_i => clk,
                rst_i => reset,
                sample_i => sample_chain(i),
                coeff_i => coeffs(i),
                acc_i => acc_chain(i),              
                acc_o => acc_chain(i + 1),          
                clk_en => clk_en
            );
    end generate GEN_FIR_STAGES;

    -- registar na izlazu
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '0' then
                out_tdata <= (others => '0');
            elsif clk_en = '1' then
                out_tdata <= acc_chain(NUM_STAGES)(MSB_IDX downto LSB_IDX);
            end if;
        end if;
    end process;
    
    -- axi
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '0' then
                in_tvalid_sr <= (others => '0');
                in_tlast_sr  <= (others => '0');
            elsif (clk_en) then 
            --else
            
                in_tvalid_sr(0) <= in_tvalid  ;
                in_tlast_sr(0) <= in_tlast  ; 
                -- Pomeranje kroz sve stupnjeve pipeline-a   
                for i in 1 to LATENCY - 1 loop
                    in_tvalid_sr(i) <= in_tvalid_sr(i - 1);
                    in_tlast_sr(i) <= in_tlast_sr(i - 1);
                end loop;
            end if;
        end if;
    end process;
    
    -- Izlazni TVALID
    out_tvalid <= in_tvalid_sr(LATENCY - 1);

    in_tready <= clk_en;
    
    clk_en <=  not (out_tvalid and not out_tready ) ;   
 
    -- Izlazni TLAST 
    out_tlast <= in_tlast_sr(LATENCY - 1);

end architecture rtl;