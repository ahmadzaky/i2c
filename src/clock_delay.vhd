library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;


entity clock_delay is
	port
	(
		rst_n		: in  std_logic;
		clk		    : in  std_logic;
		data		: in  std_logic_vector (11 downto 0);
		clk_i   	: in  std_logic;
		clk_o   	: out std_logic
	);
end entity clock_delay;


architecture rtl of clock_delay is

	signal r_count	    : std_logic_vector(11 downto 0);
	signal r_count_en   : std_logic;
	signal r_trig       : std_logic;
	signal f_count	    : std_logic_vector(11 downto 0);
	signal f_count_en   : std_logic;
	signal f_trig       : std_logic;
	signal clk_prv      : std_logic;

begin

  process(clk, rst_n)
    begin
    if(rst_n = '0') then                                 
        clk_prv   <= '0';                               
    elsif(clk'event and clk = '1') then                                 
        clk_prv   <= clk_i;     
    end if;
    end process; 

  process(clk, rst_n)
    begin
    if(rst_n = '0') then                                 
        r_trig   <= '0';                                 
        f_trig   <= '0';                               
    elsif(clk'event and clk = '1') then                                 
        r_trig   <= r_count_en;                                 
        f_trig   <= f_count_en;     
    end if;
    end process; 

  process(clk, rst_n)
    begin
    if(rst_n = '0') then                                 
        r_count_en   <= '0';                               
    elsif(clk'event and clk = '1') then  
        if clk_i = '1' and clk_prv = '0' then 
            r_count_en   <= '1';  
        elsif r_count = data then                             
            r_count_en   <= '0';  
        end if;
    end if;
    end process; 

  process(clk, rst_n)
    begin
    if(rst_n = '0') then                                 
        f_count_en   <= '0';                               
    elsif(clk'event and clk = '1') then  
        if clk_i = '0' and clk_prv = '1' then 
            f_count_en   <= '1';  
        elsif f_count = data then                             
            f_count_en   <= '0';  
        end if;
    end if;
    end process; 

  process(clk, rst_n)
    begin
    if(rst_n = '0') then                                 
        r_count   <= (others => '0');                               
    elsif(clk'event and clk = '1') then  
        if r_count_en = '1' then
            if r_count = data then                      
                r_count <= (others => '0'); 
            else
                r_count <= r_count+1;
            end if;
        end if;
    end if;
    end process; 

  process(clk, rst_n)
    begin
    if(rst_n = '0') then                                 
        f_count   <= (others => '0');                               
    elsif(clk'event and clk = '1') then  
        if f_count_en = '1' then
            if f_count = data then                      
                f_count <= (others => '0'); 
            else
                f_count <= f_count+1;
            end if;
        end if;
    end if;
    end process; 

  process(clk, rst_n)
    begin
    if(rst_n = '0') then                                 
        clk_o   <= '0';                               
    elsif(clk'event and clk = '1') then  
        if r_count_en = '0' and r_trig = '1' then                             
                clk_o   <= '1';      
            elsif f_count_en = '0'  and f_trig = '1' then                       
                clk_o   <= '0'; 
        end if;
    end if;
    end process; 



	

	
end architecture;