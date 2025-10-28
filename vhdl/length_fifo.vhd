LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.ALL;
USE ieee.numeric_std.ALL;
USE ieee.math_real.ALL;

ENTITY length_fifo IS 
  PORT (
      clk : in STD_LOGIC;
      reset : in STD_LOGIC;
      
      -- write interface
      wr_en : in STD_LOGIC;
      din : in STD_LOGIC_VECTOR(10 downto 0);
      fifo_full : out STD_LOGIC;

      -- read interface 
      rd_en : in STD_LOGIC;
      dout : out STD_LOGIC_VECTOR(10 downto 0);
      fifo_empty : out STD_LOGIC
   );
END length_fifo;

architecture behavioral of length_fifo is 
  constant LENGTH_FIFO_DEPTH : integer := 16; -- 16 queued packets
  type length_fifo_type is array(0 to LENGTH_FIFO_DEPTH-1) of STD_LOGIC_VECTOR(10 downto 0);
  signal length_fifo : length_fifo_type;
  signal length_wr_ptr : integer range 0 to LENGTH_FIFO_DEPTH-1 := 0;
  signal length_rd_ptr : integer range 0 to LENGTH_FIFO_DEPTH-1 := 0;
  signal length_count : integer range 0 to LENGTH_FIFO_DEPTH := 0;
  signal length_empty : std_logic;
  signal length_full : std_logic;

BEGIN

  fifo_empty <= '1' when length_count = 0 else '0';
  fifo_full <= '1' when length_count = LENGTH_FIFO_DEPTH else '0';
  process(clk)
  BEGIN
    if rising_edge(clk) then
      if wr_en = '1' and fifo_full = '0' then
        length_fifo(length_wr_ptr) <= din;
        if length_wr_ptr = LENGTH_FIFO_DEPTH - 1 then
          length_wr_ptr <= 0;
        else
          length_wr_ptr <= length_wr_ptr + 1;
        end if;
        length_count <= length_count + 1;
      end if;

      if rd_en = '1' and fifo_empty = '0' then
        dout <= length_fifo(length_rd_ptr);
        if length_rd_ptr = LENGTH_FIFO_DEPTH - 1 then
          length_rd_ptr <= 0;
        else
          length_rd_ptr <= length_rd_ptr + 1;
        end if;
        length_count <= length_count - 1;
      end if;
    end if;
  end process;
end architecture;
