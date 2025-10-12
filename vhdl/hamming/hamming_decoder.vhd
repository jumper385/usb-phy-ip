library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity hamming12_8_decoder is
    port (
        data_in  : in  std_logic_vector(11 downto 0);
        data_out : out std_logic_vector(7 downto 0);
        unrecoverable_error    : out std_logic := '0'
    );
end entity hamming12_8_decoder;

architecture rtl of hamming12_8_decoder is

    signal syndrome : std_logic_vector(3 downto 0);
    signal err_loc  : integer range 0 to 12;
    signal corrected_data_in : std_logic_vector(11 downto 0);
    
begin

    syndrome(0) <= data_in(0) xor data_in(2) xor data_in(4) xor data_in(6) xor data_in(8) xor data_in(10);
    syndrome(1) <= data_in(1) xor data_in(2) xor data_in(5) xor data_in(6) xor data_in(9) xor data_in(10);
    syndrome(2) <= data_in(3) xor data_in(4) xor data_in(5) xor data_in(6) xor data_in(11);
    syndrome(3) <= data_in(7) xor data_in(8) xor data_in(9) xor data_in(10) xor data_in(11);

    process(syndrome)
    begin
        unrecoverable_error <= '0';
        if syndrome = "0000" then
            err_loc <= 0;
        elsif to_integer(unsigned(syndrome)) > 11 then
            err_loc <= to_integer(unsigned(syndrome));
        else
            err_loc <= 12;
            unrecoverable_error <= '1';
        end if;
    end process;

    process(data_in, err_loc, syndrome)
    begin
        if err_loc /= 0 then
            corrected_data_in <= data_in;
            corrected_data_in(err_loc - 1) <= not data_in(err_loc - 1);
        else
            corrected_data_in <= data_in;
        end if;
    end process;

    data_out(0) <= corrected_data_in(2);
    data_out(1) <= corrected_data_in(4);
    data_out(2) <= corrected_data_in(5);
    data_out(3) <= corrected_data_in(6);
    data_out(4) <= corrected_data_in(8);
    data_out(5) <= corrected_data_in(9);
    data_out(6) <= corrected_data_in(10);
    data_out(7) <= corrected_data_in(11);

end architecture rtl;