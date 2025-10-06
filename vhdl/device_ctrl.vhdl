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
    signal current_state, next_state: state_type := IDLE;
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

    process(clk_i, rst_i)
    begin
        if rst_i = '0' then
            current_state <= IDLE;
        elsif rising_edge(clk_i) then
            current_state <= next_state;
        end if;
    end process;

    process(current_state, tx_ready_i, rx_valid_i, rx_active_i, data_rx_in_i, setup_data_count)
    begin
        case current_state is
            when IDLE => 

                setup_data_count <= 0;
                tx_valid_o <= '0';
                data_tx_out_o <= (others => '0');

                if rx_valid_i = '1' and rx_active_i = '1' then
                    next_state <= SETUP;
                else
                    next_state <= IDLE;
                end if;
            
            when SETUP =>
                setup_data_count <= 10;
                tx_valid_o <= '0';
                data_tx_out_o <= (others => '0');

                if rx_active_i = '0' then
                    next_state <= DATA;
                else
                    next_state <= SETUP;
                end if;
            
            when DATA =>
                if rx_active_i = '0' then
                    next_state <= IDLE;
                end if;
            
            when SEND_ACK =>
                data_tx_out_o <= x"D2"; -- ACK token
                tx_valid_o <= '1';

                if tx_ready_i = '1' then
                    tx_valid_o <= '0';
                    next_state <= EP0;
                else
                    next_state <= SEND_ACK;
                end if;

            when others => 
                next_state <= IDLE;
        end case;

    end process;

end architecture rtl;