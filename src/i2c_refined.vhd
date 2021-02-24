library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;


entity i2c_master is
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
end i2c_master;

architecture rtl of i2c_master is
  constant divider  :  integer := (input_clk/bus_clk)/4; --number of clocks in 1/4 cycle of scl
  type machine is(ready, start, command, slv_ack1, wr, rd, slv_ack2, mstr_ack, stop); 
  
  signal state          : machine;                       
  signal data_clk       : std_logic;                     
  signal data_clk_prev  : std_logic;                     
  signal scl_clk        : std_logic;                     
  signal scl_ena        : std_logic := '0';              
  signal sda_int        : std_logic := '1';              
  signal sda_in         : std_logic := '1';              
  signal sda_ena_n      : std_logic;                     
  signal addr_rw        : std_logic_vector(7 downto 0);  
  signal data_tx        : std_logic_vector(7 downto 0);  
  signal data_rx        : std_logic_vector(7 downto 0);  
  signal bit_cnt        : integer range 0 to 7 := 7;     
  signal stretch        : std_logic := '0';         
  signal rd_v      		: std_logic;                 
  signal wr_v      		: std_logic;   
  signal datout_wr 		: std_logic_vector(7 downto 0);
  signal data_rsv  		: std_logic_vector(7 downto 0);
  signal s_busy 		: std_logic;
  signal ena       		: std_logic;                   
  
  
