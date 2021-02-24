library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;


entity i2c_master_ifc is
  generic(
    input_clk   : integer := 50_000_000; 
    bus_clk     : integer := 400_000);   
    
  port(
    clk       : in  std_logic;                    
    reset_n   : in  std_logic;                    
    i2c_start : in  std_logic;                    
    i2c_rw    : in  std_logic;  
    i2c_addr  : in  std_logic_vector(6 downto 0); 
    busy      : out std_logic; 	
    rd_valid  : out std_logic; 	
    wr_valid  : out std_logic; 					

    addr_wr   : in  std_logic_vector(5 downto 0); 
    addr_rd   : in  std_logic_vector(5 downto 0); 
    data_wr   : in  std_logic_vector(7 downto 0);  
    data_rd   : out std_logic_vector(7 downto 0));                
end i2c_master_ifc;
