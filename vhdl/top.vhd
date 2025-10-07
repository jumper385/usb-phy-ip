library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top is
	port (
		clk_i : in std_logic;
		rst_n_i : in std_logic; -- active low

		-- PORT CONFIGS
		dev_usb_host_en : out std_logic;
		dev_usb_ls_en : out std_logic;
		ulpi_reset_o : out std_logic;

		-- USB differential pair
		dev_usb_dp_io : inout std_logic;
		dev_usb_dn_io : inout std_logic;

		-- debug led
		led_r_o : out std_logic := '1';
		led_g_o : out std_logic := '1';
		led_b_o : out std_logic := '1';

		-- debug io
		dbg_io_o : out std_logic

	);
end entity top;

architecture rtl of top is

	-- sb_hfosc for 48mhz usb
	component SB_HFOSC is
		generic (
			CLKHF_DIV : STRING := "0b00"
		);
		port (
			CLKHFEN : in STD_LOGIC;
			CLKHFPU : in STD_LOGIC;
			CLKHF : out STD_LOGIC
		);
	end component SB_HFOSC;

	signal clk_48mhz : std_logic;

	-- USB PHY signals
	signal dev_tx_valid_i : std_logic := '0';
	signal dev_tx_ready_o : std_logic;
	signal dev_data_tx_out_i : std_logic_vector(7 downto 0);
	signal dev_rx_valid_o : std_logic;
	signal dev_rx_active_o : std_logic;
	signal dev_data_rx_in_o : std_logic_vector(7 downto 0);
	signal dev_rx_error_o : std_logic;
	signal dev_line_state_o : std_logic_vector(1 downto 0);

	component usb_transceiver is
		port (
			clk_i : in std_logic;
			rst_i : in std_logic;

			-- UTMI Interface
			tx_valid_i : in std_logic;
			tx_ready_o : out std_logic;
			data_tx_out_i : in std_logic_vector(7 downto 0);
			rx_valid_o : out std_logic;
			rx_active_o : out std_logic;
			data_rx_in_o : out std_logic_vector(7 downto 0);
			rx_error_o : out std_logic;
			line_state_o : out std_logic_vector(1 downto 0);

			-- USB differential pair
			usb_dp_io : inout std_logic;
			usb_dn_io : inout std_logic
		);
	end component usb_transceiver;

	component utmi_shim is
		port (
			clk_i : in std_logic;
			rst_i : in std_logic;

			-- UTMI Interface
			utmi_data_tx_out_o : out std_logic_vector(7 downto 0);
			utmi_tx_valid_o : out std_logic;
			utmi_tx_ready_i : in std_logic;
			utmi_data_rx_in_i : in std_logic_vector(7 downto 0);
			utmi_rx_valid_i : in std_logic;
			utmi_rx_active_i : in std_logic;
			utmi_rx_error_i : in std_logic;

			-- SHIM Interface
			shim_rx_active_o : out std_logic;
			shim_rx_next_o : out std_logic;
			shim_rx_data_o : out std_logic_vector(7 downto 0);

			shim_tx_first_i : in std_logic;
			shim_tx_last_i : in std_logic;
			shim_tx_next_i : in std_logic;
			shim_tx_data_i : in std_logic_vector(7 downto 0);
			shim_tx_next_o : out std_logic;

			shim_hs_pid_o : out std_logic_vector(3 downto 0);
			shim_hs_pid_i : in std_logic_vector(3 downto 0);
			shim_hs_req_i : in std_logic;
			shim_hs_next_i : in std_logic
		);
	end component utmi_shim;

begin

	led_r_o <= '1';
	led_g_o <= '1';
	led_b_o <= '1';

	dev_usb_host_en <= '1';
	dev_usb_ls_en <= '0';
	ulpi_reset_o <= '1';

	hfosc_inst: component SB_HFOSC
	generic map (
		CLKHF_DIV => "0b00" -- 48MHz
	)
	port map (
		CLKHFEN => '1',
		CLKHFPU => '1',
		CLKHF => clk_48mhz
	);

	usb_rxtx: component usb_transceiver
	port map (
		clk_i => clk_48mhz,
		rst_i => not rst_n_i,

		-- UTMI Interface
		tx_valid_i => dev_tx_valid_i,
		tx_ready_o => dev_tx_ready_o,
		data_tx_out_i => dev_data_tx_out_i,
		rx_valid_o => dev_rx_valid_o,
		rx_active_o => dev_rx_active_o,
		data_rx_in_o => dev_data_rx_in_o,
		rx_error_o => dev_rx_error_o,
		line_state_o => dev_line_state_o,

		-- USB differential pair
		usb_dp_io => dev_usb_dp_io,
		usb_dn_io => dev_usb_dn_io
	);

	dev_shim: entity work.utmi_shim
	port map (
		clk_i => clk_48mhz,
		rst_i => rst_n_i,

		utmi_data_tx_out_o => dev_data_tx_out_i,
		utmi_tx_valid_o => dev_tx_valid_i,
		utmi_tx_ready_i => dev_tx_ready_o,
		utmi_data_rx_in_i => dev_data_rx_in_o,
		utmi_rx_valid_i => dev_rx_valid_o,
		utmi_rx_active_i => dev_rx_active_o,
		utmi_rx_error_i => dev_rx_error_o,

		shim_rx_active_o => dbg_io_o,
		shim_rx_next_o => open,
		shim_rx_data_o => open,

		shim_tx_first_i => '0',
		shim_tx_next_o => open,
		shim_tx_last_i => '0',
		shim_tx_next_i => '1',
		shim_tx_data_i => (others => '0'),

		shim_hs_pid_o => open,
		shim_hs_det_o => open,
		shim_hs_send_ack_i => '0'
	);


end architecture rtl;
