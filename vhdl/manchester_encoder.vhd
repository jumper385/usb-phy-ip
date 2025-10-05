library ieee;
use ieee.std_logic_1164.all;

entity manchester_encoder is
    port (
        clk, reset : in std_logic;
        v, d       : in std_logic;
        y          : out std_logic
    );
end manchester_encoder;

architecture moore_arch of manchester_encoder is
    type state_type is (idle, s0a, s0b, s1a, s1b);
    signal state_reg, state_next : state_type;
begin
    -- state register
    process (clk, reset)
    begin
        if (reset = '0') then
            state_reg <= idle;
        elsif (clk'event and clk = '1') then
            state_reg <= state_next;
        end if;
    end process;

    -- next-state logic
    process (state_reg, v, d)
    begin
        case state_reg is
            when idle =>
                if v = '0' then
                    state_next <= idle;
                else
                    if d = '0' then
                        state_next <= s0a;
                    else
                        state_next <= s1a;
                    end if;
                end if;
            when s0a =>
                state_next <= s0b;
            when s1a =>
                state_next <= s1b;
            when s0b =>
                if v = '0' then
                    state_next <= idle;
                else
                    if d = '0' then
                        state_next <= s0a;
                    else
                        state_next <= s1a;
                    end if;
                end if;
            when s1b =>
                if v = '0' then
                    state_next <= idle;
                else
                    if d = '0' then
                        state_next <= s0a;
                    else
                        state_next <= s1a;
                    end if;
                end if;
        end case;
    end process;

    -- Moore output logic
    y <= '1' when state_reg = s1b or state_reg = s0a else
        '0';

end moore_arch;