library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity block_blast_game is
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
end block_blast_game;

architecture Behavioral of block_blast_game is

  -- -------------------------------------------------------
  -- Grid constants
  -- -------------------------------------------------------
 constant GRID_COLS   : integer := 8;
constant GRID_ROWS   : integer := 8;
constant CELL_SIZE   : integer := 68;
constant GRID_LEFT   : integer := 128;
constant GRID_TOP    : integer := 28;
constant GRID_RIGHT  : integer := GRID_LEFT + GRID_COLS * CELL_SIZE;
constant GRID_BOTTOM : integer := GRID_TOP  + GRID_ROWS * CELL_SIZE; 

  -- -------------------------------------------------------
  -- Grid types
  -- Occupancy grid: 1 = filled
  -- Color grid: 3-bit piece-type index stored per cell
  -- -------------------------------------------------------
  type grid_row_t       is array(0 to GRID_COLS-1) of std_logic;
  type grid_t           is array(0 to GRID_ROWS-1) of grid_row_t;
  type color_row_t      is array(0 to GRID_COLS-1) of std_logic_vector(2 downto 0);
  type color_grid_t     is array(0 to GRID_ROWS-1) of color_row_t;

  signal grid       : grid_t;
  signal color_grid : color_grid_t;

  -- -------------------------------------------------------
  -- Piece shape lookup (8 types, 3x3 bitmask)
  -- -------------------------------------------------------
  type all_shapes_t is array(0 to 7, 0 to 2, 0 to 2) of std_logic;
  constant SHAPES : all_shapes_t := (
    (('1','0','0'),('0','0','0'),('0','0','0')),  -- 0: 1x1
    (('1','1','0'),('0','0','0'),('0','0','0')),  -- 1: 1x2H
    (('1','1','1'),('0','0','0'),('0','0','0')),  -- 2: 1x3H
    (('1','0','0'),('1','0','0'),('0','0','0')),  -- 3: 2x1V
    (('1','0','0'),('1','0','0'),('1','0','0')),  -- 4: 3x1V
    (('1','1','0'),('1','1','0'),('0','0','0')),  -- 5: 2x2
    (('1','0','0'),('1','0','0'),('1','1','0')),  -- 6: L
    (('0','1','0'),('0','1','0'),('1','1','0'))   -- 7: J
  );

  -- -------------------------------------------------------
  -- Color palette lookup: (R 2-bit, G 1-bit, B 1-bit)
  -- Index = piece_type (0-7)
  -- -------------------------------------------------------
  type color_entry_t is record
    r : std_logic_vector(1 downto 0);
    g : std_logic;
    b : std_logic;
  end record;
  type palette_t is array(0 to 7) of color_entry_t;

  constant PALETTE : palette_t := (
    0 => (r => "11", g => '0', b => '0'),  -- Red
    1 => (r => "00", g => '1', b => '0'),  -- Green
    2 => (r => "00", g => '0', b => '1'),  -- Blue
    3 => (r => "11", g => '1', b => '0'),  -- Yellow
    4 => (r => "11", g => '0', b => '1'),  -- Magenta
    5 => (r => "00", g => '1', b => '1'),  -- Cyan
    6 => (r => "10", g => '1', b => '0'),  -- Orange
    7 => (r => "11", g => '1', b => '1')   -- White
  );

  -- -------------------------------------------------------
  -- Game state
  -- -------------------------------------------------------
  signal piece_type : std_logic_vector(2 downto 0) := "000";
  signal cursor_r   : integer range 0 to GRID_ROWS-1 := 0;
  signal cursor_c   : integer range 0 to GRID_COLS-1 := 0;
  signal lfsr       : std_logic_vector(7 downto 0)   := "11111110";
  signal score      : integer range 0 to 65535        := 0;
  signal game_over  : std_logic := '0';

  -- -------------------------------------------------------
  -- Button debounce
  -- -------------------------------------------------------
  signal btn_l_prev, btn_r_prev, btn_u_prev, btn_d_prev, btn_p_prev : std_logic := '0';
  signal btn_l_pulse, btn_r_pulse, btn_u_pulse, btn_d_pulse, btn_p_pulse : std_logic := '0';
  signal clk_div  : std_logic_vector(21 downto 0) := (others => '0');
  signal slow_tick : std_logic := '0';

--does the piece fit, check row and col, taken from og tetris
  function piece_fits(g     : grid_t;
                      ptype : std_logic_vector(2 downto 0);
                      r     : integer;
                      c     : integer) return boolean is
    variable pt : integer;
  begin
    pt := to_integer(unsigned(ptype));
    for pr in 0 to 2 loop
      for pc in 0 to 2 loop
        if SHAPES(pt, pr, pc) = '1' then
          if (r + pr) >= GRID_ROWS or (c + pc) >= GRID_COLS then return false; end if;
          if g(r + pr)(c + pc) = '1'                        then return false; end if;
        end if;
      end loop;
    end loop;
    return true;
  end function;

