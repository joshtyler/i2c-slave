library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.i2c_package.all;

entity i2c is
    Generic ( no_ro_regs : integer range 0 to 128; --Address space is 0x0 to 0x7F. 128 combinations
	           no_rw_regs : integer range 0 to 128; --Address space is 0x80 to 0xFF. 128 combinations
	           module_addr : STD_LOGIC_VECTOR(SLV_ADDR_WIDTH-1 downto 0));
    Port ( sda : in  STD_LOGIC;
           sda_wen : out STD_LOGIC;
           scl : in  STD_LOGIC;
           ro_regs : in  array8 (0 to no_ro_regs-1);
           rw_regs : out  array8 (0 to no_rw_regs-1));
end i2c;

architecture Behavioral of i2c is
	
	-- Top level state machine
	type sm_type is (SM_RECEIVE, SM_SEND, SM_SEND_ACK, SM_RECEIVE_ACK, SM_WAIT);
	signal top_state : sm_type;

	-- Receive state machine
	type rec_sm_type is (REC_SM_SLV_ADDR, REC_SM_REG_ADDR, REC_SM_DATA);
	signal receive_state : rec_sm_type;
	
	type mode_type is (MD_RECEIVE, MD_SEND);
	signal mode : mode_type;
	
	signal data : std_logic_vector(D_WIDTH-1 downto 0); -- General purpose register to store received word
	signal reg_addr : std_logic_vector(D_WIDTH-1 downto 0);
	signal receive_ctr : integer range 0 to D_WIDTH-1;
	signal send_ctr : integer range 1 to D_WIDTH+1 := 1; --Go to D_WIDTH+2 as we need to count up to ACK. We must initialise to make first send work correctly
	
	signal start_condition : std_logic := '0'; -- Pulses when start condition detected, init to none
	signal stop_condition : std_logic := '0'; -- Pulses when stop condition detected, init to none
	
	type status_type is (ST_STOPPED, ST_STARTED);
	signal status : status_type := ST_STOPPED; -- Init to stopped
	
	--Intermediatory signals to allow readback of output
	signal sda_wen_buf : std_logic := '0'; --Init to 0 to not drive line
	signal rw_regs_buf : array8 (0 to no_rw_regs-1);
--
begin

	--Intermediatory signals to allow readback of output
	sda_wen <= sda_wen_buf;
	rw_regs <= rw_regs_buf;

	-- Detect start condition
	detect_start : process(sda)
	begin
	
		if falling_edge(sda) then
			if scl = '1' and sda_wen_buf = '0' then -- Stop from triggering based on ACK
				start_condition <= '1';
			else 
				start_condition <= '0';
			end if;
		end if;
	end process detect_start;
	
	-- Detect stop condition
	detect_stop : process(sda)
	begin
		if rising_edge(sda) then
			if scl = '1' and sda_wen_buf = '0' then -- Stop from triggering based on ACK
				stop_condition <= '1';
			else 
				stop_condition <= '0';
			end if;
		end if;
	end process detect_stop;
	
	
	-- Set status
	set_status : process(start_condition, stop_condition)
	begin
		if rising_edge(start_condition) then
			status <= ST_STARTED;
		elsif rising_edge(stop_condition) then
			status <= ST_STOPPED;
		end if;
	end process set_status;


	main_sm : process(scl, start_condition)
	begin
		if rising_edge(start_condition) then
			-- Reset
			top_state <= SM_RECEIVE;
			receive_state <= REC_SM_SLV_ADDR;
			receive_ctr <= 0;
		elsif rising_edge(scl) and status = ST_STARTED then -- Proceed on errors, so that we can output them!
			case top_state is
				--Receive module address
				when SM_RECEIVE =>
					--If we have received the entire word
					if receive_ctr = D_WIDTH-1 then
						top_state <= SM_SEND_ACK; -- May be overwritten later
						receive_ctr <= 0;
						case receive_state is
							when REC_SM_SLV_ADDR =>
								receive_state <= REC_SM_REG_ADDR;
								-- If the slave address matches
								if data(D_WIDTH-2 downto 0) = module_addr then
									-- Save whether read or write mode
									if sda = '1' then
										mode <= MD_SEND;
									else
										mode <= MD_RECEIVE;
									end if;
								else
									top_state <= SM_WAIT;
								end if;
							when REC_SM_REG_ADDR =>
								reg_addr <= data(D_WIDTH-2 downto 0) & sda;
								receive_state <= REC_SM_DATA;
							when REC_SM_DATA =>
								if check_in_range(reg_addr, no_rw_regs, RW_REG_OFFSET) then
									rw_regs_buf(to_integer(unsigned(reg_addr))) <= data(D_WIDTH-2 downto 0) & sda;
									reg_addr <= std_logic_vector(unsigned(reg_addr) + 1);
								else
									top_state <= SM_WAIT; -- Out of range, so do not ack and wait for next transaction
								end if;
						end case;
					else
						-- Shift left, as MSB first
						data <= data(D_WIDTH-2 downto 0) & sda;
						receive_ctr <= receive_ctr + 1;
					end if;
					
				when SM_SEND_ACK =>
					--Sent in external process
					if mode = MD_RECEIVE then
						--If we're going to receive data
						top_state <= SM_RECEIVE;
					elsif check_in_range(reg_addr, no_rw_regs, RW_REG_OFFSET) or check_in_range(reg_addr, no_ro_regs, RO_REG_OFFSET) then
						--If we're going to send data and are in range
						top_state <= SM_SEND;
					else
						--If the requested register is out of range
						top_state <= SM_WAIT;
					end if;
				
				when SM_SEND =>
					if send_ctr = 1 then
						--We've transmitted the entire word, check for ack
						if sda = '0' and (check_in_range(std_logic_vector(unsigned(reg_addr) + 1), no_rw_regs, RW_REG_OFFSET) or check_in_range(std_logic_vector(unsigned(reg_addr) + 1), no_ro_regs, RO_REG_OFFSET)) then
							--Master ACK and next register would be in range
							reg_addr <= std_logic_vector(unsigned(reg_addr) + 1);
						else
							--Master NACK or next register would not be in range
							top_state <= SM_WAIT;
						end if;
					end if;
					
				when SM_WAIT=>
					-- Do nothing. We will reset on next start condition
				when others =>
					-- This should never happen!
					-- Do nothing
			end case;
			
		end if;
	end process main_sm;
	
	--Send data on falling edge.
	process(scl)
		variable current_data : std_logic_vector(D_WIDTH-1 downto 0);
	begin
		if falling_edge(scl) then
			case top_state is
				when SM_SEND_ACK =>
					sda_wen_buf <= '1';
					
				when SM_SEND =>
						if send_ctr = D_WIDTH+1 then
							sda_wen_buf <= '0'; -- Stop transmit for ACK
							send_ctr <= 1; --Set to 1 to make indexing nice
						else
							--Check if we are in the read only portion, or the read/write portion of memory
							if check_in_range(reg_addr, no_rw_regs, RW_REG_OFFSET) then
								current_data := rw_regs_buf(to_integer(unsigned(reg_addr(D_WIDTH-2 downto 0))));
							else
								current_data := ro_regs(to_integer(unsigned(reg_addr(D_WIDTH-2 downto 0))));
							end if;
							--Send data MSB first
							sda_wen_buf <= not current_data(D_WIDTH-send_ctr);
							send_ctr <= send_ctr + 1;
						end if;
					
				when others =>
					sda_wen_buf <= '0';
			end case;
		end if;		
	end process;

	
end Behavioral;

