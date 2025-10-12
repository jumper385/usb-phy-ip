library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity align_tx is
    port (
        clk_i        : in  std_logic;  -- clock
        rst_i        : in  std_logic;  -- active-high synchronous reset
        align_en_i   : in  std_logic;  -- enable: when '1' we stream the pattern
        align_sig_o  : out std_logic   -- serial bit output (MSB first)
    );
end entity;

architecture rtl of align_tx is
    signal align_pattern : std_logic_vector(7 downto 0) := x"BC"; -- 1011_1100
    type state_type is (IDLE, START_BIT, SEND, STOP_BIT);
    signal align_cs, align_ns : state_type := IDLE;
    signal bit_counter, bit_counter_ns: integer range 0 to 8 := 0;
begin
    align_pattern <= x"BC"; -- 1011_1100

    reg_p : process(clk_i) is
    begin
        if rising_edge(clk_i) then
            if rst_i = '0' or align_en_i = '0' then
                align_cs        <= IDLE;
                bit_counter <= 0;
            else
                align_cs        <= align_ns;
                bit_counter <= bit_counter_ns;
            end if;
        end if;
    end process;

    -- Next-state and next-output logic
    comb_p : process(align_cs, bit_counter, align_en_i)
    begin
        -- defaults
        align_ns          <= align_cs;
        bit_counter_ns    <= 0;
        align_sig_o     <= '1';

        case align_cs is
            when IDLE =>
                bit_counter_ns <= 0;

                if align_en_i = '1' then
                    align_ns   <= START_BIT;
                end if;
            
            when START_BIT =>
                align_sig_o <= '0'; -- start bit
                align_ns <= SEND; -- move on after start bit
                bit_counter_ns <= 0;

            when SEND =>
                align_sig_o <= align_pattern(bit_counter);
                if bit_counter = 7 then
                    align_ns <= STOP_BIT; -- move on after sending all bits
                else
                    bit_counter_ns <= bit_counter + 1;
                end if;
            
            when STOP_BIT =>
                align_sig_o <= '1'; -- stop bit
                align_ns <= IDLE; -- move on after stop bit

        end case;
    end process;

end architecture;