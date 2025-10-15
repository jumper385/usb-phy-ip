LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
use ieee.std_logic_unsigned.all;
USE ieee.numeric_std.ALL;
use ieee.math_real.all;

ENTITY top IS 
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

    host_to_dev_buff: OUT STD_LOGIC;
    length_fifo: OUT STD_LOGIC;
    length_empty: OUT STD_LOGIC;
    clk_hf: OUT STD_LOGIC;

    host_feedthrough_dp : OUT STD_LOGIC;
    host_feedthrough_dn : OUT STD_LOGIC;
    dev_feedthrough_dp : OUT STD_LOGIC;
    dev_feedthrough_dn : OUT STD_LOGIC
    );
END ENTITY;

ARCHITECTURE rtl of top IS 
  COMPONENT SB_HFOSC
    GENERIC (CLKHF_DIV : STRING := "0b00");
    PORT (
      CLKHFEN : IN STD_LOGIC;
      CLKHFPU : IN STD_LOGIC;
      CLKHF : OUT STD_LOGIC
    );
  END COMPONENT;

  COMPONENT usb_phy
    PORT (
      clk : IN STD_LOGIC;
      rst : IN STD_LOGIC;
      phy_tx_mode : IN STD_LOGIC;
      usb_rst : OUT STD_LOGIC;
      rxd, rxdp, rxdn : IN STD_LOGIC;
      txdp, txdn, txoe : OUT STD_LOGIC;
      DataOut_i : IN STD_LOGIC_VECTOR(7 downto 0);
      TxValid_i : IN STD_LOGIC;
      TxReady_o : OUT STD_LOGIC;
      DataIn_o : OUT STD_LOGIC_VECTOR(7 downto 0);
      RxValid_o : OUT STD_LOGIC;
      RxActive_o : OUT STD_LOGIC;
      RxError_o : OUT STD_LOGIC;
      LineState_o : OUT STD_LOGIC_VECTOR(1 downto 0)
      );
  END COMPONENT;

  COMPONENT usb_fifo
    PORT (
        clk : in STD_LOGIC;
        reset : in STD_LOGIC;
        
        -- Write interface (from host RX)
        wr_en : in STD_LOGIC;
        din : in STD_LOGIC_VECTOR(7 downto 0);
        fifo_full : out STD_LOGIC;
        
        -- Read interface (to device TX)
        rd_en : in STD_LOGIC;
        dout : out STD_LOGIC_VECTOR(7 downto 0);
        fifo_empty : out STD_LOGIC;
        data_count : out STD_LOGIC_VECTOR(6 downto 0)  -- 0-64 count
    );
  END COMPONENT;

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

component LT_controller IS
    PORT (
        fsm_clk : IN STD_LOGIC; 
        rst : IN STD_LOGIC;
		-- Indicators from other blocks to trigger states
        tx_ready : IN STD_LOGIC; -- indication from EC to start reading TX_RAM and transmit
		rx_received : IN STD_LOGIC; -- indication from the RX line that a light message is incoming
		-- host_align : IN STD_LOGIC;
		-- device_align : IN STD_LOGIC;
		-- Add error signals that suggest to go to idle state?
		rx_error : OUT STD_LOGIC;
		tx_error : OUT STD_LOGIC;
		-- host : IN STD_LOGIC;
        ena_t : out std_logic;
        message_sent : in std_logic;
        -- aligned : in std_logic
		ena_r : out std_logic;
        rx_done : in std_logic

    );
