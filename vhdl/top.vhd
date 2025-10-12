library ieee;
use ieee.std_logic_1164.all;

entity top is
	port (
		tram_wr_en : in std_logic;
		reset : in std_logic;
		bitt_out : out std_logic; -- bit
		bitt_in : out std_logic; -- bit received
		dout : out std_logic; -- manchester tx
		dout_rd : out std_logic; -- read manchester tx
		din_rd : out std_logic; -- read manchester rx
        clk_100 : in std_logic; -- 100 MHz 
		din : in std_logic -- manchester rx
	);
end top;

architecture rtl of top is
component tx_tb is
	generic(
		BITS : INTEGER := 10; -- Number of bits being encoded
		mlength : INTEGER := 11 -- Number of bits in the length message (not including the sync)
	);
	port(
	wr_clk : in STD_LOGIC;
	reset : in STD_LOGIC;
	wr_en : in STD_LOGIC;
	tx_length : in std_logic_vector (mlength-1 downto 0);
	wr_ram : out STD_LOGIC_VECTOR (BITS-1 downto 0);
	wr_addr : out STD_LOGIC_VECTOR (mlength-1 downto 0);
	tx_ready : out STD_LOGIC
	);
end component;

	component ram is
		generic (
			addr_width : natural := 9; -- 512x8
			data_width : natural := 8
		);
		port (
			write_en : in  std_logic;
			waddr    : in  std_logic_vector (addr_width - 1 downto 0);
			wclk     : in  std_logic;
			raddr    : in  std_logic_vector (addr_width - 1 downto 0);
			rclk     : in  std_logic;
			din      : in  std_logic_vector (data_width - 1 downto 0);
			dout     : out std_logic_vector (data_width - 1 downto 0)
		);
	end component;

component serialiser is
	generic(
		BITS : INTEGER := 10; -- Number of bits being encoded
		mlength : INTEGER := 11 -- Number of bits in the length message (not including the sync)
	);
	port (
		clk : in STD_LOGIC;
		message : in STD_LOGIC_VECTOR(BITS-1 downto 0);
		tx_length : in std_logic_vector (mlength-1 downto 0);
		dout : out STD_LOGIC;
		rd_addr : out STD_LOGIC_VECTOR (mlength-1 downto 0);
		message_sent : out STD_LOGIC;
		reset : in STD_LOGIC;
		tx_err_sent : out STD_LOGIC;
		tx_error : in std_logic;
		ena_re : in std_logic;
		ena_t : in STD_LOGIC
	);
end component;

	COMPONENT clk_divider IS
		GENERIC (
			N : INTEGER := 0
		);
		PORT (
			clk_in : IN STD_LOGIC;
			reset : IN STD_LOGIC;
			clk_out : OUT STD_LOGIC
		);
	end component;

    component manchester_encoder is
        port (
            clk, reset : in std_logic;
            v, d       : in std_logic;
            y          : out std_logic
        );
    end component;

	
	component LT_controller IS
    PORT (
        fsm_clk : IN STD_LOGIC; 
        rst : IN STD_LOGIC;
		-- Indicators from other blocks to trigger states
        tx_ready : IN STD_LOGIC; -- indication from EC to start reading TX_RAM and transmit
		rx_received : IN STD_LOGIC; -- indication from the RX line that a light message is incoming
		-- host_align : IN STD_LOGIC;
		-- device_align : IN STD_LOGIC;
		-- Add error signals that suggest to go to idle state?
		rx_error : IN STD_LOGIC;
		tx_err_sent : IN STD_LOGIC;
		tx_error : IN STD_LOGIC;
		ena_re : out std_logic;
		-- host : IN STD_LOGIC;
        ena_t : out std_logic;
        message_sent : in std_logic;
        -- aligned : in std_logic
		ena_r : out std_logic;
        rx_done : in std_logic

    );
END component;

	-- component SB_PLL40_CORE is
	-- 	generic (

    --         -- fout = fin * (DIVF + 1) / (2^DIVQ * (DIVR + 1))

	-- 		FEEDBACK_PATH : string := "SIMPLE";
	-- 		PLLOUT_SELECT : string := "GENCLK";
	-- 		DIVR : integer := 3;
	-- 		DIVF : integer := 43;
	-- 		DIVQ : integer := 5;
	-- 		FILTER_RANGE : integer := 4
	-- 	);
	-- 	port (
	-- 		REFERENCECLK : in std_logic;
	-- 		PLLOUTCORE : out std_logic;
	-- 		PLLOUTGLOBAL : out std_logic;
	-- 		EXTFEEDBACK : in std_logic;
	-- 		DYNAMICDELAY : in std_logic_vector(7 downto 0);
	-- 		LOCK : out std_logic;
	-- 		BYPASS : in std_logic;
	-- 		RESETB : in std_logic
	-- 	);
	-- end component SB_PLL40_CORE;

