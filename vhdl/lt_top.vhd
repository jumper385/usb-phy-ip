-- Library and Use statements for IEEE packages
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
ENTITY top IS
	GENERIC (
		BITS : INTEGER := 8 -- Input number of bits to EC
	);
	PORT (
		-- enter port declarations here
		reset : IN STD_LOGIC;
		byte_in : IN STD_LOGIC_VECTOR(BITS - 1 DOWNTO 0);
		bit_valid : OUT STD_LOGIC;
		bit_out : OUT STD_LOGIC;
		byte_out : OUT STD_LOGIC_VECTOR(BITS - 1 DOWNTO 0);
		byte_ready : OUT STD_LOGIC; -- byte ready for wr
		dbg_io1 : OUT STD_LOGIC
	);
END ENTITY top;

ARCHITECTURE arch OF top IS
	-- insert local declarations here
	SIGNAL clk_48 : STD_LOGIC;
	SIGNAL glob_clk : STD_LOGIC;
	SIGNAL rx_clk : STD_LOGIC;
	SIGNAL man_in : STD_LOGIC;
	SIGNAL clk_4_tx : STD_LOGIC;
	SIGNAL byte_clk : STD_LOGIC;
	SIGNAL tx_byte : STD_LOGIC_VECTOR (BITS + 1 DOWNTO 0);
	SIGNAL rx_byte : STD_LOGIC_VECTOR (BITS + 1 DOWNTO 0);
	SIGNAL wr_en : STD_LOGIC := '0';
	SIGNAL rd_en : STD_LOGIC := '0';
	SIGNAL lt_tx_byte : STD_LOGIC_VECTOR (BITS + 1 DOWNTO 0);
	SIGNAL lt_rx_byte : STD_LOGIC_VECTOR (BITS + 1 DOWNTO 0);
	SIGNAL tx_length : STD_LOGIC_VECTOR (10 DOWNTO 0) := "11111111100"; -- length of TX message
	SIGNAL wr_addr_i : STD_LOGIC_VECTOR (10 DOWNTO 0);
	SIGNAL rd_addr_i : STD_LOGIC_VECTOR (10 DOWNTO 0);
	-- takes 48MHz -> 16MHz
	COMPONENT PLL_clk IS
		PORT (
			ref_clk_i : IN STD_LOGIC;
			rst_n_i : IN STD_LOGIC;
			outcore_o : OUT STD_LOGIC;
			outglobal_o : OUT STD_LOGIC
		);
	END COMPONENT PLL_clk;

	COMPONENT manchester_receiver IS
		GENERIC (
			OVERSAMPLE : NATURAL := 16; -- oversample factor (must match PLL output)
			BAUD : NATURAL := 1000000; -- Manchester bit rate
			BITS : INTEGER := 10 -- Number of bits being processed out
		);
		PORT (
			clk_ovs : IN STD_LOGIC; -- oversample clock from PLL (OVERSAMPLE BAUD)
			reset : IN STD_LOGIC;
			man_in : IN STD_LOGIC; -- Manchester encoded input
			bit_valid : OUT STD_LOGIC; -- one-cycle pulse when bit_out is valid
			bit_out : OUT STD_LOGIC; -- decoded bit
			byte_out : OUT STD_LOGIC_VECTOR(BITS - 1 DOWNTO 0);
			byte_ready : OUT STD_LOGIC -- pulse when byte_out is valid
		);
	END COMPONENT manchester_receiver;

	COMPONENT SB_HFOSC IS
		GENERIC (
			CLKHF_DIV : STRING := "0b00"
		);
		PORT (
			CLKHFEN : IN STD_LOGIC;
			CLKHFPU : IN STD_LOGIC;
			CLKHF : OUT STD_LOGIC
		);
	END COMPONENT SB_HFOSC;

	COMPONENT manchester_encoder IS
		GENERIC (
			BITS : INTEGER := 10 -- Number of bits being encoded
		);
		PORT (
			clk : IN STD_LOGIC;
			message : IN STD_LOGIC_VECTOR(BITS - 1 DOWNTO 0);
			dout : OUT STD_LOGIC;
			reset : IN STD_LOGIC
		);
	END COMPONENT manchester_encoder;

	COMPONENT clk_divider IS
		GENERIC (
			Freq_in : POSITIVE := 16000000
		);
		PORT (
			clk_in : IN STD_LOGIC;
			reset : IN STD_LOGIC;
			clk_out : OUT STD_LOGIC
		);
	END COMPONENT clk_divider;

	COMPONENT EC_RX IS

		PORT (
			EC_clk : IN STD_LOGIC;
			EC_ENA : IN STD_LOGIC;
			reset : IN STD_LOGIC;
			LT_in : IN STD_LOGIC_VECTOR (9 DOWNTO 0);
			EC_out : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
		);
	END COMPONENT;

	COMPONENT EC_TX IS

		PORT (
			EC_in : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
			EC_clk : IN STD_LOGIC;
			EC_ENA : IN STD_LOGIC;
			reset : IN STD_LOGIC;
			RAM_out : OUT STD_LOGIC_VECTOR (9 DOWNTO 0);
			RAM_ready : OUT STD_LOGIC
		);
	END COMPONENT;
	COMPONENT TX_RAM IS
		PORT (
			-- enter port declarations here
			wr_clk : IN STD_LOGIC;
			rd_clk : IN STD_LOGIC;
			reset : IN STD_LOGIC;
			wr_en : IN STD_LOGIC;
			rd_en : IN STD_LOGIC;
			tx_length : IN STD_LOGIC_VECTOR (10 DOWNTO 0);
			wr_addr : OUT STD_LOGIC_VECTOR (10 DOWNTO 0);
			rd_addr : OUT STD_LOGIC_VECTOR (10 DOWNTO 0)
		);
	END COMPONENT;

	COMPONENT bram_2048x10
		PORT (
			-- Write port
			wclk : IN STD_LOGIC;
			we : IN STD_LOGIC;
			waddr : IN STD_LOGIC_VECTOR(10 DOWNTO 0); -- 2048 deep
			din : IN STD_LOGIC_VECTOR(9 DOWNTO 0);

			-- Read port
			rclk : IN STD_LOGIC;
			re : IN STD_LOGIC;
			raddr : IN STD_LOGIC_VECTOR(10 DOWNTO 0);
			dout : OUT STD_LOGIC_VECTOR(9 DOWNTO 0)
		);
	END COMPONENT;