begin


    process(clk, reset_n)
    variable count  :  integer range 0 to divider*4;  
    begin
    if(reset_n = '0') then                
        stretch <= '0';
        count := 0;
    elsif(clk'event and clk = '1') then
        data_clk_prev <= data_clk;          
        if(count = divider*4-1) then        
            count := 0;                     
        elsif(stretch = '0') then           
            count := count + 1;             
        end if;
        case count is
            when 0 to divider-1 =>          
                scl_clk  <= '0';
                data_clk <= '0';
            when divider to divider*2-1 =>  
                scl_clk  <= '0';
                data_clk <= '1';
            when divider*2 to divider*3-1 =>
                scl_clk <= '1';             
                data_clk <= '1';
                if(scl = '0') then          
                    stretch <= '1';
                else
                    stretch <= '0';
                end if;
            when others =>                  
                scl_clk <= '1';
                data_clk <= '0';
        end case;
    end if;
    end process;


    process(clk, reset_n)
    begin
    if(reset_n = '0') then                       
        state     <= ready;                      
        s_busy    <= '0';                        
        sda_int   <= '1';                        
        bit_cnt   <= 7;                          
        data_rsv  <= "00000000";                 
    elsif(clk'event and clk = '1') then
        if(data_clk = '1' and data_clk_prev = '0') then 
            case state is
                when ready =>                     
                    if(ena = '1') then            
                        s_busy  <= '1';           
                        addr_rw <= i2c_addr & rw; 
                        data_tx <= datout_wr;     
                        state   <= start;         
                    else                          
                        s_busy  <= '0';           
                        state   <= ready;         
                    end if;
                when start =>                     
                    s_busy  <= '1';               
                    sda_int <= addr_rw(bit_cnt);  
                    state   <= command;           
                when command =>               
                    s_busy  <= '1';                   
                    if(bit_cnt = 0) then          
                        sda_int <= '1';           
                        bit_cnt <= 7;             
                        state   <= slv_ack1;      
                    else                          
                        bit_cnt <= bit_cnt - 1;   
                        sda_int <= addr_rw(bit_cnt-1); 
                        state   <= command;             
                    end if;
                when slv_ack1 =>                 
                    s_busy  <= '1';               
                    if(addr_rw(0) = '0') then       
                        sda_int <= data_tx(bit_cnt);
                        state   <= wr;              
                    else                            
                        sda_int <= '1';             
                        state   <= rd;              
                    end if;
                when wr =>                        
                    s_busy <= '1';                
                    if(bit_cnt = 0) then          
                        sda_int <= '1';           
                        bit_cnt <= 7;             
                        state   <= slv_ack2;      
                    else                          
                        bit_cnt <= bit_cnt - 1;   
                        sda_int <= data_tx(bit_cnt-1);
                        state   <= wr;                
                    end if;
                when rd =>                        
                    s_busy <= '1';                
                    if(bit_cnt = 0) then          
                        if(ena = '1' and addr_rw = i2c_addr & rw) then 
                            sda_int <= '0';       
                        else                      
                            sda_int <= '1';       
                        end if;
                        bit_cnt  <= 7;            
                        data_rsv <= data_rx;      
                        state    <= mstr_ack;     
                    else                          
                        bit_cnt <= bit_cnt - 1;   
                        state   <= rd;            
                    end if;
                when slv_ack2 =>                  
                    if(ena = '1') then            
                        s_busy <= '1';            
                        addr_rw <= i2c_addr & rw; 
                        data_tx <= datout_wr;     
                        if(addr_rw = i2c_addr & rw) then  
                            sda_int <= datout_wr(bit_cnt);
                            state <= wr;          
                        else                      
                            state <= start;       
                        end if;
                    else                          
                        state <= stop;            
                    end if;
                when mstr_ack =>                  
                    if(ena = '1') then            
                        s_busy  <= '1';           
                        addr_rw <= i2c_addr & rw;       
                        data_tx <= datout_wr;           
                        if(addr_rw = i2c_addr & rw) then
                            sda_int <= '1';             
                            state <= rd;                
                        else                    
                            state <= start;     
                        end if;    
                    else                        
                        state <= stop;          
                    end if;
                when stop =>                    
                    s_busy <= '0';              
                    state  <= ready;            
            end case;  
        end if;
    end if;
    end process;  


    process(clk, reset_n)
    begin
    if(reset_n = '0') then                                 
        scl_ena   <= '0';                                  
        ack_error <= '0';                                  
        data_rx   <= (others => '0');                      
    elsif(clk'event and clk = '1') then       
        if(data_clk = '0' and data_clk_prev = '1') then    
            case state is
                when start =>                  
                    if(scl_ena = '0') then                 
                        scl_ena   <= '1';                  
                        ack_error <= '0';                  
                    end if;
                when slv_ack1 =>                           
                    if(sda /= '0' or ack_error = '1') then 
                        ack_error <= '1';                  
                    end if;
                when rd =>                                 
                    data_rx(bit_cnt) <= sda_in;               
                when slv_ack2 =>                           
                    if(sda /= '0' or ack_error = '1') then 
                        ack_error <= '1';                  
                    end if;
                when stop =>
                    scl_ena <= '0';                        
                when others =>
                    null;
            end case;
        end if;
    end if;
    end process;  

  -------------------------------------------------------------------------------------------------
	process(clk, reset_n)
	begin
	if reset_n = '0' then
		rd_v	<= '0';
	elsif clk'event and clk = '1' then
		if state = rd and bit_cnt = 0 then
			rd_v	<= '1';
		else
			rd_v	<= '0';
		end if;
	end if;
	end process;
  
	process(clk, reset_n)
	begin
	if reset_n = '0' then
		wr_v	<= '0';
	elsif clk'event and clk = '1' then
		if state = wr and bit_cnt = 0 then
			wr_v	<= '1';
		else
			wr_v	<= '0';
		end if;
	end if;
	end process;
	
	------------------------------------------------------------------------------------------------
  --set sda output
  with state select
    sda_ena_n <= data_clk_prev when start,     --generate start condition
                 NOT data_clk_prev when stop,  --generate stop condition
                 sda_int when others;          --set to internal sda signal    
      
  --set scl and sda outputs
  scl <= '0' when (scl_ena = '1' and scl_clk = '0') else 'Z';
  sda <= '0' when sda_ena_n = '0' else 'Z';
  sda_in <= '0' when (sda = '0') else '1';
  --------------------------------------------------------------------------------------------------

    
    process(clk, reset_n)
    begin
        if (reset_n = '0') then
            ena  <= '0';
        elsif (clk'event and clk = '1') then
            ena  <= i2c_req;
        end if;
    end process;

    ------------------------------------------------------------------------------


	datout_wr   <= data_wr;
	busy        <= s_busy;	
	rd_valid    <= rd_v;
	wr_valid    <= wr_v;
	data_rd     <= data_rsv;
	
	
	
end architecture;
