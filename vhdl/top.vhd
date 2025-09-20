LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY top IS
	PORT (
		rst_n : IN STD_LOGIC;
		usb_dp : INOUT STD_LOGIC;
		usb_dn : INOUT STD_LOGIC;
		led : OUT STD_LOGIC;

		rx_valid : OUT STD_LOGIC;
		dbg_io : OUT STD_LOGIC
	);
END ENTITY;

ARCHITECTURE rtl OF top IS

  	component and2 is
		port ( a: in std_logic; b: in std_logic; y: out std_logic );
	end component;

	component or2 is
		port ( a: in std_logic; b: in std_logic; y: out std_logic );
	end component;	

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

	COMPONENT SB_HFOSC
		GENERIC (CLKHF_DIV : STRING := "0b00");
		PORT (
			CLKHFEN : IN STD_LOGIC;
			CLKHFPU : IN STD_LOGIC;
			CLKHF : OUT STD_LOGIC
		);
	END COMPONENT;

	-- signals ...
	SIGNAL txdp, txdn, txoe : STD_LOGIC;
	SIGNAL rxdp, rxdn, rxd : STD_LOGIC;

	SIGNAL utmi_dout : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
	SIGNAL utmi_txvalid : STD_LOGIC := '0';
	SIGNAL utmi_txrdy : STD_LOGIC;
	SIGNAL utmi_din : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL utmi_rxvalid : STD_LOGIC;
	SIGNAL utmi_rxactive : STD_LOGIC;
	SIGNAL utmi_rxerror : STD_LOGIC;
	SIGNAL utmi_line_state : STD_LOGIC_VECTOR(1 DOWNTO 0);
	SIGNAL utmi_usb_rst : STD_LOGIC;
	
	SIGNAL clk_hf : std_logic;

	SIGNAL a, b, c, d: std_logic;

BEGIN
	-- simple tie-offs to keep logic from being optimized away
	led <= NOT rst_n;

	usb_dp <= txdp WHEN txoe = '1' ELSE '1';
	usb_dn <= txdn WHEN txoe = '1' ELSE '1';
	rxdp <= usb_dp WHEN txoe = '0' ELSE 'Z' ;
	rxdn <= usb_dn WHEN txoe = '0' ELSE 'Z' ;
	rxd <= usb_dp;

	u_osc : SB_HFOSC
	GENERIC MAP(CLKHF_DIV => "0b00")
	PORT MAP(
		CLKHFEN => '1',
		CLKHFPU => '1',
		CLKHF => clk_hf
	);

	u_phy : usb_phy
	PORT MAP(
		clk => clk_hf,
		rst => '1', -- invert if the USB core expects active-high
		phy_tx_mode => '1',
		usb_rst => utmi_usb_rst,
		rxd => rxd,
		rxdp => rxdp,
		rxdn => rxdn,
		txdp => txdp,
		txdn => txdn,
		txoe => txoe,
		DataOut_i => utmi_dout,
		TxValid_i => utmi_txvalid,
		TxReady_o => utmi_txrdy,
		DataIn_o => utmi_din,
		RxValid_o => utmi_rxvalid,
		RxActive_o => utmi_rxactive,
		RxError_o => utmi_rxerror,
		LineState_o => utmi_line_state
	);

	a <= '1';	
	b <= '0';
	d <= '1';

  	u_and: and2 port map(a => a, b => b, y => c);
	u_or : or2  port map(a => c, b => d, y => dbg_io);

	rx_valid <= utmi_rxvalid;
	-- dbg_io <= utmi_usb_rst;

END ARCHITECTURE;
