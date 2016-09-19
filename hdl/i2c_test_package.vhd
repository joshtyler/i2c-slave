library IEEE;
use IEEE.STD_LOGIC_1164.all;

use work.i2c_package.all;

package i2c_test_package is


	-- Declare constants
	constant scl_period : time := 10 ms;

	-- Declare functions and procedure
	-- Only make 'top level' functions visible
	procedure READ_FROM_SLAVE( signal sda : inout std_logic; signal scl : inout std_logic; constant slv_addr : in std_logic_vector(SLV_ADDR_WIDTH-1 downto 0); constant reg_addr : in std_logic_vector(D_WIDTH-1 downto 0); variable data : out array8);
	procedure WRITE_TO_SLAVE( signal sda : inout std_logic; signal scl : inout std_logic; constant slv_addr : in std_logic_vector(SLV_ADDR_WIDTH-1 downto 0); constant reg_addr : in std_logic_vector(D_WIDTH-1 downto 0); constant data : in array8);


end i2c_test_package;

package body i2c_test_package is

	
	procedure START_TO_BUS( signal sda : inout std_logic; signal scl : out std_logic) is
	begin
	
		--We are assumed to be right at the start of a clock period, just after the falling edge (repeated start)
		--Or right at the start of the whole thing (normal start)
		wait for scl_period/2;
		scl <= '1'; --Force SCL to 1. This is because it is assumed to have been left low
		wait for scl_period/2;
		assert sda = '1' or sda = 'H'  report "SDA not 1 at start" severity failure;
		sda <= '0';
		wait for scl_period/4;
		scl <= '0';
		wait for scl_period/2;
	end START_TO_BUS;
	
	procedure STOP_TO_BUS( signal sda : out std_logic; signal scl : inout std_logic) is
	begin
		--As a prequisite, SCL must be 0
		--We are assumed to be right at the start of a clock period, just after the falling edge
		sda <= '0';
		wait for scl_period/4;
		assert scl = '0' report "SCL not 0 at stop" severity failure;
		scl <= '1';
		wait for scl_period/4;
		sda <= '1';
		wait for scl_period/2;
	end STOP_TO_BUS;
	
	procedure DATA_TO_BUS( signal sda : inout std_logic; signal scl : inout std_logic; constant data : in std_logic_vector(D_WIDTH-1 downto 0)) is
	begin
		--As a prequisite, SCL must be 0
		--We are assumed to be right at the start of a clock period, just after the falling edge
		
		-- Send data
		-- MSB first
		for i in D_WIDTH-1 downto 0 loop
			sda <= data(i);
			wait for scl_period/4;
			assert scl = '0' report "SCL not 0 at start of data to bus" severity failure;
			wait for scl_period/4;
			scl <= '1';
			wait for scl_period/2;
			scl <= '0';
		end loop;
		
		sda <= 'Z'; -- Leave bus as high impedance
		
		-- Check ack
		wait for scl_period/2;
		scl <= '1';
		wait for scl_period/4;
		assert sda = '0' report "Slave did not ack" severity failure;
		wait for scl_period/4;
		scl <= '0';
	end DATA_TO_BUS;
	
	procedure ADDR_TO_BUS( signal sda : inout std_logic; signal scl : inout std_logic; constant addr : in std_logic_vector(SLV_ADDR_WIDTH-1 downto 0); constant write_mode : in Boolean) is
		variable data : std_logic_vector(D_WIDTH-1 downto 0);
	begin
		if write_mode = true then
			data := addr & '0';
		else
			data := addr & '1';
		end if;
		
		DATA_TO_BUS(sda, scl, data);
	
	
	end procedure ADDR_TO_BUS;
	
	procedure WRITE_TO_SLAVE( signal sda : inout std_logic; signal scl : inout std_logic; constant slv_addr : in std_logic_vector(SLV_ADDR_WIDTH-1 downto 0); constant reg_addr : in std_logic_vector(D_WIDTH-1 downto 0); constant data : in array8) is
	begin
      START_TO_BUS(sda,scl);
		ADDR_TO_BUS(sda, scl, slv_addr , true );
		DATA_TO_BUS(sda, scl, reg_addr);
		for i in 0 to data'LENGTH-1 loop
			DATA_TO_BUS(sda, scl, data(i));
		end loop;
		STOP_TO_BUS(sda,scl);
	end procedure WRITE_TO_SLAVE;
	
	procedure DATA_FROM_BUS( signal sda : inout std_logic; signal scl : inout std_logic; variable data : out std_logic_vector(D_WIDTH-1 downto 0); constant ack : in boolean) is
	begin
	
		--As a prequisite, SCL must be 0
		--We are assumed to be right at the start of a clock period, just after the falling edge
		
		-- Receive data
		-- MSB first
		for i in D_WIDTH-1 downto 0 loop
			wait for scl_period/4;
			assert scl = '0' report "SCL not 0 at start of data from bus" severity failure;
			wait for scl_period/4;
			scl <= '1';
			wait for scl_period/4;
			data(i) := sda;
			wait for scl_period/4;
			scl <= '0';
		end loop;
		
		-- Give ack
		wait for scl_period/4;
		if ack then
			sda <= '0';
		end if;
		wait for scl_period/4;
		scl <= '1';
		wait for scl_period/2;
		sda <= 'Z';
		scl <= '0';
	end DATA_FROM_BUS;
	
	procedure READ_FROM_SLAVE( signal sda : inout std_logic; signal scl : inout std_logic; constant slv_addr : in std_logic_vector(SLV_ADDR_WIDTH-1 downto 0); constant reg_addr : in std_logic_vector(D_WIDTH-1 downto 0); variable data : out array8) is
	begin
      START_TO_BUS(sda,scl);
		ADDR_TO_BUS(sda,scl, slv_addr , true );
		DATA_TO_BUS(sda, scl, reg_addr);
      START_TO_BUS(sda,scl);
		ADDR_TO_BUS(sda,scl, slv_addr , false );
		for i in 0 to data'LENGTH-1 loop
			if i = data'LENGTH-1 then
				DATA_FROM_BUS(sda, scl, data(i),false);
			else
				DATA_FROM_BUS(sda, scl, data(i),true);
			end if;
		end loop;
		STOP_TO_BUS(sda,scl);
	end procedure READ_FROM_SLAVE;
 
end i2c_test_package;
