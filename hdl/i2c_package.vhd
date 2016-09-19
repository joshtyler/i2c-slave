library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.ALL;

package i2c_types is

	--Constants
	constant SLV_ADDR_WIDTH : integer := 7; -- Code would need to be modified to implement 10 bit.
	constant D_WIDTH : integer := 8; -- Width of I2C registers
	
	--NOTE. THESE OFFSETS CANNOT BE CHANGED WIHTOUT FURTHER MODIFICATION TO THE CODE
	--This is due to taking advantage of efficiencies due to the transition being at 0x80
	constant WRITE_REG_OFFSET : std_logic_vector(D_WIDTH-1 downto 0) := B"0000_0000"; --Read/write register offset
	constant READ_REG_OFFSET : std_logic_vector(D_WIDTH-1 downto 0) := B"1000_0000"; --Read only register offset

	--Types
	type array8 is array (natural range <>) of std_logic_vector(D_WIDTH-1 downto 0); --Store registers
	
	--Functions
	-- Check if an address is in the allowable range for the number of registers
	-- This function could be written unbounded, however bonds are given to ensure we don't synthesize 32 bit registers!
	function check_in_range(address : std_logic_vector(D_WIDTH-1 downto 0); num_regs : integer range 0 to (2**D_WIDTH); offset : std_logic_vector(D_WIDTH-1 downto 0)) return boolean;

end i2c_types;

package body i2c_types is


	function check_in_range(address : std_logic_vector(D_WIDTH-1 downto 0); num_regs : integer range 0 to (2**D_WIDTH); offset : std_logic_vector(D_WIDTH-1 downto 0)) return boolean is
	begin
		-- If the address given is greater than the highest existing address 
		if to_integer(unsigned(address)) > (to_integer(unsigned(offset)) + num_regs - 1) then
			--Out of range
			return false;
		else
			--In range
			return true;
		end if;
	
	end check_in_range;

end i2c_types;