BEGIN
	-- Component instantiation statement
	RX_PLL_clk : PLL_clk
	PORT MAP(
		ref_clk_i => clk_48,
		rst_n_i => NOT reset,
		outcore_o => rx_clk,
		outglobal_o => glob_clk
	);
	uut : manchester_receiver
	GENERIC MAP(
		OVERSAMPLE => 16, -- oversample factor (must match PLL output) must be even number. oversample - 2
		BAUD => 1000000, -- Manchester bit rate
		BITS => 10
	)
	PORT MAP(
		clk_ovs => rx_clk,
		reset => reset,
		man_in => man_in,
		bit_valid => bit_valid,
		bit_out => bit_out,
		byte_out => RX_byte,
		byte_ready => byte_clk
	);
	u_osc : SB_HFOSC
	GENERIC MAP(
		CLKHF_DIV => "0b00"
	)
	PORT MAP(
		CLKHFEN => '1',
		CLKHFPU => '1',
		CLKHF => clk_48
	);

	txt : manchester_encoder
	GENERIC MAP(
		BITS => 10
	)
	PORT MAP(
		clk => clk_4_tx,
		message => lt_tx_byte,
		dout => man_in,
		reset => reset
	);
	tx_clk : clk_divider
	GENERIC MAP(
		Freq_in => 16
	)
	PORT MAP(
		clk_in => rx_clk,
		reset => reset,
		clk_out => clk_4_tx
	);
	ECTX : EC_TX
	PORT MAP(
		EC_in => byte_in,
		EC_clk => byte_clk,
		EC_ENA => NOT reset,
		reset => reset,
		RAM_out => TX_byte,
		RAM_ready => wr_en
	);

	ECRX : EC_RX
	PORT MAP(
		EC_clk => byte_clk,
		EC_ENA => NOT reset,
		reset => reset,
		LT_in => RX_byte,
		EC_out => byte_out
	);
	EC_TX_LT : TX_RAM
	PORT MAP(
		-- enter port declarations here
		wr_clk => byte_clk,
		rd_clk => byte_clk,
		reset => reset,
		wr_en => wr_en,
		rd_en => rd_en,
		tx_length => tx_length,
		wr_addr => wr_addr_i,
		rd_addr => rd_addr_i
	);

	RAM_TX : bram_2048x10
	PORT MAP(
		wclk => byte_clk,
		we => wr_en,
		waddr => wr_addr_i,
		din => TX_byte,
		rclk => byte_clk,
		re => rd_en,
		raddr => rd_addr_i,
		dout => lt_tx_byte
	);
	-- Generate statement
	-- make a FSM with indicators of state. need a rd_en for the TX RAM.
	dbg_io1 <= rx_clk;
	byte_ready <= byte_clk;
	rd_en <= wr_en;
END ARCHITECTURE arch;