library ieee;
use ieee.std_logic_1164.all;

entity hamming12_8_encoder is
    port (
        data_in  : in  std_logic_vector(7 downto 0);
        data_out : out std_logic_vector(11 downto 0)
    );
end entity hamming12_8_encoder;

architecture rtl of hamming12_8_encoder is

    signal p0, p1, p3, p7 : std_logic;

begin

    p0 <= data_in(0) xor data_in(1) xor data_in(3) xor data_in(4) xor data_in(6);
    p1 <= data_in(0) xor data_in(2) xor data_in(3) xor data_in(5) xor data_in(6);
    p3 <= data_in(1) xor data_in(2) xor data_in(3) xor data_in(7);
    p7 <= data_in(4) xor data_in(5) xor data_in(6) xor data_in(7);

    data_out(0)  <= p0;
    data_out(1)  <= p1;
    data_out(2)  <= data_in(0);
    data_out(3)  <= p3;
    data_out(4)  <= data_in(1);
    data_out(5)  <= data_in(2);
    data_out(6)  <= data_in(3);
    data_out(7)  <= p7;
    data_out(8)  <= data_in(4);
    data_out(9)  <= data_in(5);
    data_out(10) <= data_in(6);
    data_out(11) <= data_in(7);

end architecture rtl;