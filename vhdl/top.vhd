library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top is
    port (
        clk_i : in std_logic;
        rst_n_i : in std_logic; -- active low

        -- USB differential pair
        dev_usb_dp_io : inout std_logic;
        dev_usb_dn_io : inout std_logic
    );
end entity top;

architecture rtl of top is
    -- sb_hfosc for 48mhz usb
    COMPONENT SB_HFOSC
		GENERIC (CLKHF_DIV : STRING := "0b00");
		PORT (
			CLKHFEN : IN STD_LOGIC;
			CLKHFPU : IN STD_LOGIC;
			CLKHF : OUT STD_LOGIC
		);
	END COMPONENT;

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

    component usb_transceiver
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

    component device_ctrl
        port (
            clk_i : in std_logic;
            rst_i : in std_logic;

            -- UTMI Interface
            data_tx_out_o : out std_logic_vector(7 downto 0);
            tx_valid_o : out std_logic;
            tx_ready_i : in std_logic;
            data_rx_in_i : in std_logic_vector(7 downto 0);
            rx_valid_i : in std_logic;
            rx_active_i : in std_logic;
            rx_error_o : out std_logic
        );
    end component device_ctrl;

begin

    hfosc_inst : SB_HFOSC
        generic map (
            CLKHF_DIV => "0b00"  -- 48MHz
        )
        port map (
            CLKHFEN => '1',
            CLKHFPU => '1',
            CLKHF => clk_48mhz
        );

    usb_rxtx : usb_transceiver
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

    device_ctrl_inst : device_ctrl
    port map (
        clk_i => clk_48mhz,
        rst_i => not rst_n_i,

        -- UTMI Interface
        data_tx_out_o => dev_data_tx_out_i,
        tx_valid_o => dev_tx_valid_i,
        tx_ready_i => dev_tx_ready_o,
        data_rx_in_i => dev_data_rx_in_o,
        rx_valid_i => dev_rx_valid_o,
        rx_active_i => dev_rx_active_o,
        rx_error_o => dev_rx_error_o
    );

end architecture rtl;
