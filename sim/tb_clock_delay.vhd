library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity tb_clock_delay is
end entity;


architecture tb of tb_clock_delay is

component clock_delay is
	port
	(
		rst_n		: in  std_logic;
		clk		    : in  std_logic;
		data		: in  std_logic_vector (11 downto 0);
		clk_i   	: in  std_logic;
		clk_o   	: out std_logic
	);
end component;

	signal s_rst_n	    : std_logic;
	signal s_clk		: std_logic;
	signal s_data		: std_logic_vector (11 downto 0);
	signal s_clk_i   	: std_logic;
	signal s_clk_o   	: std_logic;

begin
    DUT : clock_delay
	port map
	(
		rst_n		=> s_rst_n,
		clk		    => s_clk,
		data		=> s_data,
		clk_i   	=> s_clk_i,
		clk_o   	=> s_clk_o
	);
  
  s_data <= X"00A";
  process
  begin
    s_rst_n <= '0';
    wait for 400 ns;
    s_rst_n <= '1';
    wait;
    end process;
    
  process
  begin
    s_clk <= '1';
    wait for 50 ns;
    s_clk <= '0';
    wait for 50 ns;
    end process;
    
  process
  begin
    s_clk_i <= '1';
    wait for 3500 ns;
    s_clk_i <= '0';
    wait for 6500 ns;
    end process;
	
end architecture;