begin

  score_out <= std_logic_vector(to_unsigned(score, 16));

--slow tick, taken from og tetris
  process(clk)
  begin
    if rising_edge(clk) then
      clk_div  <= clk_div + 1;
      slow_tick <= '0';
      if clk_div = 0 then slow_tick <= '1'; end if;
    end if;
  end process;
  -- Button edge detection
  process(clk)
  begin
    if rising_edge(clk) then
      btn_l_pulse <= '0'; btn_r_pulse <= '0';
      btn_u_pulse <= '0'; btn_d_pulse <= '0'; btn_p_pulse <= '0';
      if slow_tick = '1' then
        if btn_left  = '1' and btn_l_prev = '0' then btn_l_pulse <= '1'; end if;
        if btn_right = '1' and btn_r_prev = '0' then btn_r_pulse <= '1'; end if;
        if btn_up    = '1' and btn_u_prev = '0' then btn_u_pulse <= '1'; end if;
        if btn_down  = '1' and btn_d_prev = '0' then btn_d_pulse <= '1'; end if;
        if btn_place = '1' and btn_p_prev = '0' then btn_p_pulse <= '1'; end if;
        btn_l_prev <= btn_left;  btn_r_prev <= btn_right;
        btn_u_prev <= btn_up;    btn_d_prev <= btn_down;
        btn_p_prev <= btn_place;
      end if;
    end if;
  end process;
  -- Game logic
  process(clk)
    variable new_grid       : grid_t;
    variable new_color_grid : color_grid_t;
    variable row_full       : std_logic;
    variable col_full       : std_logic;
    variable lines          : integer;
    variable next_lfsr      : std_logic_vector(7 downto 0);
    variable next_type      : integer;
    variable any_fit        : boolean;
    variable pt             : integer;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        for r in 0 to GRID_ROWS-1 loop
          for c in 0 to GRID_COLS-1 loop
            grid(r)(c)             <= '0';
            color_grid(r)(c)       <= "000";
          end loop;
        end loop;
        cursor_r   <= 0; cursor_c   <= 0;
        piece_type <= "000";
        score      <= 0;
        game_over  <= '0';
        lfsr       <= "10110011";

      elsif game_over = '0' then

        if btn_l_pulse = '1' and cursor_c > 0             then cursor_c <= cursor_c - 1; end if;
        if btn_r_pulse = '1' and cursor_c < GRID_COLS - 1 then cursor_c <= cursor_c + 1; end if;
        if btn_u_pulse = '1' and cursor_r > 0             then cursor_r <= cursor_r - 1; end if;
        if btn_d_pulse = '1' and cursor_r < GRID_ROWS - 1 then cursor_r <= cursor_r + 1; end if;

        if btn_p_pulse = '1' then
          pt := to_integer(unsigned(piece_type));
          if piece_fits(grid, piece_type, cursor_r, cursor_c) then

            -- Stamp piece onto both grids
            new_grid       := grid;
            new_color_grid := color_grid;
            for pr in 0 to 2 loop
              for pc in 0 to 2 loop
                if SHAPES(pt, pr, pc) = '1' then
                  new_grid(cursor_r + pr)(cursor_c + pc)       := '1';
                  new_color_grid(cursor_r + pr)(cursor_c + pc) := piece_type;
                end if;
              end loop;
            end loop;

            -- Clear full rows
            lines := 0;
            for r in 0 to GRID_ROWS-1 loop
              row_full := '1';
              for c in 0 to GRID_COLS-1 loop
                if new_grid(r)(c) = '0' then row_full := '0'; end if;
              end loop;
              if row_full = '1' then
                lines := lines + 1;
                for c in 0 to GRID_COLS-1 loop
                  new_grid(r)(c)       := '0';
                  new_color_grid(r)(c) := "000";
                end loop;
              end if;
            end loop;

            -- Clear full columns
            for c in 0 to GRID_COLS-1 loop
              col_full := '1';
              for r in 0 to GRID_ROWS-1 loop
                if new_grid(r)(c) = '0' then col_full := '0'; end if;
              end loop;
              if col_full = '1' then
                lines := lines + 1;
                for r in 0 to GRID_ROWS-1 loop
                  new_grid(r)(c)       := '0';
                  new_color_grid(r)(c) := "000";
                end loop;
              end if;
            end loop;

            grid       <= new_grid;
            color_grid <= new_color_grid;

            if score + lines * 10 + 1 > 65535 then
              score <= 65535;
            else
              score <= score + lines * 10 + 1;
            end if;

            -- Next piece
            next_lfsr  := lfsr(6 downto 0) & (lfsr(7) xor lfsr(5) xor lfsr(4) xor lfsr(3));
            lfsr       <= next_lfsr;
            next_type  := to_integer(unsigned(next_lfsr(2 downto 0)));
            piece_type <= std_logic_vector(to_unsigned(next_type, 3));

            -- Game-over check
            any_fit := false;
            for tr in 0 to GRID_ROWS-1 loop
              for tc in 0 to GRID_COLS-1 loop
                if piece_fits(new_grid,
                              std_logic_vector(to_unsigned(next_type, 3)),
                              tr, tc) then
                  any_fit := true;
                end if;
              end loop;
            end loop;
            if not any_fit then game_over <= '1'; end if;

          end if;
        end if;
      end if;
    end if;
  end process;

  process(pixel_row, pixel_col, grid, color_grid, cursor_r, cursor_c, piece_type, game_over)
    variable current_x_int, current_y_int     : integer;
    variable in_grid        : boolean;
    variable cell_r, cell_c : integer;
    variable row_i, col_i   : integer;
    variable on_border      : boolean;
    variable on_piece       : boolean;
    variable cell_occupied  : std_logic;
    variable cell_color_s : integer range 0 to 7;
    variable piece_color_s: integer range 0 to 7;
    variable r_out          : std_logic_vector(1 downto 0);
    variable g_out, b_out   : std_logic;
  begin
    r_out := "00"; g_out := '0'; b_out := '0';

    current_x_int := to_integer(unsigned(pixel_col));
    current_y_int := to_integer(unsigned(pixel_row));

    in_grid := (current_x_int >= GRID_LEFT) and (current_x_int < GRID_RIGHT) and
               (current_y_int >= GRID_TOP)  and (current_y_int < GRID_BOTTOM);

    if in_grid then
      cell_c := (current_x_int - GRID_LEFT) / CELL_SIZE;
      cell_r := (current_y_int - GRID_TOP)  / CELL_SIZE;
      col_i  := (current_x_int - GRID_LEFT) mod CELL_SIZE;
      row_i  := (current_y_int - GRID_TOP)  mod CELL_SIZE;

      on_border := (row_i < 2) or (row_i >= CELL_SIZE-2) or
                   (col_i < 2) or (col_i >= CELL_SIZE-2);

      cell_occupied   := grid(cell_r)(cell_c);
      cell_color_s  := to_integer(unsigned(color_grid(cell_r)(cell_c)));
      piece_color_s := to_integer(unsigned(piece_type));

      on_piece := false;
      for pr in 0 to 2 loop
        for pc in 0 to 2 loop
          if SHAPES(piece_color_s, pr, pc) = '1' then
            if (cursor_r + pr) = cell_r and (cursor_c + pc) = cell_c then
              on_piece := true;
            end if;
          end if;
        end loop;
      end loop;

      if game_over = '1' then
        if cell_occupied = '1' then
          r_out := "11"; g_out := '0'; b_out := '0';
        else
          r_out := "01"; g_out := '0'; b_out := '0';
        end if;
        
      elsif on_border then
       
        
        r_out := "00"; g_out := '0'; b_out := '0';
        

       elsif on_piece then
     
        r_out := PALETTE(piece_color_s).r;
        g_out := PALETTE(piece_color_s).g;
        b_out := PALETTE(piece_color_s).b;
      
      elsif cell_occupied = '1' then
        -- Placed block: full color from palette
        r_out := PALETTE(cell_color_s).r;
        g_out := PALETTE(cell_color_s).g;
        b_out := PALETTE(cell_color_s).b;
      
     
      else
        r_out := "00"; g_out := '0'; b_out := '0';
      end if;

    else
      r_out := "00"; g_out := '0'; b_out := '0';
      if (current_x_int = GRID_LEFT-1 or current_x_int = GRID_RIGHT) then
        if current_y_int >= GRID_TOP-1 and current_y_int <= GRID_BOTTOM then
          r_out := "01"; g_out := '1'; b_out := '1';
        end if;
      end if;
      if (current_y_int = GRID_TOP-1 or current_y_int = GRID_BOTTOM) then
        if current_x_int >= GRID_LEFT-1 and current_x_int <= GRID_RIGHT then
          r_out := "01"; g_out := '1'; b_out := '1';
        end if;
      end if;
    end if;

    red_out   <= r_out;
    green_out <= g_out;
    blue_out  <= b_out;
  end process;

end Behavioral;