END component;

	COMPONENT clk_divider IS
		GENERIC (
			N : INTEGER := 0
		);
		PORT (
			clk_in : IN STD_LOGIC;
			reset : IN STD_LOGIC;
			clk_out : OUT STD_LOGIC
		);
	end component;

  -- signal declarations

  SIGNAL clk_hf : STD_LOGIC;
  
  -- host usb signals
  SIGNAL host_rxd : STD_LOGIC;
  SIGNAL host_txoe : STD_LOGIC;
  SIGNAL host_rxdp : STD_LOGIC;
  SIGNAL host_rxdn : STD_LOGIC;
  SIGNAL host_txdp : STD_LOGIC;
  SIGNAL host_txdn : STD_LOGIC;

  -- host utmi signals
  SIGNAL host_utmi_rst : STD_LOGIC;
  SIGNAL host_utmi_rxactive : STD_LOGIC;
  SIGNAL host_utmi_rxvalid : STD_LOGIC;
  SIGNAL host_utmi_rxerror : STD_LOGIC;
  SIGNAL host_utmi_txvalid : STD_LOGIC;
  SIGNAL host_utmi_txrdy : STD_LOGIC;
  SIGNAL host_utmi_dout : STD_LOGIC_VECTOR(7 downto 0) := (OTHERS => '0');
  SIGNAL host_utmi_din : STD_LOGIC_VECTOR(7 downto 0);
  SIGNAL host_utmi_line_state : STD_LOGIC_VECTOR(1 downto 0);

  -- dev usb signals
  SIGNAL dev_rxd : STD_LOGIC;
  SIGNAL dev_txoe : STD_LOGIC;
  SIGNAL dev_rxdp : STD_LOGIC;
  SIGNAL dev_rxdn : STD_LOGIC;
  SIGNAL dev_txdp : STD_LOGIC;
  SIGNAL dev_txdn : STD_LOGIC;

  -- dev utmi signals
  SIGNAL dev_utmi_rst : STD_LOGIC;
  SIGNAL dev_utmi_rxactive : STD_LOGIC;
  SIGNAL dev_utmi_rxvalid : STD_LOGIC;
  SIGNAL dev_utmi_rxerror : STD_LOGIC;
  SIGNAL dev_utmi_txvalid : STD_LOGIC;
  SIGNAL dev_utmi_txrdy : STD_LOGIC;
  SIGNAL dev_utmi_dout : STD_LOGIC_VECTOR(7 downto 0) := (OTHERS => '0');
  SIGNAL dev_utmi_din : STD_LOGIC_VECTOR(7 downto 0);
  SIGNAL dev_utmi_line_state : STD_LOGIC_VECTOR(1 downto 0);
  
  -- 8-bit registers that feed into fifo 
  signal host_to_dev_buff : STD_LOGIC_VECTOR(7 downto 0);
  signal dev_to_host_buff : STD_LOGIC_VECTOR(7 downto 0);
  signal en_host_to_dev_buff : STD_LOGIC := '0';
  signal en_dev_to_host_buff : STD_LOGIC := '0';
  signal rst_host_to_dev_buff : STD_LOGIC := '0';

  signal host_to_dev_fifo_count : STD_LOGIC_VECTOR(6 downto 0);
  signal dev_to_host_fifo_count: STD_LOGIC_VECTOR(6 downto 0);
  
  -- Signal declarations for dual FIFOs
  signal host_to_dev_fifo_wr_en : STD_LOGIC;
  signal host_to_dev_fifo_rd_en : STD_LOGIC;
  signal host_to_dev_fifo_dout : STD_LOGIC_VECTOR(7 downto 0);
  signal host_to_dev_fifo_empty : STD_LOGIC;
  signal host_to_dev_fifo_full : STD_LOGIC;

  signal dev_to_host_fifo_wr_en : STD_LOGIC;
  signal dev_to_host_fifo_rd_en : STD_LOGIC;
  signal dev_to_host_fifo_dout : STD_LOGIC_VECTOR(7 downto 0);
  signal dev_to_host_fifo_empty : STD_LOGIC;
  signal dev_to_host_fifo_full : STD_LOGIC;


  -- Control signals
  signal host_packet_complete : STD_LOGIC := '0';
  signal dev_packet_complete : STD_LOGIC := '0';
  signal host_transmit_active : STD_LOGIC := '0';
  signal dev_transmit_active : STD_LOGIC := '0';

  signal reset : STD_LOGIC := '0';

  type host_state is (HOST_IDLE, HOST_RECEIVING);
  type dev_state is (DEV_IDLE, DEV_PREREAD, DEV_PRELENGTH, DEV_CHECK, DEV_TRANSMITTING, DEV_TAIL);
  signal hsm : host_state := HOST_IDLE;
  signal dsm : dev_state := DEV_IDLE;

  CONSTANT PID_SOF: std_logic_vector(7 downto 0) := B"10100101";
  CONSTANT PID_SETUP: std_logic_vector(0 to 7) := B"00101101";
  CONSTANT PID_DATA0: std_logic_vector(0 to 7) := B"11000011";
  SIGNAL sof_detected : std_logic := '0';
  
  signal bit_count : std_logic_vector(4 downto 0) := "00000";

    -- Length FIFO - stores packet lengths (0-1024 needs 11 bits)
  constant LENGTH_FIFO_DEPTH : integer := 16; -- Can handle 16 queued packets
  type length_fifo_type is array(0 to LENGTH_FIFO_DEPTH-1) of std_logic_vector(10 downto 0);
  signal length_fifo : length_fifo_type;
  signal length_wr_ptr : integer range 0 to LENGTH_FIFO_DEPTH-1 := 0;
  signal length_rd_ptr : integer range 0 to LENGTH_FIFO_DEPTH-1 := 0;
  signal length_count : integer range 0 to LENGTH_FIFO_DEPTH := 0;
  signal length_empty : std_logic;
  signal length_full : std_logic;

  -- Control signals
  signal length_wr_en : std_logic := '0';
  signal length_rd_en : std_logic := '0';
  signal current_packet_length : std_logic_vector(10 downto 0) := (others => '0');
  signal bytes_remaining : integer range 0 to 1024 := 0;
  signal packet_byte_count : std_logic_vector(10 downto 0) := (others => '0');
  
  signal len_three : std_logic := '0';
  signal len_eleven : std_logic := '0';
  signal dbg : std_logic := '0';
  signal tail_count : integer range 0 to 1024 := 9;

  BEGIN
  host_rxd <= host_rxdp;
  u_osc : SB_HFOSC
  GENERIC MAP(CLKHF_DIV => "0b00")
  PORT MAP(
    CLKHFEN => '1',
    CLKHFPU => '1',
    CLKHF => clk_hf
  );

  host_phy : usb_phy
  PORT MAP(
    clk => clk_hf,
    rst => '1',
    phy_tx_mode => '1',
    usb_rst => host_utmi_rst,

    -- usb interface
    rxd => host_rxd,
    rxdp => host_rxdp,
    rxdn => host_rxdn,
    txdp => host_txdp,
    txdn => host_txdn,
    txoe => host_txoe,

    -- utmi tx interface
    DataOut_i => host_utmi_dout,
    TxValid_i => host_utmi_txvalid,
    TxReady_o => host_utmi_txrdy,

    -- utmi rx interface
    DataIn_o => host_utmi_din,
    RxValid_o => host_utmi_rxvalid,
    RxActive_o => host_utmi_rxactive,
    RxError_o => host_utmi_rxerror,

    -- dp/dm 
    LineState_o => host_utmi_line_state
  );

  dev_phy : usb_phy
  PORT MAP(
    clk => clk_hf,
    rst => '1',
    phy_tx_mode => '1',
    usb_rst => dev_utmi_rst,

    -- usb interface
    rxd => dev_rxd,
    rxdp => dev_rxdp,
    rxdn => dev_rxdn,
    txdp => dev_txdp,
    txdn => dev_txdn,
    txoe => dev_txoe,

    -- utmi tx interface
    DataOut_i => host_to_dev_fifo_dout,
    TxValid_i => dev_utmi_txvalid,
    TxReady_o => dev_utmi_txrdy,

    -- utmi rx interface
    DataIn_o => dev_utmi_din,
    RxValid_o => dev_utmi_rxvalid,
    RxActive_o => dev_utmi_rxactive,
    RxError_o => dev_utmi_rxerror,

    -- dp/dm 
    LineState_o => dev_utmi_line_state
  );

  clkd_25 : clk_divider
	GENERIC map(
        N => 1
    )
    PORT map (
        clk_in => clk_120,
        reset => reset,
        clk_out => clk_25 -- Set as the quarter speed
    );

