library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity usb_phy_tb is
end entity usb_phy_tb;

architecture tb of usb_phy_tb is

	constant clk_period : time := 20.833 ns;

	-- global signal
	signal clk : std_logic := '0';
	signal rst : std_logic := '1';

	signal usb_dp_io : std_logic := 'Z';
	signal usb_dn_io : std_logic := 'Z';

	-- USB pull resistors (device has pull-up on D+, host has pull-downs on both)
	-- In a real USB Full Speed device, there's a 1.5kΩ pull-up on D+
	-- We model this with weak '1' on D+ and weak '0' on D-
	signal usb_dp_pullup : std_logic := 'H';  -- Weak high (pull-up on D+)
	signal usb_dn_pulldown : std_logic := 'L';  -- Weak low (pull-down on D-)

	-- host signals
	signal host_tx_valid_i : std_logic := '0';
	signal host_tx_ready_o : std_logic;
	signal host_data_rx_in_o : std_logic_vector(7 downto 0);
	signal host_data_tx_out_i : std_logic_vector(7 downto 0);
	signal host_rx_valid_o : std_logic;
	signal host_rx_active_o : std_logic;
	signal host_rx_error_o : std_logic;
	signal host_line_state_o : std_logic_vector(1 downto 0);

	-- device signals
	signal dev_tx_valid_i : std_logic := '0';
	signal dev_tx_ready_o : std_logic;
	signal dev_data_rx_in_o : std_logic_vector(7 downto 0);
	signal dev_data_tx_out_i : std_logic_vector(7 downto 0);
	signal dev_rx_valid_o : std_logic;
	signal dev_rx_active_o : std_logic;
	signal dev_rx_error_o : std_logic;
	signal dev_line_state_o : std_logic_vector(1 downto 0);

