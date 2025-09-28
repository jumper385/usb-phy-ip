LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.numeric_std.all;

ENTITY clk_divider IS
    GENERIC (Freq_in : INTEGER := 12500000); -- 50MHz clock on DE-10 Lite FPGA board
    PORT (
        clk_in : IN STD_LOGIC;
        reset : IN STD_LOGIC;
        clk_out : OUT STD_LOGIC

    );
END clk_divider;

ARCHITECTURE Behav OF clk_divider IS
    SIGNAL temp : STD_LOGIC;
    SIGNAL counter : INTEGER;
BEGIN
    frequency_divider : PROCESS (reset, clk_in)
    BEGIN
        IF (reset = '1') THEN
            temp <= '0';
            counter <= 0;
        ELSIF rising_edge(clk_in) THEN
            IF (counter = Freq_in/2) THEN
                temp <= NOT(temp);
                counter <= 0;
            ELSE
                counter <= counter + 1;
            END IF;
        END IF;
    END PROCESS;
    clk_out <= temp;
END Behav;