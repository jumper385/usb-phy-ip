library ieee;
use ieee.std_logic_1164.all;

entity device_ctrl is
    port (
        clk_i : in std_logic;
        rst_i : in std_logic;

        -- UTMI Interface
        data_tx_out_o : out std_logic_vector(7 downto 0) := (others => '0');
        tx_valid_o : out std_logic := '0';
        tx_ready_i : in std_logic;
        data_rx_in_i : in std_logic_vector(7 downto 0);
        rx_valid_i : in std_logic;
        rx_active_i : in std_logic;
        rx_error_o : out std_logic
    );
end entity device_ctrl;

architecture rtl of device_ctrl is

    type state_type is (IDLE, SETUP, DATA, SEND_ACK, EP0, SEND_NAK);
    signal current_state: state_type := IDLE;
    signal setup_data_count : integer := 0;

    component usb_transceiver
        port (
            clk_i : in std_logic;
            rst_i : in std_logic;
            usb_dp_io : inout std_logic;
            usb_dn_io : inout std_logic;
            data_tx_out_i : in std_logic_vector(7 downto 0);
            tx_valid_i : in std_logic;
            tx_ready_o : out std_logic;
            data_rx_in_o : out std_logic_vector(7 downto 0);
            rx_valid_o : out std_logic;
            rx_active_o : out std_logic;
            rx_error_o : out std_logic;
            line_state_o : out std_logic_vector(1 downto 0)
        );
    end component usb_transceiver;

begin

    process(current_state, data_rx_in_i, rx_valid_i, tx_ready_i)
    begin
        if rising_edge(rx_valid_i) and data_rx_in_i = x"55" then
            current_state <= SETUP;
            setup_data_count <= 0;
        end if;

        if current_state = SETUP then
            if rx_valid_i = '1' then
                if data_rx_in_i = x"C3" then
                    current_state <= DATA;
                    setup_data_count <= 10;
                end if;
            end if;
        end if;

        if current_state = DATA then
            if rx_active_i = '0' then
                setup_data_count <= 0;
                current_state <= SEND_ACK;
            end if;
        end if;

        if current_state = SEND_ACK then
            data_tx_out_o <= x"D2";
            tx_valid_o <= '1';

            if falling_edge(tx_ready_i) then
                tx_valid_o <= '0';
                current_state <= EP0;
            end if;
        end if;

        if current_state = EP0 then
            if rx_valid_i = '0' then
                if data_rx_in_i = x"69" then
                    current_state <= SEND_NAK;
                end if;
            end if;
        end if;

        if current_state = SEND_NAK then
            data_tx_out_o <= x"5A";
            tx_valid_o <= '1';

            if falling_edge(tx_ready_i) then
                tx_valid_o <= '0';
                current_state <= EP0;
            else
                current_state <= IDLE;
            end if;
        end if;

    end process;

end architecture rtl;