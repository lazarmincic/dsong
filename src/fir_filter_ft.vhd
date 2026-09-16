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
        s_axis_tdata    : in  std_logic_vector(IN_WIDTH - 1 downto 0);
        s_axis_tvalid   : in  std_logic;
        s_axis_tready   : out std_logic;
        s_axis_tlast    : in  std_logic;
        
        -- axi stream master
        m_axis_tdata    : out std_logic_vector(OUT_WIDTH - 1 downto 0);
        m_axis_tvalid   : out std_logic;
        m_axis_tready   : in  std_logic;
        m_axis_tlast    : out std_logic;
        
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
    constant LATENCY : positive := 2 + FILTER_ORDER; 
    -- shift registar dužine LATENCY za tlast signal
    signal tlast_sr : std_logic_vector(LATENCY-1 downto 0);
    signal tvalid_sr : std_logic_vector(LATENCY-1 downto 0);

    signal clk_en: std_logic;
    
    signal s_ready_sig : std_logic;
    
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
    process(clk, s_axis_tdata)
    begin
        sample_chain(0) <= s_axis_tdata;
        if rising_edge(clk) then
            if reset = '0' then
                sample_chain(1 to NUM_STAGES-1) <= (others => (others => '0'));
            elsif clk_en = '1' then
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

    m_axis_tdata <= acc_chain(NUM_STAGES)(MSB_IDX downto LSB_IDX);
    
    -- shift registar
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '0' then
                tvalid_sr <= (others => '0');
                tlast_sr  <= (others => '0');
            elsif clk_en = '1' then
            
                tvalid_sr(0) <= s_axis_tvalid;
                for i in 1 to LATENCY - 1 loop
                    tvalid_sr(i) <= tvalid_sr(i - 1);
                end loop;
                
                tlast_sr(0) <= s_axis_tlast;               
                -- Pomeranje kroz sve stupnjeve pipeline-a
                for i in 1 to LATENCY - 1 loop
                    tlast_sr(i) <= tlast_sr(i - 1);
                end loop;
            end if;
        end if;
    end process;

    -- Izlazni TLAST 
    m_axis_tlast <= tlast_sr(LATENCY - 1);
    
    -- Izlazni TVALID
    m_axis_tvalid <= tvalid_sr(LATENCY - 1);
    
    s_ready_sig <= m_axis_tready or (not tvalid_sr(LATENCY - 1));
    s_axis_tready <= s_ready_sig;
    
    clk_en <= (s_axis_tvalid or tvalid_sr(LATENCY - 1)) and s_ready_sig;

end architecture rtl;