library ieee;
use ieee.std_logic_1164.all;

entity ack_sender is
  port (
    clk             : in  std_logic;
    utmi_dout_o     : out std_logic_vector(7 downto 0);
    utmi_txvalid_o  : out std_logic;

    send_trigger_i  : in  std_logic;  -- pulse or level; we edge-detect it
    utmi_txrdy_i    : in  std_logic   -- asserted when PHY consumes the byte
  );
end entity;

architecture rtl of ack_sender is
  type state_type is (IDLE, SEND_ACK);
  signal cs, ns          : state_type := IDLE;

  constant PID_ACK       : std_logic_vector(7 downto 0) := x"FF";

  -- registered outputs
  signal tx_valid_q      : std_logic := '0';
  signal dout_q          : std_logic_vector(7 downto 0) := (others => '0');

  -- trigger synchronizer + edge detect (single clock domain)
  signal trig_q          : std_logic := '0';
  signal trig_rise       : std_logic;
begin
  -- rising-edge detect of send_trigger_i
  process(clk)
  begin
    if rising_edge(clk) then
      trig_q <= send_trigger_i;
    end if;
  end process;
  trig_rise <= '1' when (send_trigger_i = '1' and trig_q = '0') else '0';

  -- state register + output registers
  process(clk)
  begin
    if rising_edge(clk) then
      cs         <= ns;
      utmi_txvalid_o <= tx_valid_q;
      utmi_dout_o    <= dout_q;
    end if;
  end process;

  -- next-state & next-output logic (combinational)
  process(cs, trig_rise, utmi_txrdy_i)
    variable tx_valid_d : std_logic;
    variable dout_d     : std_logic_vector(7 downto 0);
    variable ns_v       : state_type;
  begin
    -- safe defaults every cycle
    tx_valid_d := '0';
    dout_d     := (others => '0');
    ns_v       := cs;

    case cs is
      when IDLE =>
        -- wait for a trigger; on trigger, present ACK next cycle
        if trig_rise = '1' then
          tx_valid_d := '1';
          dout_d     := PID_ACK;
          ns_v       := SEND_ACK;
        end if;

      when SEND_ACK =>
        -- hold valid + ACK byte until PHY consumes it
        tx_valid_d := '1';
        dout_d     := PID_ACK;
        if utmi_txrdy_i = '1' then
          -- PHY accepted the byte this cycle; drop valid next cycle
          ns_v := IDLE;
        end if;

      when others =>
        ns_v := IDLE;
    end case;

    -- drive registered next values
    tx_valid_q <= tx_valid_d;
    dout_q     <= dout_d;
    ns         <= ns_v;
  end process;
end architecture;

