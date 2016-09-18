library IEEE;
use IEEE.STD_LOGIC_1164.all;

package i2c_types is

	constant SLV_ADDR_WIDTH : integer := 7; -- Code would need to be modified to implement 10 bit.
	constant D_WIDTH : integer := 8; -- Width of I2C registers
	constant D_WIDTH_ONES : std_logic_vector(D_WIDTH-1 downto 0) := (others => '1'); -- Used for comparisons
	type array8 is array (natural range <>) of std_logic_vector(D_WIDTH-1 downto 0);
--	type i2c_error_type is (I2C_ERR_NONE, I2C_ERR_OTHER);

end i2c_types;

