LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

use work.i2c_types.all;
use work.i2c_test_package.all;
 
ENTITY i2c_top_test IS
    Generic ( no_read_regs : integer := 8;
	           no_write_regs : integer := 8;
	           module_addr : STD_LOGIC_VECTOR(SLV_ADDR_WIDTH-1 downto 0) := "0000001");
END i2c_top_test;
 
ARCHITECTURE behavior OF i2c_top_test IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
    COMPONENT i2c_top
    Generic ( no_read_regs : integer := no_read_regs;
	           no_write_regs : integer := no_write_regs;
	           module_addr : STD_LOGIC_VECTOR(SLV_ADDR_WIDTH-1 downto 0) := module_addr);
    PORT(
         sda : IN  std_logic;
			sda_wen : OUT STD_LOGIC;
         scl : IN  std_logic;
         read_regs : in  array8 (0 to no_read_regs-1);
         write_regs : out  array8 (0 to no_write_regs-1)
        );
    END COMPONENT;
    

   --Inputs
   signal scl : std_logic := '1';
   signal read_regs : array8 (0 to no_read_regs-1);

	--BiDirs
   signal sda : std_logic;
	signal sda_wen : std_logic;

 	--Outputs
   signal write_regs : array8 (0 to no_write_regs-1);

BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: i2c_top PORT MAP (
          sda => sda,
			 sda_wen => sda_wen,
          scl => scl,
          read_regs => read_regs,
          write_regs => write_regs
        );
		  
		  
	--Add weak driver to SDA to mimic pullup
	sda <= 'H';
	
	--Drive bus low when slave is driving
	sda <= '0' when sda_wen = '1' else 'Z';

	read_regs <= write_regs; --Feedback output registers to input

   -- Stimulus process
   stim_proc: process
	constant no_writes : integer := 8;
	constant test_write_regs : array8 (0 to no_writes-1) := (X"01", X"02", X"03", X"04", X"F1", X"F2", X"F3", X"F4");
	variable test_read_regs : array8 (0 to no_writes-1);
   begin
		--Stimulus
		sda <= 'H';
		
		WRITE_TO_SLAVE(sda, scl, module_addr, "00000000", test_write_regs );
		
		wait for 10ms;
		
		READ_FROM_SLAVE(sda, scl, module_addr, "00000000", test_read_regs );
		
		--This fails for some reason, not sure why - simulation shows they are equal
		for i  in 0 to test_write_regs'LENGTH-1 loop
			assert to_integer(unsigned(test_write_regs(i))) = to_integer(unsigned(test_read_regs(i))) report "Read register does not match write register" severity failure;
		end loop;

      wait;
   end process;

END;
