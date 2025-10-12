library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- consists of serialiser + manchester encoder

entity lt_tx is
    generic(
        BITS : INTEGER := 12; -- Number of bits being encoded
        mlength : INTEGER := 11 -- Number of bits in the length message (not including the sync)
    );
    port(
        -- global
        clk_serial_i : in STD_LOGIC;
        clk_manchester_i : in STD_LOGIC;
        rst_i : in STD_LOGIC;

        -- ctrl interface
        din_i : in STD_LOGIC_VECTOR(BITS-1 downto 0);
        din_length_i : in std_logic_vector (mlength-1 downto 0);
        din_enable_i : in STD_LOGIC;
        din_sent_o : out STD_LOGIC;
        din_rx_error_o : out STD_LOGIC;

        -- buffer interface
        buff_rd_addr_o : out STD_LOGIC_VECTOR (mlength-1 downto 0);

        -- lt interface
        dout_o : out STD_LOGIC -- manchester output
    );

end entity lt_tx;

architecture arch of lt_tx is

    component manchester_encoder
        port (
            clk, reset : in std_logic;
            v, d       : in std_logic;
            y          : out std_logic
        );
    end component;

    component serialiser
        generic(
            BITS : INTEGER := 12;
            mlength : INTEGER := 11
        );
        port(
            clk : in STD_LOGIC;
            message : in STD_LOGIC_VECTOR(BITS-1 downto 0);
            tx_length : in std_logic_vector (mlength-1 downto 0);
            dout : out STD_LOGIC;
            rd_addr : out STD_LOGIC_VECTOR (mlength-1 downto 0);
            message_sent : out STD_LOGIC;
            reset : in STD_LOGIC;
            tx_err_sent : out STD_LOGIC;
            ena_re : in STD_LOGIC; -- error enable; starts error fsm
            ena_t : in STD_LOGIC
        );
    end component;

    signal serial_dout : std_logic;
    signal man_enable : std_logic;
    signal man_din : std_logic;
    signal serial_err_en : std_logic := '0';

begin

    u_serialiser : serialiser
        generic map (
            BITS => BITS,
            mlength => mlength
        )
        port map (
            clk => clk_serial_i,
            message => din_i,
            tx_length => din_length_i,
            dout => serial_dout,
            rd_addr => buff_rd_addr_o,
            message_sent => din_sent_o,
            reset => rst_i,
            tx_err_sent => din_rx_error_o,
            ena_re => serial_err_en,
            ena_t => din_enable_i
        );
    
    u_manchester : manchester_encoder
        port map (
            clk => clk_manchester_i,
            reset => rst_i,
            v => man_enable,
            d => man_din,
            y => dout_o  
        );

end arch;