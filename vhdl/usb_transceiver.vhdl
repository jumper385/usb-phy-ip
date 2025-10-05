library ieee;
use ieee.std_logic_1164.all;

entity usb_transceiver is
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

    component usb_phy
        port (
            clk : in std_logic;
            rst : in std_logic;
            phy_tx_mode : in std_logic;
            usb_rst : out std_logic;
            rxd : in std_logic;
            rxdp : in std_logic;
            rxdn : in std_logic;
            txdp : out std_logic;
            txdn : out std_logic;
            txoe : out std_logic;
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

begin

    usb_phy_inst : usb_phy
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

    usb_dp_io <= txdp when txoe = '0' else 'Z';
    usb_dn_io <= txdn when txoe = '0' else 'Z';

    rxdp <= usb_dp_io;
    rxdn <= usb_dn_io;

end architecture rtl;