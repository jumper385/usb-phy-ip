library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top is
    port (
        rst_n    : in    STD_LOGIC;
        usb_pu   : out   STD_LOGIC;
        usb_dp   : inout std_logic;
        usb_dn   : inout std_logic;
        led      : out   STD_LOGIC;

        rx_valid : out   STD_LOGIC;
        dbg_io   : out   STD_LOGIC
    );
end entity top;

architecture rtl of top is

    component usb_phy is
        port (
            clk              : in  STD_LOGIC;
            rst              : in  STD_LOGIC;
            phy_tx_mode      : in  STD_LOGIC;
            usb_rst          : out STD_LOGIC;
            rxd, rxdp, rxdn  : in  STD_LOGIC;
            txdp, txdn, txoe : out STD_LOGIC;
            DataOut_i        : in  STD_LOGIC_VECTOR(7 downto 0);
            TxValid_i        : in  STD_LOGIC;
            TxReady_o        : out STD_LOGIC;
            DataIn_o         : out STD_LOGIC_VECTOR(7 downto 0);
            RxValid_o        : out STD_LOGIC;
            RxActive_o       : out STD_LOGIC;
            RxError_o        : out STD_LOGIC;
            LineState_o      : out STD_LOGIC_VECTOR(1 downto 0)
        );
    end component usb_phy;

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

    signal rxdp            : std_logic;
    signal rxdn            : std_logic;
    signal txdp            : std_logic;
    signal txdn            : std_logic;

    signal clk_hf          : std_logic;

begin
    led      <= not rst_n;

    rxd      <= rxdp;

    u_osc: component SB_HFOSC
    generic map (
        CLKHF_DIV   => "0b00"
    )
    port map (
        CLKHFEN     => '1',
        CLKHFPU     => '1',
        CLKHF       => clk_hf
    );

    u_phy: component usb_phy
    port map (
        clk         => clk_hf,
        rst         => '1',
        phy_tx_mode => '0',
        usb_rst     => utmi_usb_rst,
        rxd         => rxd,
        rxdp        => rxdp,
        rxdn        => rxdn,
        txdp        => txdp,
        txdn        => txdn,
        txoe        => txoe,
        DataOut_i   => utmi_dout,
        TxValid_i   => utmi_txvalid,
        TxReady_o   => utmi_txrdy,
        DataIn_o    => utmi_din,
        RxValid_o   => utmi_rxvalid,
        RxActive_o  => utmi_rxactive,
        RxError_o   => utmi_rxerror,
        LineState_o => utmi_line_state
    );

    usb_dp <= txdp when txoe = '0' else 'Z'; -- ffs. txoe must be low to transmit
    usb_dn <= txdn when txoe = '0' else 'Z';

    rxdp     <= usb_dp;
    rxdn     <= usb_dn;

    usb_pu   <= '1';                         -- note: icesugar has the pull routed to a pin... annoyingly

    rx_valid <= utmi_rxvalid;
    dbg_io   <= utmi_rxvalid;

end architecture rtl;
