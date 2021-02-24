library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;


entity i2c_slave is
  generic(
    i2c_addr    : std_logic_vector(6 downto 0) := "0110000";
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
end i2c_slave;

architecture rtl of i2c_slave is
  type machine is(ready, start, ignoring, command, slv_ack1, wr, rd, slv_ack2, mstr_ack, stop); 
  type mem is array (0 to 63) of std_logic_vector(7 downto 0);
  
  
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


  signal state          : machine;                        --state machine
  signal data_buff      : std_logic_vector(7 downto 0);   --data to write to slave
  signal data_clk       : std_logic;                      --data clock for sda
  signal data_clk_prev  : std_logic;                      --data clock during previous system clock
  signal scl_clk        : std_logic;                      --constantly running internal scl
  signal scl_ena        : std_logic := '0';               --enables internal scl to output
  signal sda_int        : std_logic := '1';               --internal sda
  signal sda_prev       : std_logic := '1';               --internal sda
  signal sda_ena_n      : std_logic;                      --enables internal sda to output
  signal addr_rw        : std_logic_vector(7 downto 0);   --latched in address and read/write
  signal data_tx        : std_logic_vector(7 downto 0);   --latched in data to write to slave
  signal data_rx        : std_logic_vector(7 downto 0);   --data received from slave
  signal bit_cnt        : integer range 0 to 7 := 7;      --tracks bit number in transaction
  signal stretch        : std_logic := '0';               --identifies if slave is stretching scl
  signal i2c_data_count	: integer range 0 to 63;
  signal i2c_send_count	: integer range 0 to 63;
  signal rd_v      		: std_logic;                 
  signal wr_v      		: std_logic;                    
  signal data_reg		: mem;                
  signal datawr_reg		: mem;
  signal datout_wr 		: std_logic_vector(7 downto 0);
  signal datout_rd 		: std_logic_vector(7 downto 0);
  signal data_rsv  		: std_logic_vector(7 downto 0);
  signal data_rsv_v  	: std_logic_vector(7 downto 0);
  signal s_busy 		: std_logic;
  signal ena       		: std_logic;
  signal ram_we         : std_logic;
  signal rd_v_d         : std_logic;
  signal rd_v_dd        : std_logic;   
  signal start_rsv      : std_logic;  
  signal stop_start     : std_logic;  
  signal start_valid    : std_logic;   
  signal start_rsv_prv  : std_logic;   
  signal scl_prv        : std_logic;  
  signal rw             : std_logic; 
  signal scl_in         : std_logic;  
  signal sda_in         : std_logic;  
  signal first_clk      : std_logic; 
  signal first_clk_prv  : std_logic;   
  signal clk_count      : integer;     
  signal clk_count_v    : integer;    
  signal clk_count_ar   : std_logic_vector(11 downto 0);                    
  
  
begin

    iDELAY : clock_delay
	port map
	(   
		rst_n	=> reset_n, --	: in  std_logic;
		clk		=> clk,     --    : in  std_logic;
		data	=> clk_count_ar,
		clk_i   => scl_in,  --	: in  std_logic;
		clk_o   => data_clk --	: out std_logic
	);
    clk_count_ar <= conv_std_logic_vector(clk_count_v/2,12);

    --generate the timing for the bus clock (scl_clk) and the data clock (data_clk)
--    process(clk, reset_n)
--    variable count  :  integer range 0 to divider*4;  --timing for clock generation
--    begin
--    if(reset_n = '0') then                
--        stretch <= '0';
--        count := 0;
--    elsif(clk'event and clk = '1') then
--        data_clk_prev <= data_clk;          
--        if(count = divider*4-1) then        
--            count := 0;                     
--        elsif(stretch = '0') then           
--            count := count + 1;             
--        end if;
--        case count is
--            when 0 to divider-1 =>          
--                scl_clk  <= '0';
--                data_clk <= '0';
--            when divider to divider*2-1 =>  
--                scl_clk  <= '0';
--                data_clk <= '1';
--            when divider*2 to divider*3-1 =>
--                scl_clk <= '1';             
--                data_clk <= '1';
--                if(scl = '0') then          
--                    stretch <= '1';
--                else
--                    stretch <= '0';
--                end if;
--            when others =>                  
--                scl_clk <= '1';
--                data_clk <= '0';
--        end case;
--    end if;
--    end process;

  --state machine and writing to sda during scl low (data_clk rising edge)
    process(clk, reset_n)
    begin
    if(reset_n = '0') then                      
        state     <= ready;                     
        s_busy    <= '1';                       
        sda_int   <= '1';                       
        rw        <= '0';                       
        bit_cnt   <= 7;                         
        data_rsv  <= "00000000";                  
    elsif(clk'event and clk = '1') then
        if(data_clk_prev = '1' and data_clk = '0') then  --data clock rising edge
            case state is
                when ready =>                     
  --                  if(start_rsv = '1') then    
                        sda_int <= '1';          
                        s_busy  <= '0';           
                        data_tx <= datout_wr;     
                        state   <= ready;         
  --                  else                          
  --                      s_busy  <= '0';           
  --                      state   <= ready;         
  --                  end if;        
                when start =>                     
  --                  if(start_rsv = '1') then            
                        s_busy  <= '1';           
                        data_tx <= datout_wr;     
                        state   <= command;         
  --                  else                          
  --                      s_busy  <= '0';           
  --                      state   <= ready;         
  --                  end if;        
                when command =>                 
                    s_busy  <= '1';                
                    if(bit_cnt = 0) then             
                        bit_cnt <= 7;          
                        rw      <= data_rx(0);
                         if(data_rx(7 downto 1) = i2c_addr) then         
                            sda_int <= '0';    
                            state   <= slv_ack1;  
                         else                       
                            sda_int <= '1';    
                            state   <= ignoring;  
                         end if;
                    else                          
                        bit_cnt <= bit_cnt - 1;   
                        sda_int <= '1';
                        state   <= command;           
                    end if;
                 when slv_ack1 =>               
                      s_busy  <= '1';                     
                      if(data_rx(7 downto 1) = i2c_addr) then         
                             if rw = '1' then
                                 state   <= wr; 
                                 sda_int <= data_tx(bit_cnt);
                             else          
                                 state   <= rd;                         
                                sda_int <= '1';     
                             end if;
                      else        
                          state   <= ignoring;                         
                          sda_int <= '1';                  
                      end if;
                 when wr =>                            
                     s_busy <= '1';                    
                     if(bit_cnt = 0) then              
                         sda_int <= '1';               
                         bit_cnt <= 7;                 
                         state   <= mstr_ack;          
                     else                              
                         bit_cnt <= bit_cnt - 1;       
                         sda_int <= data_tx(bit_cnt-1);
                         state   <= wr;                
                     end if;
                 when rd =>                       
                     s_busy <= '1';               
                     if(bit_cnt = 0) then         
                         sda_int <= '0';      
                         bit_cnt  <= 7;           
                         data_rsv <= data_rx;     
                         state    <= slv_ack2;    
                     else                         
                         bit_cnt <= bit_cnt - 1;                       
                         state   <= rd;  
                     end if;
                when slv_ack2 =>               
                      s_busy <= '1';          
 --                   if(ena = '1') then              
                            sda_int <= '1';
                            state   <= rd;         
  --                  else                         
  --                      state <= stop;           
  --                  end if;
                when mstr_ack =>                   
                         s_busy  <= '1';          
                         data_tx <= datout_wr;    
                         if(data_rx(bit_cnt) = '0') then           
                            state <= wr;            
                            sda_int <= data_tx(bit_cnt);      
                         else                            
                            state <= stop;       
                            sda_int <= '1';        
                         end if;    
                when stop =>         
                    sda_int <= '1';                
                    s_busy <= '0';                      
                    state  <= ready;   
                when others =>                            
                    s_busy <= '0';                      
                    state  <= ready;                    
            end case;  
        elsif start_valid = '1' then     
                    sda_int <= '1';     
            state   <= start; 
        elsif stop_start = '1' then    
                    sda_int <= '1';      
            state   <= ready; 
        end if;
    end if;
    end process;  

    
    process(clk, reset_n)
    begin
    if(reset_n = '0') then                                 
        stop_start   <= '1';                               
    elsif(clk'event and clk = '1') then                                 
        if sda_in = '1' and sda_prev = '0' then 
            stop_start   <= scl_prv;        
        else
     --   elsif  start_rsv_prv = '0' and start_rsv = '1'  then 
            stop_start   <= '0';    
        end if;
    end if;
    end process; 
    
    process(clk, reset_n)
    begin
    if(reset_n = '0') then                                 
        start_valid   <= '0';                               
    elsif(clk'event and clk = '1') then                                 
        if sda_in = '0' and sda_prev = '1'  then 
            start_valid   <= scl_prv;                             
        else
            start_valid   <= '0';    
        end if;
    end if;
    end process; 
    
    process(clk, reset_n)
    begin
    if(reset_n = '0') then                                 
        first_clk   <= '0';                               
    elsif(clk'event and clk = '1') then                                 
        if start_rsv_prv = '1' and start_rsv = '0' then 
            first_clk   <= '1';                              
        elsif scl_prv = '1' then
            first_clk   <= '0'; 
        end if;
    end if;
    end process; 
    
    process(clk, reset_n)
    begin
    if(reset_n = '0') then                                 
        first_clk_prv   <= '0';                               
    elsif(clk'event and clk = '1') then                                 
        first_clk_prv   <= first_clk;     
    end if;
    end process; 
    
    process(clk, reset_n)
    begin
    if(reset_n = '0') then                                 
        start_rsv_prv   <= '0';                               
    elsif(clk'event and clk = '1') then                                 
        start_rsv_prv   <= start_rsv;     
    end if;
    end process; 

    process(clk, reset_n)
    begin
    if(reset_n = '0') then                                 
        start_rsv   <= '0';                               
    elsif(clk'event and clk = '1') then       
        if state = ready then
             start_rsv <= not sda_in;
        else                             
            start_rsv   <= '0';      
        end if;
    end if;
    end process; 
    
    scl_in <= '0' when (scl = '0') else '1';
    sda_in <= '0' when (sda = '0') else '1';
    
    process(clk, reset_n)
    begin
    if(reset_n = '0') then                                 
        data_clk_prev   <= '0';                               
    elsif(clk'event and clk = '1') then                                 
        data_clk_prev   <= data_clk;     
    end if;
    end process; 
    
    process(clk, reset_n)
    begin
    if(reset_n = '0') then                                 
        sda_prev   <= '1';                               
    elsif(clk'event and clk = '1') then                                 
        sda_prev   <= sda_in;     
    end if;
    end process; 
    
    process(clk, reset_n)
    begin
    if(reset_n = '0') then                                 
        scl_prv   <= '0';                               
    elsif(clk'event and clk = '1') then                                 
        scl_prv   <= scl_in;     
    end if;
    end process; 

    process(clk, reset_n)
    begin
    if(reset_n = '0') then                                 
        clk_count   <= 0;                               
    elsif(clk'event and clk = '1') then    
      --  if state = command then
            if first_clk = '1' then
                clk_count   <= clk_count+1;
            elsif state = ready then                                                    
                clk_count   <= 0;     
            end if;
      --  end if;
    end if;
    end process; 

    process(clk, reset_n)
    begin
    if(reset_n = '0') then                                 
        clk_count_v   <= 0;                               
    elsif(clk'event and clk = '1') then       
        if(first_clk_prv = '1' and first_clk = '0') then   
                clk_count_v   <= clk_count;
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
        if(scl_in = '0' and scl_prv = '1') then    
            case state is
                when ignoring =>                  
                    if(scl_ena = '0') then                 
                        scl_ena   <= '1';                  
                        ack_error <= '0';                  
                    end if;
                when slv_ack1 =>                           
                    if(sda /= '0' or ack_error = '1') then 
                        ack_error <= '1';                  
                    end if;
                when command =>                                 
                    data_rx(bit_cnt) <= sda_in;     
                when rd =>                                 
                    data_rx(bit_cnt) <= sda_in;     
                when mstr_ack =>                                 
                    data_rx(bit_cnt) <= sda_in;               
                when slv_ack2 =>                           
                    if(sda /= '0' or ack_error = '1') then 
                        ack_error <= '1';                  
                    end if;
                when stop =>
                    scl_ena <= '0';   
                when ready =>                  
                    data_rx   <= (others => '0');                        
                when others =>
                    null;
            end case;
        end if;
    end if;
    end process;  

  
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
	
    rd_valid    <= rd_v;
    wr_valid    <= wr_v;
	busy        <= s_busy;	
	data_rd     <= data_rsv;
	datout_wr   <= data_wr;
	
  --set sda output

    sda_ena_n <= sda_int ;          --set to internal sda signal    
      
  --set scl and sda outputs
  scl <= '0' when (scl_ena = '1' and scl_clk = '0') else 'Z';
  sda <= '0' when sda_ena_n = '0' else 'Z';
  


	

	
	
end architecture;
