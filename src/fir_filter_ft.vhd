library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.util_pkg.all;
use work.voter_pkg.all; 

entity fir_filter_ft is
    generic (
        FILTER_ORDER : positive := 20; -- red filtra (stepen filtra je FILTER_ORDER + 1)
        IN_WIDTH : positive := 24; -- širina ulaznih podataka (umnožak 8)
        OUT_WIDTH : positive := 24; -- širina izlaznih podataka (umnožak 8)
        -- paznja! OUT_WIDTH sme biti maksimalno 2*IN_WIDTH - 1!
 
        MAX_FAULT_TOLERANCE : natural := 6
        -- na nivou stepena filtra, za mac jedinicu i glasac posebno
        -- na primer, ako je 1, mac jedinica je otporna na 1 gresku, i glasac na 1.
    );
    port (
        clk : in  std_logic;
        reset : in  std_logic; -- aktivan na '0'
        input : in std_logic_vector(IN_WIDTH-1 downto 0);
        output: out std_logic_vector (OUT_WIDTH-1 downto 0);
        
        coeffs : in std_logic_vector_array (FILTER_ORDER downto 0)(IN_WIDTH-1 downto 0); 
        
        valid_i: in std_logic;
        valid_o: out std_logic;
        
        last_i: in std_logic;
        last_o: out std_logic;
        
        clk_en: in std_logic;
        
        last_in_pipeline: out std_logic
        
    );
end entity fir_filter_ft;

architecture rtl of fir_filter_ft is
    
    -- signali za kaskadno povezivanje akumulatora
    type acc_chain_type is array (FILTER_ORDER downto 0) of std_logic_vector(2*IN_WIDTH - 1 downto 0);
    signal acc_chain : acc_chain_type := (others=>(others=>'0')); 
    
    -- odsecanje izlaza
    constant MSB_IDX : natural := (2 * IN_WIDTH) - 2;
    constant LSB_IDX : natural := (2 * IN_WIDTH) - OUT_WIDTH - 1;

    -- pipeline kašnjenje : 3 registra u DSP-u + 0 u glasaču + 2 za ulaz i izlaz
    constant PIPELINE_DEPTH : positive := FILTER_ORDER + 3 + 2; 
    -- shift registar dužine PIPELINE_DEPTH za tlast signal
    signal last_shift : std_logic_vector(PIPELINE_DEPTH-1 downto 0);
    signal valid_shift : std_logic_vector(PIPELINE_DEPTH-1 downto 0);
    
    type sample_chain_type is array (FILTER_ORDER-1 downto 0) of std_logic_vector(IN_WIDTH - 1 downto 0);
    signal sample_chain : sample_chain_type := (others=>(others=>'0')); 
    
    constant MAC_NUM : positive := 2*(MAX_FAULT_TOLERANCE+1)-1;  -- broj MAC jedinica (neparan broj)
    constant VOTER_PAIR_NUM : positive := MAX_FAULT_TOLERANCE + 1;   -- broj parova glasača 
    
    -- reg na ulazu
    signal input_r : std_logic_vector(IN_WIDTH-1 downto 0);
    
begin

    -- registar na ulazu
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '0' then
                input_r <= (others => '0');
            elsif clk_en = '1' then
                input_r <= input;
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
                sample_chain(0) <= input_r; 
                for i in 1 to FILTER_ORDER-1 loop
                    sample_chain(i) <= sample_chain(i - 1);
                end loop;
            end if;
        end if;
    end process; 

    -- povezivanje 
    -- nulti 
    
    gen_stage_0: entity work.fir_stage_ft
        generic map (
            MAC_NUM => MAC_NUM, 
            VOTER_PAIR_NUM => VOTER_PAIR_NUM,
            SAMPLE_WIDTH => IN_WIDTH
        )
        port map (
            clk_i => clk,
            rst_i => reset,
            sample_i => input_r,
            coeff_i => coeffs(FILTER_ORDER),
            acc_i => (others => '0'),              
            acc_o => acc_chain(0),          
            clk_en => clk_en
        );
            
    gen_stages : for i in 1 to FILTER_ORDER generate
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
                sample_i => sample_chain(i-1),
                coeff_i => coeffs(FILTER_ORDER - i),
                acc_i => acc_chain(i-1),              
                acc_o => acc_chain(i),          
                clk_en => clk_en
            );
    end generate gen_stages;
    
    -- registar na izlazu
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '0' then
                output <= (others => '0');
            elsif clk_en = '1' then
                output <= acc_chain(FILTER_ORDER)(MSB_IDX downto LSB_IDX);
            end if;
        end if;
    end process;
    
    -- prenos valid i last signala
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '0' then
                valid_shift <= (others => '0');
                last_shift <= (others => '0');
            elsif clk_en = '1' then
                valid_shift(0) <= valid_i;
                last_shift(0) <= last_i;
                for i in 1 to PIPELINE_DEPTH-1 loop
                    valid_shift(i) <= valid_shift(i-1);
                    last_shift(i) <= last_shift(i-1);
                end loop;
            end if;
        end if;
    end process; 
    
    last_in_pipeline <= '1' when unsigned(last_shift) /= 0 else '0';
    
    valid_o <= valid_shift (PIPELINE_DEPTH-1);
    last_o <= last_shift (PIPELINE_DEPTH-1);

end architecture rtl;