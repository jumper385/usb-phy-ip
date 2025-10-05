library ieee;
use ieee.std_logic_1164.all;

entity top is
	port (
		tram_wr_en : in std_logic;
		reset : in std_logic;
		clk_50 : out std_logic;
		bitt_out : out std_logic;
		dout : out std_logic;
		enc_ena : out std_logic;
        clk_100 : in std_logic
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
		ena_t : in STD_LOGIC
	);
end component;

	COMPONENT clk_divider IS
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
		-- rx_received : IN STD_LOGIC; -- indication from the RX line that a light message is incoming
		-- host_align : IN STD_LOGIC;
		-- device_align : IN STD_LOGIC;
		-- Add error signals that suggest to go to idle state?
		-- rx_error : OUT STD_LOGIC;
		-- tx_error : OUT STD_LOGIC;
		-- host : IN STD_LOGIC;
        ena_t : out std_logic;
        message_sent : in std_logic
        -- rx_done : in std_logic;
        -- aligned : in std_logic

    );
END component;

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
	signal tram_in, tram_out : std_logic_vector (11 downto 0);
	-- signal tx_clk : std_logic;
 	signal tram_raddr_i,tram_waddr_i : std_logic_vector (10 downto 0);
	signal tx_length : std_logic_vector (10 downto 0) := "00001111111";
	signal ena_t : std_logic;
	signal message_sent : std_logic := '0';
    signal bit_out : std_logic;
	signal enc_clk : std_logic;
	-- signal rx_received : std_logic := '0'; -- indication from the RX line that a light message is incoming
	-- signal host_align : std_logic := '0';
	-- signal device_align : std_logic := '0';
	-- 	-- Add error signals that suggest to go to idle state?
	-- signal rx_error : std_logic := '0';
	-- signal tx_error : std_logic := '0';
	-- signal host : std_logic := '0';
	-- signal rx_done : std_logic := '0';
	-- signal aligned : std_logic := '0';


begin
tx_length <= "00000111111";

ECin : tx_tb
	generic map(
	BITS => 12,
	mlength => 11
	)
	port map (
	wr_clk => enc_clk,
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
        wclk  => enc_clk,
        raddr  => tram_raddr_i,
        rclk   => enc_clk,
        din  => tram_in,
        dout => tram_out
    );


serial : serialiser
	generic map(
		BITS => 12, -- Number of bits being encoded in message 'byte'
		mlength => 11 -- Number of bits in the length message (not including the sync)
	)
	port map (
		clk => enc_clk,
		message => tram_out,
		tx_length => tx_length,
		dout => bit_out,
		rd_addr => tram_raddr_i,
		message_sent => message_sent,
		reset => reset,
		ena_t => ena_t 
	);

man_enc : manchester_encoder
    port map (
        clk => clk_100, 
        reset => reset,
        v => ena_t,
        d => bit_out,
        y => dout
    );

clk_4_enc : clk_divider
    PORT map (
        clk_in => clk_100,
        reset => reset,
        clk_out => enc_clk
    );

lt_fsm : LT_controller
    PORT MAP(
        fsm_clk => enc_clk,
        rst => reset,
		-- Indicators from other blocks to trigger states
        tx_ready => tx_ready, -- indication from EC to start reading TX_RAM and transmit
		-- rx_received => rx_received, -- indication from the RX line that a light message is incoming
		-- host_align => host_align,
		-- device_align => device_align,
		-- -- Add error signals that suggest to go to idle state?
		-- rx_error => rx_error,
		-- tx_error => tx_error,
		-- host => host,
        ena_t => ena_t,
        message_sent => message_sent
		-- rx_done => rx_done,
		-- aligned => aligned
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
	clk_50 <= enc_clk;
	bitt_out <= bit_out;
	enc_ena <= ena_t;
-- tx_clk => clock A
-- enc_clk => BITS * clock A
-- dec_clk => enc_clk * samples per bit
-- rx_clk => clock A
-- FSM needs logic to take in length_sent signal to turn on tx state latch rd_en, use enc_en from TX_enc to turn on and off the encoder.

end architecture;
