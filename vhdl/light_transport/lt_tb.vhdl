library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lt_tb is   
end entity lt_tb;

architecture behaviour of lt_tb is

    -- globals
    constant clk_100mhz_period : time := 10 ns;
    constant clk_50mhz_period : time := 20 ns;
    constant clk_25mhz_period : time := 40 ns;
    signal clk_100mhz : std_logic := '0';
    signal clk_50mhz : std_logic := '0';
    signal clk_25mhz : std_logic := '0';

    -- host
    signal host_tram_wr_en : std_logic;
    signal host_reset : std_logic;
    signal host_bitt_in : std_logic;
    signal host_man_out : std_logic;
    signal host_rd_addr_o : std_logic_vector(10 downto 0);

begin

    -- clock generation
    clk100mhz_process : process
    begin
        clk_100mhz <= '0';
        wait for clk_100mhz_period/2;
        clk_100mhz <= '1';
        wait for clk_100mhz_period/2;
    end process;

    clk50mhz_process : process
    begin
        clk_50mhz <= '0';
        wait for clk_50mhz_period/2;
        clk_50mhz <= '1';
        wait for clk_50mhz_period/2;
    end process;

    clk25mhz_process : process
    begin
        clk_25mhz <= '0';
        wait for clk_25mhz_period/2;
        clk_25mhz <= '1';
        wait for clk_25mhz_period/2;
    end process;

    -- DUT instantiation
    lt_tx_inst : entity work.lt_tx
        generic map (
            BITS => 12,
            mlength => 11
        )
        port map (
            clk_serial_i => clk_50mhz,
            clk_manchester_i => clk_25mhz,
            rst_i => host_reset,
            din_i => x"ABC",
            din_length_i => "00000001011", -- 11 bits
            din_enable_i => '1',
            buff_rd_addr_o => (others => '0'),
            din_sent_o => open,
            din_rx_error_o => open,

            buff_rd_addr_o => host_rd_addr_o,

            dout_o => host_man_out
        );

    stimulus : process
    begin



        wait;
    end process;

end behaviour ; -- behaviour