component manchester_decoder is
	generic (
		OVERSAMPLE : natural := 8; -- oversample factor (must match PLL output)
		BAUD : natural := 18000000; -- Manchester bit rate
		BITS : INTEGER := 12 -- Number of bits being processed out
	);
	port (
		clk_ovs : in std_logic; -- oversample clock from PLL (OVERSAMPLE BAUD)
		reset : in std_logic;
		man_in : in std_logic; -- Manchester encoded input
		rx_done : in std_logic; -- signal from deserialiser to reset bit_out
		bit_valid : out std_logic; -- one-cycle pulse when bit_out is valid
		bit_out : out std_logic; -- decoded bit for debugging/testing
		byte_out : out std_logic_vector(BITS-1 downto 0);
		byte_ready : out std_logic;-- pulse when byte_out is valid
		rx_received : out std_LOGIC
	);
end component;

component deserialiser is
	generic(
		BITS : INTEGER := 12; -- Number of bits being encoded
		mlength : INTEGER := 11 -- Number of bits in the length message (not including the sync)
	);
	port (
		clk : in STD_LOGIC;
		rx_message : out STD_LOGIC_VECTOR(BITS-1 downto 0); -- data to load into RAM
		rx_length : out std_logic_vector (mlength-1 downto 0); -- Received length 
		byte_in : in STD_LOGIC_VECTOR(BITS-1 downto 0); -- byte from manchester_decoder
		wr_addr : out STD_LOGIC_VECTOR (mlength-1 downto 0); -- Address to RX_RAM
		rx_done : out STD_LOGIC; -- signal to LT controller
		reset : in STD_LOGIC; -- global reset
		byte_ready : in STD_LOGIC; -- byte ready from manchester_decoder
		lt_wr_ram_clk : out std_logic;
        rx_error : out STD_LOGIC; -- RE to LT controller
        ena_r : in STD_LOGIC; -- enable from LT controller
        tx_error : out STD_LOGIC -- TE to LT controller
	);
end component;

-- component SB_HFOSC is
-- 		generic (
-- 			CLKHF_DIV : STRING := "0b00"
-- 		);
-- 		port (
-- 			CLKHFEN : in STD_LOGIC;
-- 			CLKHFPU : in STD_LOGIC;
-- 			CLKHF : out STD_LOGIC
-- 		);
-- 	end component SB_HFOSC;

	signal tx_ready, tram_rd_en : std_logic := '0';
	signal tram_in, tram_out, rram_in, rram_out : std_logic_vector (11 downto 0);
	-- signal tx_clk : std_logic;
 	signal tram_raddr_i,tram_waddr_i, rram_waddr_i, rram_raddr_i : std_logic_vector (10 downto 0);
	signal tx_length : std_logic_vector (10 downto 0) := "00001111111";
	signal rx_length : std_logic_vector (10 downto 0);
	signal ena_t, ena_r : std_logic;
	signal message_sent : std_logic := '0';
    signal bit_out : std_logic;
	signal clk_25, clk_50, clk_120 : std_logic;
	signal bit_valid : std_logic;
	signal bit_in : std_logic;
	signal byte_ready : std_logic;
	signal dout_wr : std_logic;
	signal rx_message : STD_LOGIC_VECTOR (11 downto 0);	
	signal rx_received : std_logic := '0'; -- indication from the RX line that a light message is incoming
	signal tx_err_sent : STD_LOGIC;
	-- signal host_align : std_logic := '0';
	-- signal device_align : std_logic := '0';
	-- 	-- Add error signals that suggest to go to idle state?
	signal rx_error : std_logic := '0';
	signal tx_error : std_logic := '0';
	signal ena_re : std_logic := '0';
	-- signal host : std_logic := '0';
	signal lt_wr_ram_clk : std_logic;
	signal rx_done : std_logic := '0';
	-- signal aligned : std_logic := '0';


begin
tx_length <= "00000000111";

ECin : tx_tb
	generic map(
	BITS => 12,
	mlength => 11
	)
	port map (
	wr_clk => clk_25,
	reset => reset,
	wr_en => tram_wr_en,
	tx_length => tx_length,
	wr_ram => tram_in,
	wr_addr => tram_waddr_i,
	tx_ready => tx_ready
);

ram_tx : ram 
    generic map (
        addr_width => 11, -- 2048 x 12
        data_width => 12
    )
    port map (
        write_en => tram_wr_en,
        waddr  => tram_waddr_i,
        wclk  => clk_25,
        raddr  => tram_raddr_i,
        rclk   => clk_25,
        din  => tram_in,
        dout => tram_out
    );


serial : serialiser
	generic map(
		BITS => 12, -- Number of bits being encoded in message 'byte'
		mlength => 11 -- Number of bits in the length message (not including the sync)
	)
	port map (
		clk => clk_25,
		message => tram_out,
		tx_length => tx_length,
		dout => bit_out,
		rd_addr => tram_raddr_i,
		message_sent => message_sent,
		reset => reset,
		tx_err_sent => tx_err_sent,
		tx_error => tx_error,
		ena_re => ena_re,
		ena_t => ena_t 
	);