clkd_50 : clk_divider
	GENERIC map(
        N => 0
    )
    PORT map (
        clk_in => clk_120,
        reset => reset,
        clk_out => clk_50 -- Set as the half speed
    );

  -- FIFO for Host → Device direction
host_to_dev_fifo : usb_fifo
    port map (
        clk => clk_hf,
        reset => reset,
        wr_en => host_to_dev_fifo_wr_en,
        din(7 downto 0) => host_to_dev_buff,           -- From host PHY RX (host_utmi_din)
        fifo_full => host_to_dev_fifo_full,
        rd_en => host_to_dev_fifo_rd_en,
        dout => host_to_dev_fifo_dout,
        fifo_empty => host_to_dev_fifo_empty,
        data_count => host_to_dev_fifo_count
    );

-- FIFO for Device → Host direction  
dev_to_host_fifo : usb_fifo
    port map (
        clk => clk_hf,
        reset => reset,
        wr_en => dev_to_host_fifo_wr_en,
        din => dev_to_host_buff,            -- From device PHY RX (dev_utmi_din)
        fifo_full => dev_to_host_fifo_full,
        rd_en => dev_to_host_fifo_rd_en,
        dout => dev_to_host_fifo_dout,
        fifo_empty => dev_to_host_fifo_empty,
        data_count => dev_to_host_fifo_count
    );

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

  -- usb differential signalling
  host_dp <= host_txdp when host_txoe = '0' else 'Z';
  host_dn <= host_txdn when host_txoe = '0' else 'Z';
  host_rxdp <= host_dp;
  host_rxdn <= host_dn;

  host_pu <= '1';

  dev_dp <= dev_txdp when dev_txoe = '0' else 'Z';
  dev_dn <= dev_txdn when dev_txoe = '0' else 'Z';
  dev_rxdp <= dev_dp;
  dev_rxdn <= dev_dn;
  
  -- Length FIFO status
  length_empty <= '1' when length_count = 0 else '0';
  length_full <= '1' when length_count = LENGTH_FIFO_DEPTH else '0';

  -- LENGTHS FIFO
  process(clk_hf)
  begin
    if rising_edge(clk_hf) then
      -- Write to length FIFO
      if length_wr_en = '1' and length_full = '0' then
          length_fifo(length_wr_ptr) <= packet_byte_count;
          if length_wr_ptr = LENGTH_FIFO_DEPTH-1 then
              length_wr_ptr <= 0;
          else
              length_wr_ptr <= length_wr_ptr + 1;
          end if;
          length_count <= length_count + 1;
      end if;
      
      -- Read from length FIFO
      if length_rd_en = '1' and length_empty = '0' then
          current_packet_length <= length_fifo(length_rd_ptr);
          if length_rd_ptr = LENGTH_FIFO_DEPTH-1 then
              length_rd_ptr <= 0;
          else
              length_rd_ptr <= length_rd_ptr + 1;
          end if;
          length_count <= length_count - 1;
      end if;

    host_to_dev_buff <= host_utmi_din;
    end if;
  end process;

  -- HOST MACHINE
  process(clk_hf)
  BEGIN
    if rising_edge(clk_hf) then
      case hsm is 
        when HOST_IDLE =>
          bit_count <= "00000";
          sof_detected <= '0';
          host_to_dev_fifo_wr_en <= '0';
          host_utmi_txvalid <= '0';
          packet_byte_count <= "00000000000";
          length_wr_en <= '0';

          if host_utmi_rxactive and host_utmi_rxvalid then
            hsm <= HOST_RECEIVING;
          else
            hsm <= HOST_IDLE;
          end if;

        when HOST_RECEIVING =>
          if host_utmi_rxactive = '1' then
            if(bit_count = B"11110") then
              host_to_dev_fifo_wr_en <= '1';
              packet_byte_count <= packet_byte_count + "1";
            else
              host_to_dev_fifo_wr_en <= '0';
            end if;
            if (host_utmi_rxvalid) then
              bit_count <= "00000";
              if (host_to_dev_fifo_count = B"0000000") then
                sof_detected <= '1' when host_to_dev_buff(7 downto 0) = PID_SETUP else '0';
              else
                sof_detected <= '0';
              end if;
            else
              bit_count <= bit_count + "00001";
