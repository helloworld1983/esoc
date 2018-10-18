--------------------------------------------------------------------------------
--
-- This VHDL file was generated by EASE/HDL 7.4 Revision 4 from HDL Works B.V.
--
-- Ease library  : work
-- HDL library   : work
-- Host name     : S212065
-- User name     : df768
-- Time stamp    : Tue Aug 19 08:05:18 2014
--
-- Designed by   : L.Maarsen
-- Company       : LogiXA
-- Project info  : eSoC
--
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Object        : Entity work.esoc_control
-- Last modified : Thu Apr 17 12:55:38 2014.
--------------------------------------------------------------------------------



library ieee, std, work;
use ieee.std_logic_1164.all;
use std.textio.all;
use ieee.numeric_std.all;
use work.package_esoc_configuration.all;

entity esoc_control is
  port(
    brom_address       : out    std_logic_vector(10 downto 0);
    brom_rd            : out    std_logic;
    brom_rddata        : in     std_logic_vector(31 downto 0);
    clk_control        : in     std_logic;
    ctrl_address       : out    std_logic_vector(15 downto 0);
    ctrl_rd            : out    std_logic;
    ctrl_rddata        : in     std_logic_vector(31 downto 0);
    ctrl_wait          : in     std_logic;
    ctrl_wr            : out    std_logic;
    ctrl_wrdata        : out    std_logic_vector(31 downto 0);
    esoc_address       : in     std_logic_vector(15 downto 0);
    esoc_boot_complete : out    std_logic;
    esoc_cs            : in     std_logic;
    esoc_data          : inout  std_logic_vector(31 downto 0);
    esoc_rd            : in     std_logic;
    esoc_wait          : out    std_logic;
    esoc_wr            : in     std_logic;
    pll1_locked        : in     STD_LOGIC;
    pll2_locked        : in     STD_LOGIC;
    reset              : in     std_logic);
end entity esoc_control;

--------------------------------------------------------------------------------
-- Object        : Architecture work.esoc_control.esoc_control
-- Last modified : Thu Apr 17 12:55:38 2014.
--------------------------------------------------------------------------------


---------------------------------------------------------------------------------------------------------------
-- architecture and declarations
---------------------------------------------------------------------------------------------------------------
architecture esoc_control of esoc_control is

---------------------------------------------------------------------------------------------------------------
-- registers
---------------------------------------------------------------------------------------------------------------
-- register and bit definitions
constant reg_ctrl_id_add       : integer                         := 0;

constant reg_ctrl_version_add  : integer                         := 1;

constant reg_ctrl_stat_ctrl_add   : integer                      := 2;

constant reg_ctrl_scratch_add  : integer                         := 3;
signal   reg_ctrl_scratch_dat  : std_logic_vector(31 downto 0);
constant reg_ctrl_scratch_rst  : std_logic_vector(31 downto 0)   := X"00000000";

---------------------------------------------------------------------------------------------------------------
-- signals
---------------------------------------------------------------------------------------------------------------
type ctrl_bus_states is (boot, boot_wait, boot_rd_add, boot_rd_dat, operational);
signal ctrl_bus_state: ctrl_bus_states;

signal esoc_rd_sync: std_logic_vector(2 downto 0);
signal esoc_wr_sync: std_logic_vector(2 downto 0);

