library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.i2c_types.all;

entity i2c_top is
    Generic ( no_read_regs : integer;
	           no_write_regs : integer;
	           module_addr : STD_LOGIC_VECTOR(SLV_ADDR_WIDTH-1 downto 0));
    Port ( sda : in  STD_LOGIC;
           sda_wen : out STD_LOGIC := '0'; --Init to 0 to not drive line
           scl : in  STD_LOGIC;
           read_regs : in  array8 (0 to no_read_regs-1);
           write_regs : out  array8 (0 to no_write_regs-1));
end i2c_top;

architecture Behavioral of i2c_top is
	
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
	signal bit_ctr : integer range 0 to D_WIDTH-1;
	
	signal start_condition : std_logic := '0'; -- Pulses when start condition detected, init to none
	signal stop_condition : std_logic := '0'; -- Pulses when stop condition detected, init to none
	
	type status_type is (ST_STOPPED, ST_STARTED);
	signal status : status_type := ST_STOPPED; -- Init to stopped
--
begin

	-- Detect start condition
	detect_start : process(sda)
	begin
	
		if falling_edge(sda) then
			if scl = '1' then
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
			if scl = '1' then
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
			bit_ctr <= 0;
		elsif rising_edge(scl) and status = ST_STARTED then -- Proceed on errors, so that we can output them!
			sda_wen <= '0';
			case top_state is
				--Receive module address
				when SM_RECEIVE =>
					--If we have received the entire word
					if bit_ctr = D_WIDTH-1 then
						top_state <= SM_SEND_ACK; -- May be overwritten later
						bit_ctr <= 0;
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
								-- TODO: ADD RANGE CHECKING
								write_regs(to_integer(unsigned(reg_addr))) <= data(D_WIDTH-2 downto 0) & sda;
								reg_addr <= std_logic_vector(unsigned(reg_addr) + 1);
						end case;
					else
						-- Shift left, as MSB first
						data <= data(D_WIDTH-2 downto 0) & sda;
						bit_ctr <= bit_ctr + 1;
					end if;
					
				when SM_SEND_ACK =>
					sda_wen <= '1';
					if mode = MD_RECEIVE then
						top_state <= SM_RECEIVE;
					else
						top_state <= SM_SEND;
					end if;
					
				when SM_RECEIVE_ACK =>
					if sda = '0' then
						--Master ACK
						top_state <= SM_SEND;
					else
						--Master NACK
						top_state <= SM_WAIT;
					end if;
				
				
				when SM_SEND =>
					-- TODO: FILL IN
					
				when SM_WAIT=>
					-- Do nothing. We will reset on next start condition
				when others =>
					-- This should never happen!
					-- Do nothing
			end case;
			
		end if;
	end process main_sm;

end Behavioral;

