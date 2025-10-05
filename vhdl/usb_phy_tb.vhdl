library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity usb_phy_tb is
end entity usb_phy_tb;

architecture tb of usb_phy_tb is

	constant clk_period : time := 28.833333 ns;

	component usb_phy is
		generic (
			usb_rst_det : boolean := TRUE
		);
		port (
			clk : in std_logic; -- 60 MHz
			rst : in std_logic;
			phy_tx_mode : in std_logic; -- HIGH level for differential io mode (else single-ended)
			usb_rst : out std_logic;
			-- Transciever Interface
			rxd, rxdp, rxdn : in std_logic;
			txdp, txdn, txoe : out std_logic;
			-- UTMI Interface
			DataOut_i : in std_logic_vector(7 downto 0);
			TxValid_i : in std_logic;
			TxReady_o : out std_logic;
			DataIn_o : out std_logic_vector(7 downto 0);
			RxValid_o : out std_logic;
			RxActive_o : out std_logic;
			RxError_o : out std_logic;
			LineState_o : out std_logic_vector(1 downto 0)
		);
	end component usb_phy;

	-- global control signals
	signal clk : std_logic := '0';
	signal rst : std_logic := '0';

    -- host phy signals
	signal host_phy_tx_mode : std_logic := '1';
	signal host_usb_rst : std_logic;
	signal host_rxd, host_rxdp, host_rxdn : std_logic := '0';
	signal host_txdp, host_txdn, host_txoe : std_logic;
	signal host_DataOut_i : std_logic_vector(7 downto 0) := (others => '0');
	signal host_TxValid_i : std_logic := '0';
	signal host_TxReady_o : std_logic;
	signal host_DataIn_o : std_logic_vector(7 downto 0);
	signal host_RxValid_o : std_logic;
	signal host_RxActive_o : std_logic;
	signal host_RxError_o : std_logic;
	signal host_LineState_o : std_logic_vector(1 downto 0);

    -- device phy signals
	signal dev_phy_tx_mode : std_logic := '1';
	signal dev_usb_rst : std_logic;
	signal dev_rxd, dev_rxdp, dev_rxdn : std_logic := '0';
	signal dev_txdp, dev_txdn, dev_txoe : std_logic;
	signal dev_DataOut_i : std_logic_vector(7 downto 0) := (others => '0');
	signal dev_TxValid_i : std_logic := '0';
	signal dev_TxReady_o : std_logic;
	signal dev_DataIn_o : std_logic_vector(7 downto 0);
	signal dev_RxValid_o : std_logic;
	signal dev_RxActive_o : std_logic;
	signal dev_RxError_o : std_logic;
	signal dev_LineState_o : std_logic_vector(1 downto 0);

	signal usb_dp, usb_dn : std_logic;

begin

	-- Clock generation
	gen_48mhz: process
	begin
		clk <= '0';
		wait for clk_period / 2;
		clk <= '1';
		wait for clk_period / 2;
	end process gen_48mhz;

	-- USB Host PHY
	usb_host_phy_inst: entity work.usb_phy
	generic map (
		usb_rst_det => TRUE
	)
	port map (
		clk => clk,
		rst => rst,
		phy_tx_mode => host_phy_tx_mode,
		usb_rst => host_usb_rst,
		rxd => host_rxd,
		rxdp => host_rxdp,
		rxdn => host_rxdn,
		txdp => host_txdp,
		txdn => host_txdn,
		txoe => host_txoe,
		DataOut_i => host_DataOut_i,
		TxValid_i => host_TxValid_i,
		TxReady_o => host_TxReady_o,
		DataIn_o => host_DataIn_o,
		RxValid_o => host_RxValid_o,
		RxActive_o => host_RxActive_o,
		RxError_o => host_RxError_o,
		LineState_o => host_LineState_o
	);

	-- USB Device PHY
	usb_device_phy_inst: entity work.usb_phy
	generic map (
		usb_rst_det => TRUE
	)
	port map (
		clk => clk,
		rst => rst,
		phy_tx_mode => dev_phy_tx_mode,
		usb_rst => dev_usb_rst,
		rxd => dev_rxd,
		rxdp => dev_rxdp,
		rxdn => dev_rxdn,
		txdp => dev_txdp,
		txdn => dev_txdn,
		txoe => dev_txoe,
		DataOut_i => dev_DataOut_i,
		TxValid_i => dev_TxValid_i,
		TxReady_o => dev_TxReady_o,
		DataIn_o => dev_DataIn_o,
		RxValid_o => dev_RxValid_o,
		RxActive_o => dev_RxActive_o,
		RxError_o => dev_RxError_o,
		LineState_o => dev_LineState_o
	);

	-- USB bus connections (host to device)
	-- Both host and device can drive the bus (with pull-ups for idle state)
	usb_dp <= host_txdp when host_txoe = '0' else
	          dev_txdp when dev_txoe = '0' else
	          'H';  -- Weak pull-up for J-state (idle)
	usb_dn <= host_txdn when host_txoe = '0' else
	          dev_txdn when dev_txoe = '0' else
	          'L';  -- Weak pull-down

	-- Host receives from USB bus (but not its own transmission)
	host_rxdp <= usb_dp;
	host_rxdn <= usb_dn;
	host_rxd <= usb_dp;
	
	-- Device receives from USB bus (but not its own transmission)
	dev_rxdp <= usb_dp;
	dev_rxdn <= usb_dn;
	dev_rxd <= usb_dp; 

    -- send setup command as usb host
    host_stim_proc: process is
    begin
        -- hold reset state for 100 ns.
        rst <= '0';
        wait for 100 ns;
        rst <= '1';
        wait for 100 ns;

        -- send a packet
        host_DataOut_i <= "00000000";
        host_TxValid_i <= '1';
        wait until rising_edge(host_TxReady_o);
        host_DataOut_i <= x"2D";
        host_TxValid_i <= '1';
        wait until rising_edge(host_TxReady_o);
        host_DataOut_i <= x"EA";
        host_TxValid_i <= '1';
        wait until rising_edge(host_TxReady_o);
        host_DataOut_i <= x"BE";
        host_TxValid_i <= '1';
        wait until rising_edge(host_TxReady_o);
        host_DataOut_i <= x"EF";
        host_TxValid_i <= '1';
        wait until rising_edge(host_TxReady_o);
        wait for clk_period;
        host_TxValid_i <= '0';
        host_DataOut_i <= (others => '0');

        -- hold for a while
        wait for 500 ns;

        -- finish simulation
        wait;
    end process;

	dev_stim_proc: process is
	begin
		wait until rising_edge(dev_RxValid_o);
		assert dev_DataIn_o = x"DE" report "Unexpected data received" severity error;

		wait until rising_edge(dev_RxValid_o);
		assert dev_DataIn_o = x"EA" report "Unexpected data received" severity error;

		wait until rising_edge(dev_RxValid_o);
		assert dev_DataIn_o = x"BE" report "Unexpected data received" severity error;

		wait until rising_edge(dev_RxValid_o);
		assert dev_DataIn_o = x"EF" report "Unexpected data received" severity error;

		wait;
	end process;

end architecture tb;
