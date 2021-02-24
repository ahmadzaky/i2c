library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use ieee.std_logic_textio.all;
use std.textio.all;


entity tb_i2c_master is
end entity;


architecture tb of tb_i2c_master is

component i2c_master is
  generic(
    input_clk   : integer := 50_000_000; 
    bus_clk     : integer := 400_000);   
    
  port(
    clk       : in  std_logic;                    
    reset_n   : in  std_logic;                    
    i2c_req   : in  std_logic;                    
    rw        : in  std_logic;  
    i2c_addr  : in  std_logic_vector(6 downto 0); 
    busy      : out std_logic; 	
    rd_valid  : out std_logic; 	
    wr_valid  : out std_logic; 					

    data_wr   : in  std_logic_vector(7 downto 0);  
    data_rd   : out std_logic_vector(7 downto 0);  
    
    ack_error : buffer std_logic;                 
    sda       : inout  std_logic;                 
    scl       : inout  std_logic);                    
end component;

 component i2c_slave is
  generic(
    i2c_addr    : std_logic_vector(6 downto 0);
    bus_clk     : integer := 400_000);   
    
  port(
    clk       : in  std_logic;                    
    reset_n   : in  std_logic;  
    rd_valid  : out std_logic;  
    wr_valid  : out std_logic; 	
    busy      : out std_logic; 					
    
    data_wr   : in  std_logic_vector(7 downto 0);  
    data_rd   : out std_logic_vector(7 downto 0);  
    
    ack_error : buffer std_logic;                 
    sda       : inout  std_logic;                 
    scl       : inout  std_logic);             
end component;

    type mem_test is array (0 to 7) of std_logic_vector(7 downto 0);
    signal test_vector  : mem_test := (X"8A", X"8B", X"0C", X"0D", X"0E", X"0F", X"18", X"27"); 
    signal s_clock      : std_logic;
    signal s_rstn       : std_logic;
    signal s_i2c_req    : std_logic;                   
    signal s_rw         : std_logic;  
    signal s_i2c_addr   : std_logic_vector(6 downto 0) := "0001110";
    signal s_rd_valid   : std_logic; 		
    signal s_wr_valid   : std_logic; 		
    signal s_valid      : std_logic; 					
    signal s_dat_to_wr  : std_logic_vector(5 downto 0);
    signal s_dat_to_rd  : std_logic_vector(5 downto 0);
    signal s_wen        : std_logic;                   
    signal s_wraddr     : std_logic_vector(5 downto 0);
    signal s_data_wr    : std_logic_vector(7 downto 0);
    signal s_rdaddr     : std_logic_vector(5 downto 0);
    signal s_data_rd    : std_logic_vector(7 downto 0);
    signal s_ack_error  : std_logic;                
    signal s_sda        : std_logic;                
    signal s_scl        : std_logic;             
    signal buff_wr_end  : std_logic;           
    signal s_busy       : std_logic;         
    signal s_slave_busy            : std_logic;
    signal s_slave_rd_valid        : std_logic; 
    signal s_slave_wr_valid        : std_logic; 					
    signal s_slave_data_available  : std_logic_vector(5 downto 0);
    signal s_slave_wen             : std_logic;                   
    signal s_slave_waddr           : std_logic_vector(5 downto 0);
    signal s_slave_data_wr         : std_logic_vector(7 downto 0);
    signal s_slave_raddr           : std_logic_vector(5 downto 0);
    signal s_slave_data_rd         : std_logic_vector(7 downto 0);            

begin
    
    SLV : i2c_slave
  generic map(
    i2c_addr    => "0001110",
    bus_clk     => 400_000)   
  port map(
    clk       => s_clock,                  
    reset_n   => s_rstn,             
    busy      => s_slave_busy,     
    rd_valid  => s_slave_rd_valid, 
    wr_valid  => s_slave_wr_valid, 	                         
    data_wr   => s_slave_data_wr,          
    data_rd   => s_slave_data_rd,          
    sda       => s_sda,                    
    scl       => s_scl                     
);
      
s_valid <= s_rd_valid or s_wr_valid;
    
  DUT : i2c_master
  generic map(
    input_clk   => 50_000_000,
    bus_clk     => 400_000) 
  port map(
    clk         =>  s_clock,                   
    reset_n     =>  s_rstn,                 
    i2c_req     =>  s_i2c_req,  
    rw          =>  s_rw,       
    i2c_addr    =>  s_i2c_addr, 
    busy        =>  s_busy,
    rd_valid    =>  s_rd_valid,
    wr_valid    =>  s_wr_valid,

    data_wr     =>  s_data_wr,   
    data_rd     =>  s_data_rd,  
    ack_error   =>  s_ack_error,
    sda         =>  s_sda,      
    scl         =>  s_scl      
    ); 

    s_rdaddr        <= "000000";
    s_dat_to_rd     <= "000000";
  
  
   process(s_rstn, s_rd_valid)
    begin
    if s_rstn = '0' then
        s_slave_data_wr <= "01010110";
    elsif s_rd_valid'event and s_rd_valid = '0' then
        s_slave_data_wr <= s_slave_data_wr+1;
    end if;
    end process;
  
   process
    begin
    s_rw            <= '1';
    s_i2c_addr  <= "0000110";
        wait for 100 ns;
    for J in 0 to 1 loop
        s_rw            <= not s_rw;
        buff_wr_end <= '0';
        s_data_wr   <= test_vector(0);
        wait for 20000 ns;
        s_i2c_req      <= '1';
       -- wait for 4000 ns;
        for I in 0 to 7 loop
            wait for 4000 ns;
            s_data_wr  <= test_vector(i);
            wait until s_valid = '1';
                if I < 5 then
                    
                s_i2c_addr  <= "0001110";
                end if;
        end loop;
        s_i2c_req      <= '0';
        buff_wr_end <= '1';
            wait for 100000 ns;
    end loop;
        wait;   
    end process;

   process
    begin
        s_clock <= '0';
        wait for 10 ns;
        s_clock <= '1';
        wait for 10 ns;
    end process;

   process
    begin
        s_rstn <= '0';
        wait for 100 ns;
        s_rstn <= '1';
        wait;
    end process;

   process
  variable sim_time_count : integer := 0;
  variable sim_time_str_v : string(1 to 30);
  variable sim_time_len_v : natural;
begin
    sim_time_len_v := time'image(now)'length;
    if sim_time_count = 600 then
     report "END OF SIMULATION"
              severity failure;
    end if;
    sim_time_str_v := (others => ' ');
    sim_time_str_v(1 to sim_time_len_v) := time'image(now);
    report "Simulation time " & sim_time_str_v;
        wait for 1000 ns;
        sim_time_count := sim_time_count+1;
  end process;
  
end tb;