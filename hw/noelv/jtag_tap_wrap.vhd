library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tap_gen is
    generic (
        irlen  : integer range 2 to 8 := 5;
        idcode : integer range 0 to 255 := 9;
        manf   : integer range 0 to 2047 := 804;
        part   : integer range 0 to 65535 := 0;
        ver    : integer range 0 to 15 := 0;
        trsten : integer range 0 to 1 := 1;    
        scantest : integer := 0;
        oepol  : integer := 1
    );
    port (
        trst        : in std_ulogic;
        tckp        : in std_ulogic;
        tckn        : in std_ulogic;
        tms         : in std_ulogic;
        tdi         : in std_ulogic;
        tdo         : out std_ulogic;
        tapi_en1    : in std_ulogic;
        tapi_tdo1   : in std_ulogic;
        tapi_tdo2   : in std_ulogic;
        tapo_tck    : out std_ulogic;
        tapo_tdi    : out std_ulogic;
        tapo_inst   : out std_logic_vector(7 downto 0);
        tapo_rst    : out std_ulogic;
        tapo_capt   : out std_ulogic;
        tapo_shft   : out std_ulogic;
        tapo_upd    : out std_ulogic;
        tapo_xsel1  : out std_ulogic;
        tapo_xsel2  : out std_ulogic;
        tapo_ninst  : out std_logic_vector(7 downto 0);
        tapo_iupd   : out std_ulogic;
        testen      : in std_ulogic := '0';
        testrst     : in std_ulogic := '1';
        testoen     : in std_ulogic := '0';
        tdoen       : out std_ulogic
    );
end;

architecture rtl of tap_gen is

    component dmi_jtag_tap
        generic (
            IrLength : integer := 5;
            IdcodeValue : std_logic_vector(31 downto 0) := (others => '0')
        );
        port (
            tck_i : in  std_logic;
            tms_i : in  std_logic;
            trst_ni : in  std_logic;
            td_i : in  std_logic;
            td_o : out  std_logic;
            tdo_oe_o : out  std_logic;
            testmode_i : in  std_logic;
            tck_o : out  std_logic;
            dmi_clear_o : out  std_logic;
            update_o : out  std_logic;
            capture_o : out  std_logic;
            shift_o : out  std_logic;
            tdi_o : out  std_logic;
            dtmcs_select_o : out  std_logic;
            dtmcs_tdo_i : in  std_logic;
            dmi_select_o : out  std_logic;
            dmi_tdo_i : in  std_logic
        );
    end component;
 
    signal dmi_select, dtmcs_select : std_ulogic;

begin

    dmi_jtag_tap_i : dmi_jtag_tap
    generic map(
        IrLength      => 5,
        IdcodeValue   => std_logic_vector(to_unsigned(ver,4)) & std_logic_vector(to_unsigned(part,16)) & std_logic_vector(to_unsigned(manf,11)) & '1'
    )
    port map(
        tck_i          => tckp,
        tms_i          => tms,
        trst_ni        => trst,
        td_i           => tdi,
        td_o           => tdo,
        tdo_oe_o       => tdoen,
        testmode_i     => testen,
        tck_o          => tapo_tck,
        dmi_clear_o    => tapo_rst,
        update_o       => tapo_upd,
        capture_o      => tapo_capt,
        shift_o        => tapo_shft,
        tdi_o          => tapo_tdi,
        dtmcs_select_o => dtmcs_select,
        dtmcs_tdo_i    => tapi_tdo1,
        dmi_select_o   => dmi_select,
        dmi_tdo_i      => tapi_tdo1
    );

    tapo_xsel2 <= dmi_select;
    tapo_xsel1 <= dtmcs_select;

    tapo_inst <= "00010001" when (dmi_select = '1') else "00010000" when (dtmcs_select = '1') else "00000000";
    tapo_ninst <= (others => '0');
    tapo_iupd <= '0';

end;