man_enc : manchester_encoder
    port map (
        clk => clk_50, 
        reset => reset,
        v => ena_t,
        d => bit_out,
        y => dout_wr
    );

clkd_25 : clk_divider
	GENERIC map(
        N => 3
    )
    PORT map (
        clk_in => clk_100,
        reset => reset,
        clk_out => clk_25 -- Set as the quarter speed
    );

clkd_50 : clk_divider
	GENERIC map(
        N => 1
    )
    PORT map (
        clk_in => clk_100,
        reset => reset,
        clk_out => clk_50 -- Set as the half speed
    );

lt_fsm : LT_controller
    PORT MAP(
        fsm_clk => clk_100,
        rst => reset,
		-- Indicators from other blocks to trigger states
        tx_ready => tx_ready, -- indication from EC to start reading TX_RAM and transmit
		rx_received => rx_received, -- indication from the RX line that a light message is incoming
		-- host_align => host_align,
		-- device_align => device_align,
		-- -- Add error signals that suggest to go to idle state?
		rx_error => rx_error,
		tx_err_sent => tx_err_sent,
		tx_error => tx_error,
		-- host => host,
        ena_t => ena_t,
		ena_r => ena_r,
		ena_re => ena_re,
        message_sent => message_sent,
		rx_done => rx_done
		-- aligned => aligned
    );

-- pll_200 : component SB_PLL40_CORE
-- generic map(

-- 	-- fout = fin * (DIVF + 1) / (2^DIVQ * (DIVR + 1))
-- 	DIVR => 11,
-- 	DIVF => 1,
-- 	DIVQ => 4
-- )
-- port map (
-- 	REFERENCECLK => clk_100,
-- 	PLLOUTCORE => clk_120,
-- 	PLLOUTGLOBAL => open,
-- 	EXTFEEDBACK => '0',
-- 	DYNAMICDELAY => (others => '0'),
-- 	LOCK => open,
-- 	BYPASS => '0',
-- 	RESETB => reset
-- );

ram_rx : ram 
    generic map (
        addr_width => 11, -- 2048 x 12
        data_width => 12
    )
    port map (
        write_en => ena_r,
        waddr  => rram_waddr_i,
        wclk  => lt_wr_ram_clk,
        raddr  => rram_raddr_i, -- EC side
        rclk   => clk_25,-- EC side
        din  => rram_in,
        dout => rram_out -- EC side
    );

man_dec : manchester_decoder
	generic map (
		OVERSAMPLE => 8, -- oversample factor (must match PLL output)
		BAUD => 18000000, -- Manchester bit rate
		BITS => 12 -- Number of bits being processed out
	)
	port map (
		clk_ovs => clk_100, -- oversample clock from PLL (OVERSAMPLE BAUD)
		reset => reset,
		man_in => din, -- Manchester encoded input
		rx_done => rx_done,
		bit_valid => bit_valid, -- one-cycle pulse when bit_out is valid
		bit_out => bit_in, -- decoded bit for debugging/testing
		byte_out => rx_message,
		rx_received => rx_received,
		byte_ready => byte_ready -- pulse when byte_out is valid
	);

deser : deserialiser
	generic map(
		BITS => 12, -- Number of bits being encoded
		mlength => 11 -- Number of bits in the length message (not including the sync)
	)
	port map (
		clk => clk_100,
		rx_message => rram_in,  -- data to load into RAM
		rx_length => rx_length, -- Received length 
		byte_in => rx_message, -- byte from manchester_decoder
		wr_addr => rram_waddr_i, -- Address to RX_RAM
		rx_done => rx_done, -- signal to LT controller
		reset => reset, -- global reset
		lt_wr_ram_clk => lt_wr_ram_clk,
		byte_ready => byte_ready, -- byte ready from manchester_decoder
        rx_error => rx_error, -- RE to LT controller
        ena_r => ena_r, -- enable from LT controller
        tx_error => tx_error -- TE to LT controller
	);

	-- 	u_osc: component SB_HFOSC
	-- generic map (
	-- 	CLKHF_DIV => "0b00"
	-- )
	-- port map (
	-- 	CLKHFEN => '1',
	-- 	CLKHFPU => '1',
	-- 	CLKHF => enc_clk
	-- );
    
    -- clk_tx <= tx_clk;
	bitt_out <= bit_out;
	din_rd <= din;
	bitt_in <= bit_in;
	dout <= dout_wr;
	dout_rd <= dout_wr;
-- tx_clk => clock A
-- enc_clk => BITS * clock A
-- dec_clk => enc_clk * samples per bit
-- rx_clk => clock A
-- FSM needs logic to take in length_sent signal to turn on tx state latch rd_en, use enc_en from TX_enc to turn on and off the encoder.

end architecture;