library ieee;
use ieee.std_logic_1164.all;

entity top is
	port (
		tram_wr_en : in std_logic;
		reset : in std_logic;
		bitt_out : out std_logic; -- bit
		bitt_in : out std_logic; -- bit received
		dout : out std_logic; -- manchester tx
		dout_rd : out std_logic; -- read manchester tx
		din_rd : out std_logic; -- read manchester rx
        clk_100 : in std_logic; -- 100 MHz 
		din : in std_logic -- manchester rx
	);
end top;

architecture rtl of top is
component serialiser is
	generic(
		BITS : INTEGER := 10; -- Number of bits being encoded
		mlength : INTEGER := 11 -- Number of bits in the length message (not including the sync)
	);
	port (
		clk : in STD_LOGIC;
		message : in STD_LOGIC_VECTOR(BITS-1 downto 0);
		tx_length : in std_logic_vector (mlength-1 downto 0);
		dout : out STD_LOGIC;
		rd_addr : out STD_LOGIC_VECTOR (mlength-1 downto 0);
		message_sent : out STD_LOGIC;
		reset : in STD_LOGIC;
		ena_t : in STD_LOGIC
	);
end component;

component manchester_encoder is
        port (
            clk, reset : in std_logic;
            v, d       : in std_logic;
            y          : out std_logic
        );
    end component;

component USB IS 
  PORT (
    host_pu : OUT STD_LOGIC;
    host_dp : INOUT STD_LOGIC;
    host_dn : INOUT STD_LOGIC;

    dev_dp : INOUT STD_LOGIC;
    dev_dn : INOUT STD_LOGIC;

    dbg_io1 : OUT STD_LOGIC;
    dbg_io2 : OUT STD_LOGIC;
    dbg_io3 : OUT STD_LOGIC;
    dbg_io4 : OUT STD_LOGIC;

    host_to_dev_buff: OUT STD_LOGIC; -- buffer 
    length_fifo: OUT STD_LOGIC;
    length_empty: OUT STD_LOGIC;
    clk_hf: OUT STD_LOGIC;

    host_feedthrough_dp : OUT STD_LOGIC;
    host_feedthrough_dn : OUT STD_LOGIC;
    dev_feedthrough_dp : OUT STD_LOGIC;
    dev_feedthrough_dn : OUT STD_LOGIC
    );
END COMPONENT;

begin
serial : serialiser
	generic map(
		BITS => 12, -- Number of bits being encoded in message 'byte'
		mlength => 11 -- Number of bits in the length message (not including the sync)
	)
	port map (
		clk => clk_25,
		message => tram_out,
		tx_length => tx_length,
		dout => bit_out,
		rd_addr => tram_raddr_i,
		message_sent => message_sent,
		reset => reset,
		ena_t => ena_t 
	);

man_enc : manchester_encoder
    port map (
        clk => clk_50, 
        reset => reset,
        v => ena_t,
        d => bit_out,
        y => dout_wr
    );

USBee : USB 
  PORT MAP (
    host_pu =>host_pu,
    host_dp =>host_dp,
    host_dn =>host_dn,

    dev_dp =>dev_dp,
    dev_dn =>dev_dn,

    host_to_dev_buff => ,
    length_fifo =>,
    length_empty =>,
    clk_hf =>,

    );
END COMPONENT;
end architecture;
