LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY top IS
	PORT (
		rst_n : IN STD_LOGIC;
		usb_pu : OUT STD_LOGIC;
		usb_dp : INOUT STD_LOGIC;
		usb_dn : INOUT STD_LOGIC;
		led : OUT STD_LOGIC;

		rx_valid : OUT STD_LOGIC;
		dbg_io1 : OUT STD_LOGIC;
		dbg_io2 : OUT STD_LOGIC;

		usb_feedthrough_dp_o : OUT STD_LOGIC; -- for test jig
		usb_feedthrough_dn_o : OUT STD_LOGIC  -- for test jig
	);
END ENTITY;

ARCHITECTURE rtl OF top IS

	COMPONENT SB_HFOSC
		GENERIC (CLKHF_DIV : STRING := "0b00");
		PORT (
			CLKHFEN : IN STD_LOGIC;
			CLKHFPU : IN STD_LOGIC;
			CLKHF : OUT STD_LOGIC
		);
	END COMPONENT;

	component honeycomb_fs_phy
		port (
			rst_i : in std_logic; -- high = reset; low = normal
			clk_48mhz_i : in std_logic; 
			fs_pu_o : out std_logic; -- output to pull up resistor; optional

			-- usb interface
			usb_dp_io : inout std_logic; -- ensure 1.5k pull up here 
			usb_dn_io : inout std_logic;
			
			-- utmi tx interface
			utmi_dout_i : in std_logic_vector(7 downto 0); -- stage tx data here
			utmi_txvalid_i : in std_logic; -- request to tx here; set high
			utmi_txrdy_o : out std_logic; -- high = transmitting state

			-- utmi rx interface
			utmi_din_o : out std_logic_vector(7 downto 0); -- all rx line data here
			utmi_rxvalid_o : out std_logic; -- high rx is good to read
			utmi_rxactive_o : out std_logic; -- high if rx'ing
			utmi_rxerror_o : out std_logic; -- high if error

			-- utmi debug interface
			utmi_line_state_o : out std_logic_vector(1 downto 0); -- probe bit 0 for usb state
			utmi_usb_rst_o : out std_logic -- high if usb phy is being reset
		);
	end component;

	COMPONENT handshake_sender
		PORT (
			en : in std_logic;

			clk : IN STD_LOGIC;
			utmi_dout_o : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			utmi_txvalid_o : OUT STD_LOGIC;

			setup_detected_i : in std_logic;	
			data_detected_i : in std_logic;
			in_detected_i : in std_logic;
			utmi_txrdy_i : IN STD_LOGIC;

			dbg_state_o : out std_logic_vector(2 downto 0)
		);
	END COMPONENT;
	
	-- constants
	CONSTANT PID_SETUP : std_logic_vector(7 downto 0) := x"2D";
	CONSTANT PID_DATA0 : std_logic_vector(7 downto 0) := x"C3";
	CONSTANT PID_IN : std_logic_vector(7 downto 0) := x"69";

	-- signals ...
	SIGNAL txoe : STD_LOGIC;
	SIGNAL rxd : STD_LOGIC;

	SIGNAL utmi_dout : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
	SIGNAL utmi_txvalid : STD_LOGIC := '0';
	SIGNAL utmi_txrdy : STD_LOGIC;
	SIGNAL utmi_din : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL utmi_rxvalid : STD_LOGIC;
	SIGNAL utmi_rxactive : STD_LOGIC;
	SIGNAL utmi_rxerror : STD_LOGIC;
	SIGNAL utmi_line_state : STD_LOGIC_VECTOR(1 DOWNTO 0);
	SIGNAL utmi_usb_rst : STD_LOGIC;

	SIGNAL rxdp : STD_LOGIC;
	SIGNAL rxdn : STD_LOGIC;
	SIGNAL txdp : STD_LOGIC;
	SIGNAL txdn : STD_LOGIC;

	SIGNAL clk_hf : STD_LOGIC;
	SIGNAL setup_detected : STD_LOGIC;
	SIGNAL data_detected : STD_LOGIC;
	SIGNAL in_detected : std_logic;

	SIGNAL dbg_state : std_logic_vector(2 downto 0);

BEGIN
	led <= NOT rst_n;

	rxd <= rxdp;

	u_osc : SB_HFOSC
	GENERIC MAP(CLKHF_DIV => "0b00")
	PORT MAP(
		CLKHFEN => '1',
		CLKHFPU => '1',
		CLKHF => clk_hf
	);
	
	usb_phy : honeycomb_fs_phy
	port map (
		rst_i => '1',
		clk_48mhz_i => clk_hf,
		fs_pu_o => usb_pu,

		usb_dp_io => usb_dp,
		usb_dn_io => usb_dn,

		utmi_dout_i => utmi_dout,
		utmi_txvalid_i => utmi_txvalid,
		utmi_txrdy_o => utmi_txrdy,

		utmi_din_o => utmi_din,
		utmi_rxvalid_o => utmi_rxvalid,
		utmi_rxactive_o => utmi_rxactive,
		utmi_rxerror_o => utmi_rxerror,

		utmi_line_state_o => utmi_line_state,
		utmi_usb_rst_o => utmi_usb_rst
	);

	hs_sender_inst : handshake_sender
	PORT MAP(
		en => not rst_n,
		clk => clk_hf,

		utmi_dout_o => utmi_dout,
		utmi_txvalid_o => utmi_txvalid,

		setup_detected_i => setup_detected, 
		data_detected_i => data_detected,
		in_detected_i => in_detected,
		utmi_txrdy_i => utmi_txrdy,
		
		dbg_state_o => dbg_state
	);

	rx_valid <= utmi_rxvalid;
	dbg_io1 <= in_detected;
	dbg_io2 <= data_detected;

	usb_feedthrough_dp_o <= utmi_line_state(0); -- for test jig
	usb_feedthrough_dn_o <= utmi_line_state(1); -- for test jig

END ARCHITECTURE;
