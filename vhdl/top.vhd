library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top is
	port (
		rst_n                : in    STD_LOGIC;
		usb_pu               : out   STD_LOGIC;
		usb_dp               : inout STD_LOGIC;
		usb_dn               : inout STD_LOGIC;
		led                  : out   STD_LOGIC;

		rx_valid             : out   STD_LOGIC;
		dbg_io1              : out   STD_LOGIC;
		dbg_io2              : out   STD_LOGIC;

		usb_feedthrough_dp_o : out   STD_LOGIC; -- for test jig
		usb_feedthrough_dn_o : out   STD_LOGIC -- for test jig
	);
end entity top;

architecture rtl of top is

	component SB_HFOSC is
		generic (
			CLKHF_DIV :     STRING := "0b00"
		);
		port (
			CLKHFEN   : in  STD_LOGIC;
			CLKHFPU   : in  STD_LOGIC;
			CLKHF     : out STD_LOGIC
		);
	end component SB_HFOSC;

	component honeycomb_fs_phy is
		port (
			rst_i             : in    STD_LOGIC;                    -- high = reset; low = normal
			clk_48mhz_i       : in    STD_LOGIC;
			fs_pu_o           : out   STD_LOGIC;                    -- output to pull up resistor; optional

			-- usb interface
			usb_dp_io         : inout STD_LOGIC;                    -- ensure 1.5k pull up here
			usb_dn_io         : inout STD_LOGIC;

			-- utmi tx interface
			utmi_dout_i       : in    STD_LOGIC_VECTOR(7 downto 0); -- stage tx data here
			utmi_txvalid_i    : in    STD_LOGIC;                    -- request to tx here; set high
			utmi_txrdy_o      : out   STD_LOGIC;                    -- high = transmitting state

			-- utmi rx interface
			utmi_din_o        : out   STD_LOGIC_VECTOR(7 downto 0); -- all rx line data here
			utmi_rxvalid_o    : out   STD_LOGIC;                    -- high rx is good to read
			utmi_rxactive_o   : out   STD_LOGIC;                    -- high if rx'ing
			utmi_rxerror_o    : out   STD_LOGIC;                    -- high if error

			-- utmi debug interface
			utmi_line_state_o : out   STD_LOGIC_VECTOR(1 downto 0); -- probe bit 0 for usb state
			utmi_usb_rst_o    : out   STD_LOGIC                     -- high if usb phy is being reset
		);
	end component honeycomb_fs_phy;

	component handshake_sender is
		port (
			en               : in  STD_LOGIC;

			clk              : in  STD_LOGIC;
			utmi_dout_o      : out STD_LOGIC_VECTOR(7 downto 0);
			utmi_txvalid_o   : out STD_LOGIC;

			setup_detected_i : in  STD_LOGIC;
			data_detected_i  : in  STD_LOGIC;
			in_detected_i    : in  STD_LOGIC;
			utmi_txrdy_i     : in  STD_LOGIC;

			dbg_state_o      : out STD_LOGIC_VECTOR(2 downto 0)
		);
	end component handshake_sender;

	-- constants
	constant PID_SETUP     : STD_LOGIC_VECTOR(7 downto 0) := x"2D";
	constant PID_DATA0     : STD_LOGIC_VECTOR(7 downto 0) := x"C3";
	constant PID_IN        : STD_LOGIC_VECTOR(7 downto 0) := x"69";

	-- signals ...
	signal txoe            : STD_LOGIC;
	signal rxd             : STD_LOGIC;

	signal utmi_dout       : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
	signal utmi_txvalid    : STD_LOGIC                    := '0';
	signal utmi_txrdy      : STD_LOGIC;
	signal utmi_din        : STD_LOGIC_VECTOR(7 downto 0);
	signal utmi_rxvalid    : STD_LOGIC;
	signal utmi_rxactive   : STD_LOGIC;
	signal utmi_rxerror    : STD_LOGIC;
	signal utmi_line_state : STD_LOGIC_VECTOR(1 downto 0);
	signal utmi_usb_rst    : STD_LOGIC;

	signal rxdp            : STD_LOGIC;
	signal rxdn            : STD_LOGIC;
	signal txdp            : STD_LOGIC;
	signal txdn            : STD_LOGIC;

	signal clk_hf          : STD_LOGIC;
	signal setup_detected  : STD_LOGIC;
	signal data_detected   : STD_LOGIC;
	signal in_detected     : STD_LOGIC;

	signal dbg_state       : STD_LOGIC_VECTOR(2 downto 0);

begin
	led                  <= not rst_n;

	rxd                  <= rxdp;

	u_osc: component SB_HFOSC
	generic map (
		CLKHF_DIV         => "0b00"
	)
	port map (
		CLKHFEN           => '1',
		CLKHFPU           => '1',
		CLKHF             => clk_hf
	);

	usb_phy: component honeycomb_fs_phy
	port map (
		rst_i             => '1',
		clk_48mhz_i       => clk_hf,
		fs_pu_o           => usb_pu,

		usb_dp_io         => usb_dp,
		usb_dn_io         => usb_dn,

		utmi_dout_i       => utmi_dout,
		utmi_txvalid_i    => utmi_txvalid,
		utmi_txrdy_o      => utmi_txrdy,

		utmi_din_o        => utmi_din,
		utmi_rxvalid_o    => utmi_rxvalid,
		utmi_rxactive_o   => utmi_rxactive,
		utmi_rxerror_o    => utmi_rxerror,

		utmi_line_state_o => utmi_line_state,
		utmi_usb_rst_o    => utmi_usb_rst
	);

	hs_sender_inst: component handshake_sender
	port map (
		en                => not rst_n,
		clk               => clk_hf,

		utmi_dout_o       => utmi_dout,
		utmi_txvalid_o    => utmi_txvalid,

		setup_detected_i  => setup_detected,
		data_detected_i   => data_detected,
		in_detected_i     => in_detected,
		utmi_txrdy_i      => utmi_txrdy,

		dbg_state_o       => dbg_state
	);

	rx_valid             <= utmi_rxvalid;
	dbg_io1              <= in_detected;
	dbg_io2              <= data_detected;

	usb_feedthrough_dp_o <= utmi_line_state(0);               -- for test jig
	usb_feedthrough_dn_o <= utmi_line_state(1);               -- for test jig

end architecture rtl;