begin

	-- Clock generation
	gen_60mhz: process
	begin
		clk <= '0';
		wait for clk_period / 2;
		clk <= '1';
		wait for clk_period / 2;
	end process gen_60mhz;

	host_uut: entity work.usb_transceiver
	port map (
		clk_i => clk,
		rst_i => rst,
		usb_dp_io => usb_dp_io,
		usb_dn_io => usb_dn_io,
		data_tx_out_i => host_data_tx_out_i,
		tx_valid_i => host_tx_valid_i,
		tx_ready_o => host_tx_ready_o,
		data_rx_in_o => host_data_rx_in_o,
		rx_valid_o => host_rx_valid_o,
		rx_active_o => host_rx_active_o,
		rx_error_o => host_rx_error_o,
		line_state_o => host_line_state_o
	);

	dev_uut: entity work.usb_transceiver
	port map (
		clk_i => clk,
		rst_i => rst,
		usb_dp_io => usb_dp_io,
		usb_dn_io => usb_dn_io,
		data_tx_out_i => dev_data_tx_out_i,
		tx_valid_i => dev_tx_valid_i,
		tx_ready_o => dev_tx_ready_o,
		data_rx_in_o => dev_data_rx_in_o,
		rx_valid_o => dev_rx_valid_o,
		rx_active_o => dev_rx_active_o,
		rx_error_o => dev_rx_error_o,
		line_state_o => dev_line_state_o
	);

	dev_ctrl: entity work.device_ctrl
	port map (
		clk_i => clk,
		rst_i => rst,
		data_tx_out_o => dev_data_tx_out_i,
		tx_valid_o => dev_tx_valid_i,
		tx_ready_i => dev_tx_ready_o,
		data_rx_in_i => dev_data_rx_in_o,
		rx_valid_i => dev_rx_valid_o,
		rx_active_i => dev_rx_active_o,
		rx_error_o => dev_rx_error_o
	);

	dev_shim : entity work.utmi_shim
	port map (
		clk_i => clk,
		rst_i => rst,

		utmi_data_tx_out_o => dev_data_tx_out_i,
		utmi_tx_valid_o => dev_tx_valid_i,
		utmi_tx_ready_i => dev_tx_ready_o,
		utmi_data_rx_in_i => dev_data_rx_in_o,
		utmi_rx_valid_i => dev_rx_valid_o,
		utmi_rx_active_i => dev_rx_active_o,
		utmi_rx_error_i => dev_rx_error_o,

		shim_rx_active_o => open,
		shim_rx_next_o => open,
		shim_rx_data_o => open,

		shim_tx_first_i => '0',
		shim_tx_next_o => open,
		shim_tx_last_i => '0',
		shim_tx_next_i => '1',
		shim_tx_data_i => (others => '0'),

		shim_hs_pid_o => open,
		shim_hs_pid_i => (others => '0'),
		shim_hs_req_i => '0',
		shim_hs_next_i => open
	);

	-- USB Pull Resistor Modeling
	-- Device has 1.5kΩ pull-up on D+ (indicates Full Speed device)
	-- Host/Hub has 15kΩ pull-downs on both D+ and D-
	-- When both sides are high-Z, the pull-up wins and D+ goes high (J state - idle)
	usb_dp_io <= usb_dp_pullup;  -- Apply weak pull-up to D+
	usb_dn_io <= usb_dn_pulldown;  -- Apply weak pull-down to D-

	host_stim_proc: process
	begin

		rst <= '0';
		wait for 100 ns;
		rst <= '1';
		wait for 100 ns;

		-- send setup packet
		host_tx_valid_i <= '1';
		wait for 1 ns;
		host_data_tx_out_i <= x"55";
		wait until falling_edge(host_tx_ready_o);

		host_tx_valid_i <= '1';
		host_data_tx_out_i <= x"00";
		wait until falling_edge(host_tx_ready_o);

		host_tx_valid_i <= '1';
		host_data_tx_out_i <= x"08";
		wait until falling_edge(host_tx_ready_o);
		host_tx_valid_i <= '0';

		wait for 2*clk_period;

		-- send data packet
		host_tx_valid_i <= '1';
		host_data_tx_out_i <= x"C3";
		wait until falling_edge(host_tx_ready_o);

		host_tx_valid_i <= '1';
		host_data_tx_out_i <= x"80";
		wait until falling_edge(host_tx_ready_o);

		host_tx_valid_i <= '1';
		host_data_tx_out_i <= x"06";
		wait until falling_edge(host_tx_ready_o);

		host_tx_valid_i <= '1';
		host_data_tx_out_i <= x"00";
		wait until falling_edge(host_tx_ready_o);

		host_tx_valid_i <= '1';
		host_data_tx_out_i <= x"01";
		wait until falling_edge(host_tx_ready_o);

		host_tx_valid_i <= '1';
		host_data_tx_out_i <= x"00";
		wait until falling_edge(host_tx_ready_o);

		host_tx_valid_i <= '1';
		host_data_tx_out_i <= x"00";
		wait until falling_edge(host_tx_ready_o);

		host_tx_valid_i <= '1';
		host_data_tx_out_i <= x"40";
		wait until falling_edge(host_tx_ready_o);

		host_tx_valid_i <= '1';
		host_data_tx_out_i <= x"00";
		wait until falling_edge(host_tx_ready_o);

		host_tx_valid_i <= '1';
		host_data_tx_out_i <= x"94";
		wait until falling_edge(host_tx_ready_o);

		host_tx_valid_i <= '1';
		host_data_tx_out_i <= x"DD";
		wait until falling_edge(host_tx_ready_o);

		host_tx_valid_i <= '0';

		wait for 10 us;

		-- send IN token to EP0
		host_tx_valid_i <= '1';
		host_data_tx_out_i <= x"69";
		wait until falling_edge(host_tx_ready_o);
		host_tx_valid_i <= '0';

		wait for 10 us;
		host_tx_valid_i <= '1';
		host_data_tx_out_i <= x"69";
		wait until falling_edge(host_tx_ready_o);
		host_tx_valid_i <= '0';

		wait;

	end process host_stim_proc;

end architecture tb;
