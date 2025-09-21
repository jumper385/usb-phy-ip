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

	COMPONENT usb_phy
		PORT (
			clk : IN STD_LOGIC;
			rst : IN STD_LOGIC;
			phy_tx_mode : IN STD_LOGIC;
			usb_rst : OUT STD_LOGIC;
			rxd, rxdp, rxdn : IN STD_LOGIC;
			txdp, txdn, txoe : OUT STD_LOGIC;
			DataOut_i : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
			TxValid_i : IN STD_LOGIC;
			TxReady_o : OUT STD_LOGIC;
			DataIn_o : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			RxValid_o : OUT STD_LOGIC;
			RxActive_o : OUT STD_LOGIC;
			RxError_o : OUT STD_LOGIC;
			LineState_o : OUT STD_LOGIC_VECTOR(1 DOWNTO 0)
		);
	END COMPONENT;

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
	SIGNAL handshake_trig : STD_LOGIC;

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

	u_phy : usb_phy
	PORT MAP(
		-- phy control
		clk => clk_hf,
		rst => '1',
		phy_tx_mode => '1',
		usb_rst => utmi_usb_rst,

		-- usb interface
		rxd => rxd,
		rxdp => rxdp,
		rxdn => rxdn,
		txdp => txdp,
		txdn => txdn,
		txoe => txoe,

		--- utmi tx interface
		DataOut_i => utmi_dout,
		TxValid_i => utmi_txvalid,
		TxReady_o => utmi_txrdy,

		--- utmi rx interface
		DataIn_o => utmi_din,
		RxValid_o => utmi_rxvalid,
		RxActive_o => utmi_rxactive,
		RxError_o => utmi_rxerror,

		--- debug info
		LineState_o => utmi_line_state
	);

	setup_detected <= '1' when utmi_din(7 downto 0) = PID_SETUP else '0';
	data_detected <= '1' when utmi_din(7 downto 0) = PID_DATA0 else '0';
	in_detected  <= '1' when utmi_din(7 downto 0) = PID_IN else '0';

	usb_dp <= txdp when txoe = '0' else 'Z';
	usb_dn <= txdn when txoe = '0' else 'Z';

	rxdp <= usb_dp;
	rxdn <= usb_dn;

	handshake_trig <= setup_detected or data_detected;

	hs_sender_inst : handshake_sender
	PORT MAP(
		en => rst_n,
		clk => clk_hf,

		utmi_dout_o => utmi_dout,
		utmi_txvalid_o => utmi_txvalid,

		setup_detected_i => setup_detected, 
		data_detected_i => data_detected,
		in_detected_i => in_detected,
		utmi_txrdy_i => utmi_txrdy,
		
		dbg_state_o => dbg_state
	);


	usb_pu <= '1'; -- note: icesugar has the pull routed to a pin... annoyingly

	rx_valid <= utmi_rxvalid;
	dbg_io1 <= in_detected;
	dbg_io2 <= data_detected;

	usb_feedthrough_dp_o <= utmi_line_state(0); -- for test jig
	usb_feedthrough_dn_o <= utmi_line_state(1); -- for test jig

END ARCHITECTURE;
