LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY top IS 
  PORT (
    host_dp : INOUT STD_LOGIC;
    host_dn : INOUT STD_LOGIC;
    dev_dp : INOUT STD_LOGIC;
    dev_dn : INOUT STD_LOGIC;
    
    dbg_io1 : OUT STD_LOGIC;
    dbg_io2 : OUT STD_LOGIC;
    dbg_io3 : OUT STD_LOGIC;
    host_feedthrough_dp : OUT STD_LOGIC;
    host_feedthrough_dn : OUT STD_LOGIC
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

  -- signal declarations
  SIGNAL clk_48mhz : STD_LOGIC;

    -- host usb signals
  SIGNAL host_rxd : STD_LOGIC;
  SIGNAL host_txoe : STD_LOGIC := '1';
  SIGNAL host_rxdp : STD_LOGIC;
  SIGNAL host_rxdn : STD_LOGIC;
  SIGNAL host_txdp : STD_LOGIC;
  SIGNAL host_txdn : STD_LOGIC;

  -- dev usb signals
  SIGNAL dev_rxd : STD_LOGIC;
  SIGNAL dev_txoe : STD_LOGIC := '1';
  SIGNAL dev_rxdp : STD_LOGIC;
  SIGNAL dev_rxdn : STD_LOGIC;
  SIGNAL dev_txdp : STD_LOGIC;
  SIGNAL dev_txdn : STD_LOGIC;

  SIGNAL host_edge_flag : STD_LOGIC := '0';
  SIGNAL host_dp_lst : STD_LOGIC := '0';
  SIGNAL host_dn_lst : STD_LOGIC := '0';
  SIGNAL dev_edge_flag : STD_LOGIC := '0';
  SIGNAL dev_dp_lst : STD_LOGIC := '0';
  SIGNAL dev_dn_lst : STD_LOGIC := '0';
  SIGNAL host_se0 : STD_LOGIC := '0';
  SIGNAL dev_se0 : STD_LOGIC := '0';
  SIGNAL host_se0_cnt : integer range 0 to 128 := 0;
  SIGNAL dev_se0_cnt : integer range 0 to 128 := 0;

  type host_state is (OUTSIDE_PACKET, INSIDE_PACKET, KEEP_ALIVE, POST_PACKET);
  type dev_state is (OUTSIDE_PACKET, INSIDE_PACKET, POST_PACKET);
  signal hsm : host_state := OUTSIDE_PACKET;
  signal dsm : dev_state := OUTSIDE_PACKET;

  signal in_packet : STD_LOGIC := '0';
  signal keep_alive_detect : STD_LOGIC := '0';
  signal post_cnt : integer range 0 to 32 := 0;
  
  BEGIN
  u_osc : SB_HFOSC
  GENERIC MAP(CLKHF_DIV => "0b00")
  PORT MAP(
    CLKHFEN => '1',
    CLKHFPU => '1',
    CLKHF => clk_48mhz
  );

  host_rxd <= host_rxdp;
  host_dp <= host_txdp when host_txoe = '0' else 'Z';
  host_dn <= host_txdn when host_txoe = '0' else 'Z';
  host_rxdp <= host_dp when host_txoe = '1' else '0';
  host_rxdn <= host_dn when host_txoe = '1' else '1';

  dev_dp <= dev_txdp when dev_txoe = '0' else 'Z';
  dev_dn <= dev_txdn when dev_txoe = '0' else 'Z';
  dev_rxdp <= dev_dp when dev_txoe = '1' else '0';
  dev_rxdn <= dev_dn when dev_txoe = '1' else '1';

  host_edge_flag <= (host_rxdp xor host_dp_lst) or (host_rxdn xor host_dn_lst);
  dev_edge_flag <= (dev_rxdp xor dev_dp_lst) or (dev_rxdn xor dev_dn_lst);
  host_se0 <= (not host_rxdp) and (not host_rxdn);
  dev_se0 <= (not dev_rxdp) and (not dev_rxdn);

  process(clk_48mhz)
  BEGIN
    if rising_edge(clk_48mhz) then
      host_dp_lst <= host_rxdp;
      host_dn_lst <= host_rxdn;
      dev_dp_lst <= dev_rxdp;
      dev_dn_lst <= dev_rxdn;
    end if;
  end process;

  process(clk_48mhz)
  BEGIN
    if rising_edge(clk_48mhz) then
      case hsm is 
        when OUTSIDE_PACKET =>
          in_packet <= '0';
          keep_alive_detect <= '0';
          dev_txoe <= '1';
          host_se0_cnt <= 0;
          if host_se0 then
            hsm <= KEEP_ALIVE;
          elsif host_edge_flag then
            hsm <= INSIDE_PACKET;
          end if;

        when INSIDE_PACKET =>
          in_packet <= '1';
          dev_txdp <= host_rxdp;
          dev_txdn <= host_rxdn;
          dev_txoe <= '0';
          if host_se0 then
            host_se0_cnt <= host_se0_cnt + 1;
          else
            host_se0_cnt <= 0;
          end if;
          if host_se0_cnt = 4 then
            post_cnt <= 0;
            hsm <= POST_PACKET;
          end if;

        when POST_PACKET =>
          if not host_se0 then
            hsm <= OUTSIDE_PACKET;
          end if;

        when KEEP_ALIVE =>
          in_packet <= '1';
          keep_alive_detect <= '1';
          dev_txdp <= host_rxdp;
          dev_txdn <= host_rxdn;
          dev_txoe <= '0';
          if not host_se0 then
            hsm <= OUTSIDE_PACKET;
          end if;
      end case;
    end if;
  end process;


  process(clk_48mhz)
  BEGIN
    if rising_edge(clk_48mhz) then
      case dsm is 
        when OUTSIDE_PACKET =>
          host_txoe <= '1';
          dev_se0_cnt <= 0;
          if dev_edge_flag then
            dsm <= INSIDE_PACKET;
          end if;

        when INSIDE_PACKET =>
          host_txdp <= dev_rxdp;
          host_txdn <= dev_rxdn;
--          host_txoe <= '0';
          if dev_se0 then
            dev_se0_cnt <= dev_se0_cnt + 1;
          else
            dev_se0_cnt <= 0;
          end if;
          if dev_se0_cnt = 4 then
            dsm <= POST_PACKET;
          end if;

        when POST_PACKET =>
          if not dev_se0 then
            dsm <= OUTSIDE_PACKET;
          end if;
      end case;
    end if;
   end process;

  dbg_io1 <= dev_dn;
  dbg_io2 <= dev_edge_flag;
  dbg_io3 <= host_rxdp;
  host_feedthrough_dp <= dev_txdn;
  host_feedthrough_dn <= host_rxdn;
  
END ARCHITECTURE;
