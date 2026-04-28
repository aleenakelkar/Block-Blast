-- block_blast_top.vhd
-- Top-level for Block Blast on Nexys A7-100T
-- Uses leddec16 (via leddec wrapper) for score display

library ieee;
use ieee.std_logic_1164.all;

entity block_blast_top is
  port (
    CLK100MHZ  : in  std_logic;
    CPU_RESETN : in  std_logic;                
    BTNL       : in  std_logic;
    BTNR       : in  std_logic;
    BTNU       : in  std_logic;
    BTND       : in  std_logic;
    BTNC       : in  std_logic;
    VGA_R      : out std_logic_vector(3 downto 0);
    VGA_G      : out std_logic_vector(3 downto 0);
    VGA_B      : out std_logic_vector(3 downto 0);
    VGA_HS     : out std_logic;
    VGA_VS     : out std_logic;
    SEG        : out std_logic_vector(6 downto 0);
    DP         : out std_logic;
    AN         : out std_logic_vector(7 downto 0)
  );
end block_blast_top;

architecture Structural of block_blast_top is

  signal clk40          : std_logic;
  signal rst            : std_logic;
  signal score_sig      : std_logic_vector(15 downto 0);
  signal red_to_vga     : std_logic_vector(1 downto 0);
  signal green_to_vga   : std_logic;
  signal blue_to_vga    : std_logic;
  signal red_from_vga   : std_logic_vector(1 downto 0);
  signal green_from_vga : std_logic;
  signal blue_from_vga  : std_logic;
  signal pixel_row      : std_logic_vector(10 downto 0);
  signal pixel_col      : std_logic_vector(10 downto 0);

  component clk_wiz_0
    port (clk_in1 : in std_logic; clk_out1 : out std_logic);
  end component;

  component vga_sync
    port (
      pixel_clk : in  std_logic;
      red_in    : in  std_logic_vector(1 downto 0);
      green_in  : in  std_logic;
      blue_in   : in  std_logic;
      red_out   : out std_logic_vector(1 downto 0);
      green_out : out std_logic;
      blue_out  : out std_logic;
      hsync     : out std_logic;
      vsync     : out std_logic;
      pixel_row : out std_logic_vector(10 downto 0);
      pixel_col : out std_logic_vector(10 downto 0)
    );
  end component;

  component block_blast_game
    port (
      clk        : in  std_logic;
      rst        : in  std_logic;
      btn_left   : in  std_logic;
      btn_right  : in  std_logic;
      btn_up     : in  std_logic;
      btn_down   : in  std_logic;
      btn_place  : in  std_logic;
      pixel_row  : in  std_logic_vector(10 downto 0);
      pixel_col  : in  std_logic_vector(10 downto 0);
      score_out  : out std_logic_vector(15 downto 0);
      red_out    : out std_logic_vector(1 downto 0);
      green_out  : out std_logic;
      blue_out   : out std_logic
    );
  end component;

  component leddec
    port (
      clk   : in  std_logic;
      score : in  std_logic_vector(15 downto 0);
      seg   : out std_logic_vector(6 downto 0);
      anode : out std_logic_vector(7 downto 0)
    );
  end component;

begin

  rst <= not CPU_RESETN;

  U_CLK : clk_wiz_0
    port map (clk_in1 => CLK100MHZ, clk_out1 => clk40);

  U_GAME : block_blast_game
    port map (
      clk       => clk40,       rst       => rst,
      btn_left  => BTNL,        btn_right => BTNR,
      btn_up    => BTNU,        btn_down  => BTND,
      btn_place => BTNC,
      pixel_row => pixel_row,   pixel_col => pixel_col,
      score_out => score_sig,
      red_out   => red_to_vga,  green_out => green_to_vga,
      blue_out  => blue_to_vga
    );

  U_VGA : vga_sync
    port map (
      pixel_clk => clk40,
      red_in    => red_to_vga,    green_in  => green_to_vga,
      blue_in   => blue_to_vga,
      red_out   => red_from_vga,  green_out => green_from_vga,
      blue_out  => blue_from_vga,
      hsync     => VGA_HS,        vsync     => VGA_VS,
      pixel_row => pixel_row,     pixel_col => pixel_col
    );

  U_LED : leddec
    port map (
      clk   => clk40,
      score => score_sig,
      seg   => SEG,
      anode => AN
    );

  DP    <= '1';

  VGA_R <= red_from_vga   & red_from_vga;
  VGA_G <= green_from_vga & green_from_vga & green_from_vga & green_from_vga;
  VGA_B <= blue_from_vga  & blue_from_vga  & blue_from_vga  & blue_from_vga;

end Structural;