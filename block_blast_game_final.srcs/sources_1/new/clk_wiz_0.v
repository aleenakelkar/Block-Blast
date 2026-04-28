-- clk_wiz_0.vhd
-- Top-level clock wizard wrapper for Block Blast project
-- Output: CLK_OUT1 = 40 MHz for VGA 800x600 @ 60Hz

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity clk_wiz_0 is
port
 (clk_in1  : in  std_logic;
  clk_out1 : out std_logic
 );
end clk_wiz_0;

architecture xilinx of clk_wiz_0 is
  attribute CORE_GENERATION_INFO : string;
  attribute CORE_GENERATION_INFO of xilinx : architecture is
    "clk_wiz_0,clk_wiz_v5_1,{component_name=clk_wiz_0,use_phase_alignment=true," &
    "use_min_o_jitter=false,use_max_i_jitter=false,use_dyn_phase_shift=false," &
    "use_inclk_switchover=false,use_dyn_reconfig=false,enable_axi=0," &
    "feedback_source=FDBK_AUTO,PRIMITIVE=MMCM,num_out_clk=1,clkin1_period=10.0," &
    "clkin2_period=10.0,use_power_down=false,use_reset=false,use_locked=false," &
    "use_inclk_stopped=false,feedback_type=SINGLE,CLOCK_MGR_TYPE=NA,manual_override=false}";

  component clk_wiz_0_clk_wiz
  port
   (clk_in1  : in  std_logic;
    clk_out1 : out std_logic
   );
  end component;

begin

  U0 : clk_wiz_0_clk_wiz
  port map (
    clk_in1  => clk_in1,
    clk_out1 => clk_out1
  );

end xilinx;