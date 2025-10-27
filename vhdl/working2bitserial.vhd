LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

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
--    dbg_io4 : OUT STD_LOGIC;
    
    host_feedthrough_dp : OUT STD_LOGIC;
    host_feedthrough_dn : OUT STD_LOGIC;

    lt_rx : IN STD_LOGIC;
    lt_tx : OUT STD_LOGIC

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
  SIGNAL clk_24mhz : STD_LOGIC := '0';
  SIGNAL clk_pll : STD_LOGIC;
  
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

  SIGNAL dpdm_sync : std_logic_vector(1 downto 0);
  SIGNAL piso_reg : std_logic_vector(1 downto 0 ) := (others => '0');
  SIGNAL usb_ser : std_logic;
  SIGNAL load_phase : std_logic;
  SIGNAL out_phase : std_logic;

  SIGNAL dp_lst, dn_lst : std_logic := '0';
  SIGNAL edge_flag : std_logic := '0';
  SIGNAL bcnt : unsigned(4 downto 0) := (others => '0'); -- 1 downto 0 for FS (will roll-around) but shouldn't be using 48mhz for fs
  SIGNAL dcnt : unsigned(4 downto 0) := (others => '0'); -- 1 downto 0 for FS (see above)
  SIGNAL half_period : std_logic := '0';
  SIGNAL bit_clk : std_logic := '0';
  SIGNAL dpdn_mid : std_logic_vector(1 downto 0) := (others => '0');
  SIGNAL in_packet : std_logic := '0';
  SIGNAL se0 : std_logic := '0';
  SIGNAL eop : std_logic := '0';
  SIGNAL eop_cnt : integer range 0 to 64 := 0;
  signal se0_cnt : integer range 0 to 64 := 0;

  type packet_state is (OUTSIDE_PACKET, PREPACKET, INSIDE_PACKET, END_PACKET, POSTPACKET, KEEP_ALIVE);
  type des_state is (OUTSIDE_PACKET, PREPACKET, INSIDE_PACKET, KEEP_ALIVE, POST_EOP);
  signal psm : packet_state := OUTSIDE_PACKET;
  signal dsm : des_state := OUTSIDE_PACKET;

  signal keep_alive_detect : std_logic := '0';

  -- deserializer signals
  SIGNAL diff_reg : std_logic_vector(1 downto 0) := (others => '0');
  SIGNAL diff_read : std_logic := '0';
  SIGNAL diff_load : std_logic := '0';
  SIGNAL diff_clk : integer range 0 to 64 := 0;
  SIGNAL diff_cnt : integer range 0 to 64 := 0;
  SIGNAL din_pkt : std_logic := '0';
  SIGNAL out_packet : std_logic := '0';
  SIGNAL lst_usb_ser : std_logic;
  SIGNAL usb_ser_edge : std_logic := '0';
  SIGNAL se1_cnt : integer range 0 to 16;
  SIGNAL diff_buff : std_logic_vector(1 downto 0) := (others => '0');
  SIGNAL buff_check : std_logic := '0';
  SIGNAL keep_alive_cnt : integer range 0 to 32 := 0;
  SIGNAL tail_clk : integer range 0 to 32 := 0;

  SIGNAL dbg_gen : std_logic := '0';

 BEGIN
  u_osc : SB_HFOSC
  GENERIC MAP(CLKHF_DIV => "0b00")
  PORT MAP(
    CLKHFEN => '1',
    CLKHFPU => '1',
    CLKHF => clk_48mhz
  );

  host_pu <= '1';
  host_rxd <= host_rxdp;
  host_dp <= host_txdp when host_txoe = '0' else 'Z';
  host_dn <= host_txdn when host_txoe = '0' else 'Z';
  host_rxdp <= host_dp;
  host_rxdn <= host_dn;

  dev_dp <= dev_txdp when dev_txoe = '0' else 'Z';
  dev_dn <= dev_txdn when dev_txoe = '0' else 'Z';
  dev_rxdp <= dev_dp;
  dev_rxdn <= dev_dn;

  edge_flag <= (host_rxdp xor dp_lst) or (host_rxdn xor dn_lst);
  se0 <= (not host_rxdp) and (not host_rxdn);

  process(clk_48mhz)
  BEGIN
    if rising_edge(clk_48mhz) then
      case psm is
        when OUTSIDE_PACKET =>
          keep_alive_cnt <= 0;
          in_packet <= '0';
          keep_alive_detect <= '0';
          if se0 then
            psm <= KEEP_ALIVE;
          end if;
          if dpdn_mid(1) = '1' then -- rxdn for fullspeed
            psm <= INSIDE_PACKET;
          end if;

        when PREPACKET =>
          psm <= INSIDE_PACKET;

        when INSIDE_PACKET =>
          in_packet <= '1';
          se0_cnt <= 0;
          if se0 then
            psm <= END_PACKET;
          end if;

        when END_PACKET =>
          if se0 then 
            se0_cnt <= se0_cnt + 1;
          end if;
          if se0_cnt = 63 then
            psm <= OUTSIDE_PACKET;
          end if;

        when POSTPACKET =>
          psm <= OUTSIDE_PACKET;

        when KEEP_ALIVE =>
          in_packet <= '0';
          if keep_alive_cnt = 6 then
            keep_alive_detect <= '0';
          else 
            keep_alive_detect <= '1';
            keep_alive_cnt <= keep_alive_cnt + 1;
          end if;
          if not se0 then
            psm <= OUTSIDE_PACKET;
          end if;
      end case;
    end if;
  end process;

  bit_clk_gen : process(clk_48mhz)
    BEGIN
      if rising_edge(clk_48mhz) then
      dp_lst <= host_rxdp;
      dn_lst <= host_rxdn;
        if edge_flag = '1' then
      --    bit_clk <= '1';
          bcnt <= (others => '0');
        else
        --  bit_clk <= '0';
          bcnt <= bcnt + 1;
        end if;

        if bcnt = "00000" then
          bit_clk <= '1';
        else
          bit_clk <= '0';
        end if;
        
        if bcnt = "01110" then
          half_period <= '1';
        else
          half_period <= '0';
        end if;
      end if;
    end process bit_clk_gen;
          
  sampler : process(clk_48mhz)
  BEGIN
    if rising_edge(clk_48mhz) then
      if half_period = '1' then
        dpdn_mid <= host_rxdp & host_rxdn;
        piso_reg <= host_rxdp & host_rxdn;
        dcnt <= "00000";
        load_phase <= '1';
        out_phase <= '0';
      elsif dcnt = "10000" then
        piso_reg <= '0' & piso_reg(1);
        dcnt <= dcnt + 1;
        load_phase <= '0';
        out_phase <= '1';
      else
        dcnt <= dcnt + 1;
        load_phase <= '0';
        out_phase <= '0';
      end if;
    end if;
  end process sampler;

  usb_ser <= (piso_reg(0) and in_packet) or (keep_alive_detect and '1');

  usb_ser_edge <= usb_ser xor lst_usb_ser;
  deserialiser : process(clk_48mhz)
    BEGIN
      if rising_edge(clk_48mhz) then
        case dsm is 
          when OUTSIDE_PACKET =>
            out_packet <= '1';
            diff_read <= '0';
            dev_txoe <= '1';
            diff_buff <= "00";
            diff_reg <= "00";
            if usb_ser then
              din_pkt <= '0';
              diff_clk <= 0;
              diff_load <= '0';
              dsm <= PREPACKET;
            end if;

          when PREPACKET =>
            out_packet <= '0';
            dev_txoe <= '1';
            eop_cnt <= 0;
            lst_usb_ser <= usb_ser;
            if diff_clk = 7 then
              diff_load <= '1';
              diff_buff <= diff_buff(0) & usb_ser;
              diff_reg <= diff_buff;
              buff_check <= '1';
