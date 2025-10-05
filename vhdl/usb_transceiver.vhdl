library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;

entity usb_transceiver is
    generic (
		usb_rst_det : boolean := TRUE
	);
    port (
        clk_i : in std_logic;
        rst_i : in std_logic;

        -- Transciever Interface
        usb_dp_io : inout std_logic;
        usb_dn_io : inout std_logic;

        -- UTMI Interface
        data_tx_out_i : in std_logic_vector(7 downto 0);
        tx_valid_i : in std_logic;
        tx_ready_o : out std_logic;
        data_rx_in_o : out std_logic_vector(7 downto 0);
        rx_valid_o : out std_logic;
        rx_active_o : out std_logic;
        rx_error_o : out std_logic;

        -- Debug
        line_state_o : out std_logic_vector(1 downto 0)
    );
end entity usb_transceiver;

architecture rtl of usb_transceiver is

    signal phy_tx_mode : std_logic := '1'; -- HIGH level for differential io mode (else single-ended)
    signal usb_rst : std_logic;
    signal rxdp, rxdn : std_logic;
    signal txdp, txdn, txoe : std_logic;

begin

    usb_phy_inst : entity work.usb_phy
    generic map (
        usb_rst_det => usb_rst_det
    )
    port map (
        clk => clk_i,
        rst => rst_i,
        phy_tx_mode => '1',
        usb_rst => usb_rst,
        rxd => rxdp,
        rxdp => rxdp,
        rxdn => rxdn,
        txdp => txdp,
        txdn => txdn,
        txoe => txoe,
        DataOut_i => data_tx_out_i,
        TxValid_i => tx_valid_i,
        TxReady_o => tx_ready_o,
        DataIn_o => data_rx_in_o,
        RxValid_o => rx_valid_o,
        RxActive_o => rx_active_o,
        RxError_o => rx_error_o,
        LineState_o => line_state_o
    );

    usb_dp_io <= txdp when txoe = '1' else 'Z';
    usb_dn_io <= txdn when txoe = '1' else 'Z';

end architecture rtl;