--              sof_detected <= '0';
            end if;
          else
            length_wr_en <= '1';
            sof_detected <= '0';
            hsm <= HOST_IDLE;
          end if;
      end case;

  -- DEVICE MACHINE
      case dsm is 
        when DEV_IDLE =>
          tail_count <= 8;
          dev_utmi_txvalid <= '0';
          len_three <= '0';
          len_eleven <= '0';
          dbg <= '0';
          if not length_empty then 
            host_to_dev_fifo_rd_en <= '0';
            length_rd_en <= '1';
            dsm <= DEV_PREREAD;
          else
            dsm <= DEV_IDLE;
            length_rd_en <= '0';
          end if;

        when DEV_PREREAD =>
          dbg <= '0';
          length_rd_en <= '0';
          dev_utmi_txvalid <= '1';
          host_to_dev_fifo_rd_en <= '1';
          dsm <= DEV_PRELENGTH;

        when DEV_PRELENGTH =>
          length_rd_en <= '0';
          host_to_dev_fifo_rd_en <= '0';
          bytes_remaining <= to_integer(unsigned(current_packet_length));
          dsm <= DEV_CHECK;
        
        when DEV_CHECK =>
          if(bytes_remaining = 11) then
            len_eleven <= '1';
            len_three <= '0';
          elsif(bytes_remaining = 3) then
            len_three <= '1';
            len_eleven <= '0';
          else
            len_three <= '0';
            len_eleven <= '0';
          end if;
          dsm <= DEV_TRANSMITTING;

        when DEV_TRANSMITTING =>
          length_rd_en <= '0';
          if bytes_remaining > 1 then
            if(dev_utmi_txrdy) then
              host_to_dev_fifo_rd_en <= '1';
              bytes_remaining <= bytes_remaining - 1;
            else
              host_to_dev_fifo_rd_en <= '0';
            end if;
          else
            host_to_dev_fifo_rd_en <= '0';
            dsm <= DEV_TAIL;
          end if;

        when DEV_TAIL =>
          dev_utmi_txvalid <= '1';
          if (dev_utmi_txrdy) then
            dsm <= DEV_IDLE;
          end if;
      end case;
    end if;
  end process;

  -- debugging
  --dbg_io1 <= host_to_dev_buff(7);
  dbg_io1 <= sof_detected;
--  dbg_io2 <= len_three or len_eleven;
  --dbg_io3 <= host_to_dev_fifo_wr_en;
  --dbg_io2 <= host_to_dev_fifo_rd_en;
  dbg_io2 <= host_to_dev_fifo_rd_en;
  dbg_io4 <= dev_utmi_txvalid;

  host_feedthrough_dp <= host_utmi_line_state(0);
  host_feedthrough_dn <= host_utmi_line_state(1);
  dev_feedthrough_dp <= dev_utmi_line_state(0);
  dev_feedthrough_dn <= dev_utmi_line_state(1);

END ARCHITECTURE;

