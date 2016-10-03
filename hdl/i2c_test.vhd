LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

use work.i2c_package.all;
use work.i2c_test_package.all;
 
ENTITY i2c_test IS
    Generic ( no_ro_regs : integer := 8;
	           no_rw_regs : integer := 8;
	           module_addr : STD_LOGIC_VECTOR(SLV_ADDR_WIDTH-1 downto 0) := "0000001");
END i2c_test;
 
ARCHITECTURE behavior OF i2c_test IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
    COMPONENT i2c
    Generic ( no_ro_regs : integer := no_ro_regs;
	           no_rw_regs : integer := no_rw_regs;
	           module_addr : STD_LOGIC_VECTOR(SLV_ADDR_WIDTH-1 downto 0) := module_addr);
    PORT(
         sda : IN  std_logic;
			sda_wen : OUT STD_LOGIC;
         scl : IN  std_logic;
         ro_regs : in  array8 (0 to no_ro_regs-1);
         rw_regs : out  array8 (0 to no_rw_regs-1)
        );
    END COMPONENT;
    

   --Inputs
   signal scl : std_logic := '1';
   signal ro_regs : array8 (0 to no_ro_regs-1);

	--BiDirs
   signal sda : std_logic;
	signal sda_wen : std_logic;

 	--Outputs
   signal rw_regs : array8 (0 to no_rw_regs-1);
	
	--Constants
	constant test_ro_regs : array8 (0 to no_ro_regs-1) := (X"FF", X"00", X"AB", X"CD", X"DE", X"AD", X"BE", X"EF");

BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: i2c PORT MAP (
          sda => sda,
			 sda_wen => sda_wen,
          scl => scl,
          ro_regs => ro_regs,
          rw_regs => rw_regs
        );
		  
		  
	--Add weak driver to SDA to mimic pullup
	sda <= 'H';
	
	--Drive bus low when slave is driving
	sda <= '0' when sda_wen = '1' else 'Z';

	ro_regs <= test_ro_regs; --Connect RO regs to test data

   -- Stimulus process
   stim_proc: process
	constant no_writes : integer := 8;
	constant test_write_regs : array8 (0 to no_rw_regs-1) := (X"01", X"02", X"03", X"04", X"F1", X"F2", X"F3", X"F4");
	variable test_read_regs : array8 (0 to no_rw_regs-1);
	variable current_addr : std_logic_vector(SLV_ADDR_WIDTH-1 downto 0);
   begin
		--Stimulus
		
		sda <= 'H'; -- Not sure why we need to drive weak high hear also, but seems to be needed for iSim
		
		--Test acknowledgement to slave addresses in read mode
		for i in 0 to (2**SLV_ADDR_WIDTH-1) loop
			current_addr := std_logic_vector(to_unsigned(i,SLV_ADDR_WIDTH));
			if current_addr = module_addr then
				--Expect ack
				ADDRESS_SLAVE(sda, scl, current_addr, true, true);
			else
				--Expect no ack
				ADDRESS_SLAVE(sda, scl, current_addr, true, false);
			end if;

		end loop;
		report "Acknowledgement test completed";
		wait for 10ms;
		
		-- Test writing registers
		WRITE_TO_SLAVE(sda, scl, module_addr, "00000000", test_write_regs, true );
		wait for 10ms;
		report "Writing test completed";
		
		--Test reading RW registers
		READ_FROM_SLAVE(sda, scl, module_addr, "00000000", test_read_regs, true );
		
		for i  in 0 to test_write_regs'LENGTH-1 loop
			assert to_integer(unsigned(test_read_regs(i))) = to_integer(unsigned(test_write_regs(i))) report "Read register does not match write register" severity failure;
		end loop;
		wait for 10ms;
		report "Reading RW Regs test completed";
		
		--Test reading RO registers
		READ_FROM_SLAVE(sda, scl, module_addr, "10000000", test_read_regs, true );
		for i  in 0 to test_write_regs'LENGTH-1 loop
			assert to_integer(unsigned(test_read_regs(i))) = to_integer(unsigned(test_ro_regs(i))) report "Read register does not match write register" severity failure;
		end loop;
		report "Reading RO Regs test completed";

		--Test writing invalid register
		WRITE_TO_SLAVE(sda, scl, module_addr, "01110101", test_write_regs, false ); --Should fail as only 8 RW regs
		WRITE_TO_SLAVE(sda, scl, module_addr, "11110101", test_write_regs, false ); --Should fail as only 8 RO regs
		wait for 10ms;
		report "Invalid writing test completed";

		--Test read invalid register
		READ_FROM_SLAVE(sda, scl, module_addr, "01110101", test_read_regs, false ); --Should fail as only 8 RW regs
		READ_FROM_SLAVE(sda, scl, module_addr, "11110101", test_read_regs, false ); --Should fail as only 8 RO regs
		wait for 10ms;
		report "Invalid reading test completed";

		report "Testing completed without fatal errors";
		
      wait;
   end process;

END;
