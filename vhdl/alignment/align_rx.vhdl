library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity align_rx is
    port (
        clk_i        : in  std_logic;
        rst_i        : in  std_logic;
        align_en_i   : in  std_logic;
        align_sig_i  : in  std_logic;
        is_aligned_o : out std_logic
    );
end entity;

architecture arch of align_rx is

    type state_type is (IDLE, RECEIVING);
    signal rx_cs, rx_ns : state_type := IDLE;
    signal bit_counter, bit_counter_ns: integer range 0 to 8 := 0;
    signal rx_byte : std_logic_vector(8 downto 0) := (others => '0');
    signal is_aligned : std_logic := '0';

begin

    process(clk_i, rst_i)
    begin
        if rst_i = '0' or align_en_i = '0' then
            -- reset state
            rx_cs <= IDLE;
            bit_counter <= 0;
        elsif rising_edge(clk_i) then
            -- state machine
            rx_cs <= rx_ns;
            bit_counter <= bit_counter_ns;
        end if;
    end process;

    process(rx_cs, align_en_i, align_sig_i, bit_counter)
    begin
        case rx_cs is

            when IDLE =>
                if falling_edge(align_sig_i) then
                    rx_ns <= RECEIVING;
                else
                    rx_ns <= IDLE;
                end if;

            when RECEIVING =>
                if bit_counter = 8 then
                    rx_ns <= IDLE;
                else
                    rx_ns <= RECEIVING;
                    bit_counter_ns <= bit_counter + 1;
                end if;

            when others =>
                rx_ns <= IDLE;

        end case;
    end process;

    process(rx_cs, bit_counter)
    begin
        case rx_cs is

            when IDLE =>
                is_aligned <= '0';
                rx_byte <= (others => '0');

            when RECEIVING =>
                rx_byte(bit_counter) <= align_sig_i;
                
            when others =>
                is_aligned <= '0';

        end case;
    end process;

end arch ; -- arch