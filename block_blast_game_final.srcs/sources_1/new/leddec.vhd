-- leddec.vhd
-- Score display driver for Block Blast
-- Wraps leddec16: generates the mux clock, converts binary score to
-- packed BCD (one decimal digit per nibble), and cycles dig 0-3.
--
-- Display layout (right-justified on digits 0-3):
--   digit 3 = thousands, digit 2 = hundreds,
--   digit 1 = tens,      digit 0 = ones
-- Digits 4-7 are left off (leddec16 drives anode="11111111" for dig>3).

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity leddec is
  port (
    clk   : in  std_logic;                      -- 40 MHz
    score : in  std_logic_vector(15 downto 0);  -- binary score from game
    seg   : out std_logic_vector(6 downto 0);
    anode : out std_logic_vector(7 downto 0)
  );
end leddec;

architecture Behavioral of leddec is

  signal div_cnt  : std_logic_vector(14 downto 0) := (others => '0');
  signal dig      : std_logic_vector(2 downto 0)  := "000";

  signal bcd_data : std_logic_vector(15 downto 0);

  component leddec16
    port (
      dig   : in  std_logic_vector(2 downto 0);
      data  : in  std_logic_vector(15 downto 0);
      anode : out std_logic_vector(7 downto 0);
      seg   : out std_logic_vector(6 downto 0)
    );
  end component;

  signal score_int : integer range 0 to 65535;
  signal s_cap     : integer range 0 to 9999;
  signal thou, hund, tens_d, ones_d : integer range 0 to 9;

begin

  score_int <= to_integer(unsigned(score));
  s_cap     <= 9999 when score_int > 9999 else score_int;

  thou   <= s_cap / 1000;
  hund   <= (s_cap mod 1000) / 100;
  tens_d <= (s_cap mod 100)  / 10;
  ones_d <=  s_cap mod 10;

  -- Pack 4 decimal digits into 16-bit word (each nibble = one digit)
  bcd_data <= std_logic_vector(to_unsigned(thou,   4)) &
              std_logic_vector(to_unsigned(hund,   4)) &
              std_logic_vector(to_unsigned(tens_d, 4)) &
              std_logic_vector(to_unsigned(ones_d, 4));

  process(clk)
  begin
    if rising_edge(clk) then
      div_cnt <= div_cnt + 1;
      if div_cnt = 0 then
        if dig = "011" then
          dig <= "000";
        else
          dig <= dig + 1;
        end if;
      end if;
    end if;
  end process;

  U_DEC : leddec16
    port map (
      dig   => dig,
      data  => bcd_data,
      anode => anode,
      seg   => seg
    );

end Behavioral;