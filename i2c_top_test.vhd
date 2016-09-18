LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

use work.i2c_types.all;
 
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
   signal sda : std_logic := '1';
	signal sda_wen : std_logic;

 	--Outputs
   signal write_regs : array8 (0 to no_write_regs-1);
 
   constant scl_period : time := 10 ms;
	
	procedure START_TO_BUS( signal sda : inout std_logic; signal scl : out std_logic) is
	begin
		--As a prequisite, SDA must be 1
		--We are assumed to be right at the start of a clock period, just after the falling edge
		scl <= '1'; --Force SCL to 1. This is because it is assumed to have been left low
		wait for scl_period/4;
		assert sda = '1'  report "SDA not 1 at start" severity failure;
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
	
	procedure DATA_TO_BUS( signal sda : out std_logic; signal scl : inout std_logic; signal sda_wen : in std_logic; constant data : in std_logic_vector(D_WIDTH-1 downto 0)) is
	begin
	
		--As a prequisite, SCL must be 0
		--We are assumed to be right at the start of a clock period, just after the falling edge
		
		-- Send data
		-- MSB first
		for i in D_WIDTH-1 downto 0 loop
			wait for scl_period/4;
			assert scl = '0' report "SCL not 0 at start of data to bus" severity failure;
			sda <= data(i);
			wait for scl_period/4;
			scl <= '1';
			wait for scl_period/2;
			scl <= '0';
		end loop;
		
		-- Check ack
		wait for scl_period/2;
		scl <= '1';
		wait for scl_period/4;
		assert sda_wen = '1' report "Slave did not ack" severity failure;
		wait for scl_period/4;
		scl <= '0';
	end DATA_TO_BUS;
	
	procedure ADDR_TO_BUS( signal sda : out std_logic; signal scl : inout std_logic; signal sda_wen : in std_logic; constant addr : in std_logic_vector(SLV_ADDR_WIDTH-1 downto 0); constant write_mode : in Boolean) is
		variable data : std_logic_vector(D_WIDTH-1 downto 0);
	begin
		if write_mode = true then
			data := addr & '0';
		else
			data := addr & '1';
		end if;
		
		DATA_TO_BUS(sda, scl, sda_wen, data);
	
	
	end procedure ADDR_TO_BUS;
	
	procedure WRITE_TO_SLAVE( signal sda : inout std_logic; signal scl : inout std_logic; signal sda_wen : in std_logic; constant slv_addr : in std_logic_vector(SLV_ADDR_WIDTH-1 downto 0); constant reg_addr : in std_logic_vector(D_WIDTH-1 downto 0); constant data : in array8) is
	begin
      START_TO_BUS(sda,scl);
		ADDR_TO_BUS(sda,scl, sda_wen, slv_addr , true );
		DATA_TO_BUS(sda, scl, sda_wen, reg_addr);
		for i in 0 to data'LENGTH-1 loop
			DATA_TO_BUS(sda, scl, sda_wen, data(i));
		end loop;
		STOP_TO_BUS(sda,scl);
	end procedure WRITE_TO_SLAVE;
	
	procedure DATA_FROM_BUS( signal sda : inout std_logic; signal scl : inout std_logic; signal sda_wen : in std_logic; variable data : out std_logic_vector(D_WIDTH-1 downto 0); constant ack : in boolean) is
	begin
	
		--As a prequisite, SCL must be 0, SDA must be 1
		--We are assumed to be right at the start of a clock period, just after the falling edge
		
		-- Receive data
		-- MSB first
		for i in D_WIDTH-1 downto 0 loop
			wait for scl_period/4;
			assert scl = '0' report "SCL not 0 at start of data from bus" severity failure;
			assert sda = '1' report "SDA not 1 at start of data from bus" severity failure;
			wait for scl_period/4;
			scl <= '1';
			wait for scl_period/4;
			data(i) := not sda_wen; -- Inverse because sda_wen tells us when to drive the line
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
		sda <= '1';
		scl <= '0';
	end DATA_FROM_BUS;
	
	procedure READ_FROM_SLAVE( signal sda : inout std_logic; signal scl : inout std_logic; signal sda_wen : in std_logic; constant slv_addr : in std_logic_vector(SLV_ADDR_WIDTH-1 downto 0); constant reg_addr : in std_logic_vector(D_WIDTH-1 downto 0); variable data : out array8) is
	begin
      START_TO_BUS(sda,scl);
		ADDR_TO_BUS(sda,scl, sda_wen, slv_addr , true );
		DATA_TO_BUS(sda, scl, sda_wen, reg_addr);
      START_TO_BUS(sda,scl);
		ADDR_TO_BUS(sda,scl, sda_wen, slv_addr , false );
		for i in 0 to data'LENGTH-1 loop
			if i = data'LENGTH-1 then
				DATA_FROM_BUS(sda, scl, sda_wen, data(i),false);
			else
				DATA_FROM_BUS(sda, scl, sda_wen, data(i),true);
			end if;
		end loop;
		STOP_TO_BUS(sda,scl);
	end procedure READ_FROM_SLAVE;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: i2c_top PORT MAP (
          sda => sda,
			 sda_wen => sda_wen,
          scl => scl,
          read_regs => read_regs,
          write_regs => write_regs
        );

	read_regs <= write_regs; --Feedback registers

   -- Stimulus process
   stim_proc: process
	constant no_writes : integer := 8;
	constant test_write_regs : array8 (0 to no_writes-1) := (X"01", X"02", X"03", X"04", X"F1", X"F2", X"F3", X"F4");
	variable test_read_regs : array8 (0 to no_writes-1);
   begin
		--Stimulus

		WRITE_TO_SLAVE(sda, scl, sda_wen, module_addr, "00000000", test_write_regs );
		
		wait for 10ms;
		
		READ_FROM_SLAVE(sda, scl, sda_wen, module_addr, "00000000", test_read_regs );
		
		assert test_write_regs = test_read_regs report "Read registers does not match write registers" severity failure;

      wait;
   end process;

END;