signal ctrl_rd_i: std_logic;
signal ctrl_wr_i: std_logic;
signal ctrl_rdwr_i: std_logic;
signal ctrl_rddata_i: std_logic_vector(31 downto 0);
signal ctrl_wrdata_i: std_logic_vector(31 downto 0);
signal ctrl_address_i: std_logic_vector(ctrl_address'high downto 0);
signal ctrl_wait_i: std_logic;

constant brom_wait_count_init: integer := 31;
signal brom_wait_count: integer range brom_wait_count_init downto 0;
signal brom_address_count: integer range 2**brom_address'length-1 downto 0;
signal brom_error: std_logic;
             
signal pll1_locked_sync: std_logic_vector(esoc_meta_ffs-1 downto 0);
signal pll2_locked_sync: std_logic_vector(esoc_meta_ffs-1 downto 0);

begin

--=============================================================================================================
-- Process		  : synchronise asynchronous control inputs
-- Description	: 
--=============================================================================================================
sync:   process(clk_control, reset)
        begin
          if reset = '1' then
            esoc_rd_sync <= (others => '0');
            esoc_wr_sync <= (others => '0');
            
            pll1_locked_sync <= (others => '0');
            pll2_locked_sync <= (others => '0');
          
          elsif clk_control'event and clk_control = '1' then
            esoc_rd_sync <= (esoc_cs and esoc_rd) & esoc_rd_sync(esoc_rd_sync'high downto 1);
            esoc_wr_sync <= (esoc_cs and esoc_wr) & esoc_wr_sync(esoc_wr_sync'high downto 1);
            
            pll1_locked_sync <= pll1_locked & pll1_locked_sync(pll1_locked_sync'high downto 1);
            pll2_locked_sync <= pll2_locked & pll2_locked_sync(pll2_locked_sync'high downto 1);
          end if;
        end process;
          
--=============================================================================================================
-- Process		  : control internal bus with external bus signal
-- Description	: 
--=============================================================================================================       
ctrlbus:  process(clk_control, reset)
          begin
            if reset = '1' then
              ctrl_rd_i          <= '0';
              ctrl_wr_i          <= '0';
              ctrl_rdwr_i        <= '0';
              ctrl_address_i     <= (others => '0');
              ctrl_wrdata_i      <= (others => '0');
              ctrl_bus_state     <= boot;
              
              brom_rd            <= '0';
              brom_address       <= (others => '0');
              brom_address_count <= 0;
              brom_wait_count    <= 0;
              
              brom_error         <= '0';
              esoc_boot_complete <= '0';
            
            elsif clk_control'event and clk_control = '1' then
              
              case ctrl_bus_state is
                when boot         =>  -- boot from rom disabled, start read from boot rom
                                      if esoc_brom_mode = enabled then
                                        brom_rd            <= '1';
                                        brom_address       <= std_logic_vector(to_unsigned(brom_address_count,brom_address'length));
                                        brom_address_count <= brom_address_count + 1;
                                        ctrl_bus_state     <= boot_wait;                                      
                                        
                                      -- boot from rom disabled, step to operational state immediately
                                      else
                                        esoc_boot_complete <= '1';
                                        ctrl_bus_state     <= operational; 
                                      end if;

                when boot_wait    =>  -- wait for word from boot rom (the register address), continu read from boot prom
                                      brom_rd             <= '1';
                                      brom_address      <= std_logic_vector(to_unsigned(brom_address_count,brom_address'length));
                                      brom_address_count <= brom_address_count + 1;
                                      ctrl_bus_state      <= boot_rd_add;
                
                when boot_rd_add  =>  -- evaluate word from boot rom (the register address) and wait for word from boot rom (the register content)
                                      brom_rd <= '0';
                                      
                                      -- stop reading from boot rom if all ones is returned
                                      if brom_rddata = X"FFFFFFFF" then
                                        brom_error         <= '0';
                                        esoc_boot_complete <= '1';
                                        ctrl_bus_state     <= operational;    
                                      
                                      -- prepare write on internal bus by providing the address, init wait counter for dead lock detection
                                      else
                                        brom_wait_count   <= brom_wait_count_init;
                                        ctrl_address_i    <= brom_rddata(ctrl_address_i'high downto 0);
                                        ctrl_bus_state    <= boot_rd_dat;
                                      end if;
                
                when boot_rd_dat  =>  -- word from boot rom (the register content) available, start write cycle on internal bus and wait for ACK
                                      ctrl_wr_i           <= '1';
                                      ctrl_rdwr_i         <= '1';
                                      ctrl_wrdata_i       <= brom_rddata;
                                      
                                      -- wait for acknowledge, start counter to avoid dead lock due to wrong ROM content
                                      if ctrl_wait = '0' or ctrl_wait_i = '0' then
                                        ctrl_wr_i          <= '0';
                                        ctrl_bus_state     <= boot;    
                                      
                                      -- write cycle time out? Terminate boot initialisation!  
                                      elsif brom_wait_count = 0 then
                                        brom_error         <= '1';
                                        esoc_boot_complete <= '1';
                                        ctrl_wr_i          <= '0';
                                        ctrl_bus_state     <= operational;    
                                        
                                      -- count down  
                                      else
                                        brom_wait_count <= brom_wait_count - 1;
                                      end if;
                                      
                when operational  =>  -- detect rising edge of synchronized read signal, check address and drive internal signals of control bus
                                      if esoc_rd_sync(esoc_rd_sync'low+1 downto 0) = "10"  and to_integer(unsigned(esoc_address)) >= esoc_base and to_integer(unsigned(esoc_address)) < esoc_base + esoc_size then
                                        ctrl_rd_i <= '1';
                                        ctrl_rdwr_i <= '0'; 
                                        ctrl_address_i <= esoc_address;
                                      
                                      -- detect rising edge of synchronized write signal, check address and drive internal signals of control bus
                                      elsif esoc_wr_sync(esoc_wr_sync'low+1 downto 0) = "10" and to_integer(unsigned(esoc_address)) >= esoc_base and to_integer(unsigned(esoc_address)) < esoc_base + esoc_size then
                                        ctrl_wr_i <= '1';
                                        ctrl_rdwr_i <= '1'; 
                                        ctrl_wrdata_i <= esoc_data;
                                        ctrl_address_i  <= esoc_address;
                                      
                                      -- reset internal signals read/write after acknowledge from addresses unit (ack = inactive wait)
                                      elsif ctrl_wait = '0' or ctrl_wait_i = '0'  then
                                        ctrl_rd_i <= '0';
                                        ctrl_wr_i <= '0';
                                      end if;
                
                when others =>        ctrl_bus_state <= boot;
              end case;
            end if;
          end process;
          
          -- use eSOC control interface inputs to drive eSOC control bus signals after initialisation by boot rom
          ctrl_rd       <= ctrl_rd_i;
          ctrl_wr       <= ctrl_wr_i;
          ctrl_address  <= ctrl_address_i;
          ctrl_wrdata   <= ctrl_wrdata_i;
          
          -- use eSOC control bus signals to drive eSOC control interface outputs
          esoc_data   <= ctrl_rddata 	  when ctrl_wait   = '0' and ctrl_rdwr_i = '0'  else 
                         ctrl_rddata_i  when ctrl_wait_i = '0' and ctrl_rdwr_i = '0'  else (others => 'Z');
                         
          esoc_wait 	<= '0' 					  when ctrl_wait   = '0' or  ctrl_wait_i = '0'   else 'Z';

                 
--=============================================================================================================
-- Process		  : access registers of control unit itself
-- Description	: 
--=============================================================================================================    
registers:  process(clk_control, reset)
            begin
              if reset = '1' then
                reg_ctrl_scratch_dat <= reg_ctrl_scratch_rst;
                ctrl_wait_i <= '1';
                ctrl_rddata_i <= (others => '0');
                              
              elsif clk_control'event and clk_control = '1' then
              	ctrl_wait_i <= '1';
                
                -- continu if memory space of this entity is addressed
                if to_integer(unsigned(ctrl_address_i)) >= esoc_control_base and to_integer(unsigned(ctrl_address_i)) < esoc_control_base + esoc_control_size then
	                --
	                -- READ CYCLE started, unit addressed?
	                --
	                if ctrl_rd_i = '1' then
	                	-- Check register address and provide data when addressed
	                  case to_integer(unsigned(ctrl_address_i))- esoc_control_base is
	                    when reg_ctrl_id_add        =>  ctrl_rddata_i <= esoc_id;
	                                                    ctrl_wait_i <= '0';
	                    
	                    when reg_ctrl_version_add   =>  ctrl_rddata_i <= std_logic_vector(to_unsigned(esoc_version,16)) & std_logic_vector(to_unsigned(esoc_release,16));
	                                                    ctrl_wait_i <= '0';
	                    
	                    when reg_ctrl_stat_ctrl_add =>  if esoc_brom_mode = enabled then
	                                                      ctrl_rddata_i <= pll2_locked_sync(0) & pll1_locked_sync(0) & brom_error & '1' & X"000000" & std_logic_vector(to_unsigned(esoc_port_count,4));
	                                                    else
	                                                      ctrl_rddata_i <= pll2_locked_sync(0) & pll1_locked_sync(0) & brom_error & '0' & X"000000" & std_logic_vector(to_unsigned(esoc_port_count,4));
	                                                    end if;
	                                                    
	                                                    ctrl_wait_i <= '0';
                      
                      when reg_ctrl_scratch_add   =>  ctrl_rddata_i <= reg_ctrl_scratch_dat;
	                                                    ctrl_wait_i <= '0';
	                    
	                    when others                 =>  NULL;
	                  end case;
                    
	                --
	                -- WRITE CYCLE started, unit addressed?  
	                --
	                elsif ctrl_wr_i = '1' then
	                	-- Check register address and accept data when addressed
	                	case to_integer(unsigned(ctrl_address_i)) - esoc_control_base is
	                    when reg_ctrl_scratch_add  =>   reg_ctrl_scratch_dat <= ctrl_wrdata_i;
	                                                    ctrl_wait_i <= '0';        
                      when others                =>   NULL;
	                  end case;
	  							end if;
	  					  end if;
              end if;
            end process; 
end architecture esoc_control ; -- of esoc_control

