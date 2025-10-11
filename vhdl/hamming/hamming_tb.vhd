library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity hamming_tb is
end entity hamming_tb;

architecture sim of hamming_tb is

    signal enc_data_in  : std_logic_vector(7 downto 0);
    signal enc_data_out      : std_logic_vector(11 downto 0);

    signal dec_data_in  : std_logic_vector(11 downto 0);
    signal dec_data_out     : std_logic_vector(7 downto 0);
    signal dec_unrecoverable_error : std_logic;

begin

    enc_uut: entity work.hamming12_8_encoder
        port map (
            data_in  => enc_data_in,
            data_out => enc_data_out
        );

    dec_uut: entity work.hamming12_8_decoder
        port map (
            data_in  => dec_data_in,
            data_out => dec_data_out,
            unrecoverable_error => dec_unrecoverable_error
        );
    
    stimulus: process
    begin

        enc_data_in <= "01010101";
        wait for 1 ns;

        dec_data_in <= "110100101111";
        wait for 1 ns;

        enc_data_in <= "10101010";
        dec_data_in <= "111101011000";
        wait for 1 ns;

        wait;
    end process;

end architecture sim;