--              diff_reg <= diff_reg(0) & usb_ser;
              diff_cnt <= 1;
              diff_clk <= 0;
              dsm <= INSIDE_PACKET;
            else
              diff_clk <= diff_clk + 1;
            end if;

          when INSIDE_PACKET =>
            din_pkt <= '1';
            dev_txoe <= buff_check;
            if diff_clk = 15 then
              diff_load <= '1';
              if buff_check = '0' then
                diff_reg <= diff_buff;
                diff_buff <= diff_buff(0) & usb_ser;
 --             diff_reg <= diff_reg(0) & usb_ser;
                diff_cnt <= diff_cnt + 1;
--              diff_clk <= diff_clk + 1;
                diff_clk <= 0;
              else 
                if usb_ser = '0' then
                  diff_clk <= 0;
                  diff_load <= '0';
                  dsm <= KEEP_ALIVE;
                else
                  diff_reg <= diff_buff;
                  diff_buff <= diff_buff(0) & usb_ser;
                  diff_cnt <= diff_cnt + 1;
                  diff_clk <= 0;
                  buff_check <= '0';
                end if;
              end if;
            elsif usb_ser_edge = '1' then
              diff_load <= '0';
              diff_clk <= 8;
            else
              diff_load <= '0';
              diff_clk <= diff_clk + 1;
            end if;

            if diff_cnt = 2 then
              diff_read <= '1';
              dev_txdn <= diff_reg(1);
              dev_txdp <= diff_reg(0);
              if diff_reg = "00" then
                dbg_gen <= '1';
                eop_cnt <= eop_cnt + 1;
              else
                dbg_gen <= '0';
                eop_cnt <= 0;
              end if;
              diff_cnt <= 0;
            else
              diff_read <= '0';
            end if;

            if eop_cnt = 1 and diff_clk = 15 then 
              tail_clk <= 0;
              dsm <= POST_EOP;
            end if;
            lst_usb_ser <= usb_ser;

          when POST_EOP =>
            if (tail_clk = 4) then
              dsm <= OUTSIDE_PACKET;
            else
              tail_clk <= tail_clk + 1;
              dev_txdn <= '0';
              dev_txdp <= '0';
            end if;

          when KEEP_ALIVE =>
            out_packet <= '0';
            if diff_clk = 24 then
              dev_txoe <= '1';
              dsm <= OUTSIDE_PACKET;
            else
              dev_txdp <= '0';
              dev_txdn <= '0';
              dev_txoe <= '0';
              diff_clk <= diff_clk + 1;
            end if;
        end case;
      end if;
    end process;

--  dbg_io1 <= diff_reg(1);
--  dbg_io1 <= diff_read;
--  dbg_io2 <= host_rxdn;
--  dbg_io2 <= dev_txdp;
  dbg_io1 <= dev_dp;
  dbg_io2 <= host_rxdp; 
  dbg_io3 <= dev_dn;
--  dbg_io2 <= diff_reg(0);
--  dbg_io3 <= out_phase;
  --dbg_io3 <= dpdn_mid(0);
--  dbg_io3 <= diff_reg(1);
--  dbg_io3 <= diff_reg(1);
 -- dbg_io3 <= diff_reg(1);
  host_feedthrough_dp <= host_rxdn; 
  host_feedthrough_dn <= host_rxdn;
--    dbg_io3 <= diff_clk;

END ARCHITECTURE;



