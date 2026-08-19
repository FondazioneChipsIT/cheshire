library ieee;
use ieee.std_logic_1164.all;

entity gf22fdx_syncram is
  generic ( abits : integer := 10; dbits : integer := 8 );
  port (
    clk        : in std_ulogic;
    address    : in std_logic_vector(abits -1 downto 0);
    datain     : in std_logic_vector(dbits -1 downto 0);
    dataout    : out std_logic_vector(dbits -1 downto 0);
    enable     : in std_ulogic;
    wr         : in std_ulogic;
    tBist      : in std_ulogic;
    tLogic     : in std_ulogic;
    tStab      : in std_ulogic;
    tWbt       : in std_ulogic;
    resetFuse  : in std_ulogic;
    s1d_ma     : in std_logic_vector(7 downto 0);
    ch_bus_s1d : in std_logic_vector(11 downto 0);
    tck        : in std_ulogic;
    eh_bus_s1d : in std_logic_vector(25 downto 0);
    eh_diagSel : in std_logic_vector(3 downto 0);
    eh_memEn   : in std_logic_vector(3 downto 0);
    he_status  : out std_logic_vector(3 downto 0);
    he_data    : out std_logic_vector(3 downto 0);
    mempres    : out std_logic_vector(3 downto 0);
    fShift     : in std_ulogic;
    fDataIn    : in std_ulogic;
    fBypass    : in std_ulogic;
    fEnable    : in std_ulogic;
    fDataOut   : out std_ulogic
  );
end;

architecture rtl of gf22fdx_syncram is

  component RM_IHPSG13_1P_512x32_c2_bm_bist is
  port (
  A_DOUT      : out std_logic_vector(31 downto 0);
	A_ADDR      : in  std_logic_vector(8 downto 0);
	A_DIN       : in  std_logic_vector(31 downto 0);
	A_BM        : in  std_logic_vector(31 downto 0);
	A_WEN       : in  std_logic;
	A_MEN       : in  std_logic;
	A_CLK       : in  std_logic;
  A_REN       : in  std_logic;
  A_BIST_DIN  : in  std_logic_vector(31 downto 0);
  A_BIST_BM   : in  std_logic_vector(31 downto 0);
  A_BIST_ADDR : in  std_logic_vector(8 downto 0);
  A_BIST_MEN  : in  std_logic;
  A_BIST_REN  : in  std_logic;
  A_BIST_WEN  : in  std_logic;
  A_BIST_CLK  : in  std_logic;
  A_BIST_EN   : in  std_logic;
  A_DLY       : in  std_logic
       );
  end component;

  component RM_IHPSG13_1P_256x32_c2_bm_bist is
  port (
  A_DOUT      : out std_logic_vector(31 downto 0);
	A_ADDR      : in  std_logic_vector(7 downto 0);
	A_DIN       : in  std_logic_vector(31 downto 0);
	A_BM        : in  std_logic_vector(31 downto 0);
	A_WEN       : in  std_logic;
	A_MEN       : in  std_logic;
	A_CLK       : in  std_logic;
  A_REN       : in  std_logic;
  A_BIST_DIN  : in  std_logic_vector(31 downto 0);
  A_BIST_BM   : in  std_logic_vector(31 downto 0);
  A_BIST_ADDR : in  std_logic_vector(7 downto 0);
  A_BIST_MEN  : in  std_logic;
  A_BIST_REN  : in  std_logic;
  A_BIST_WEN  : in  std_logic;
  A_BIST_CLK  : in  std_logic;
  A_BIST_EN   : in  std_logic;
  A_DLY       : in  std_logic
       );
  end component;

  component RM_IHPSG13_1P_64x64_c2_bm_bist is
  port (
  A_DOUT      : out std_logic_vector(63 downto 0);
	A_ADDR      : in  std_logic_vector(5 downto 0);
	A_DIN       : in  std_logic_vector(63 downto 0);
	A_BM        : in  std_logic_vector(63 downto 0);
	A_WEN       : in  std_logic;
	A_MEN       : in  std_logic;
	A_CLK       : in  std_logic;
  A_REN       : in  std_logic;
  A_BIST_DIN  : in  std_logic_vector(63 downto 0);
  A_BIST_BM   : in  std_logic_vector(63 downto 0);
  A_BIST_ADDR : in  std_logic_vector(5 downto 0);
  A_BIST_MEN  : in  std_logic;
  A_BIST_REN  : in  std_logic;
  A_BIST_WEN  : in  std_logic;
  A_BIST_CLK  : in  std_logic;
  A_BIST_EN   : in  std_logic;
  A_DLY       : in  std_logic
       );
  end component;

  signal d, q, ben : std_logic_vector(63 downto 0);
  signal a : std_logic_vector(17 downto 0);
  signal wen : std_ulogic;
  constant synopsys_bug : std_logic_vector(63 downto 0) := (others => '0');

begin

  ben <= (others => '1'); wen <= wr;
  a(abits -1 downto 0) <= address;
  d(dbits -1 downto 0) <= datain(dbits -1 downto 0);
  a(17 downto abits) <= synopsys_bug(17 downto abits);
  d(63 downto dbits) <= synopsys_bug(63 downto dbits);
  dataout <= q(dbits -1 downto 0);
  he_status <= (others => '0'); he_data <= (others => '0'); mempres <= (others => '0'); fDataOut <= '0';

  d32 : if (dbits <= 32) generate
    a6d32 : if (abits = 6) generate -- 1p 64x32
      id0 : RM_IHPSG13_1P_64x64_c2_bm_bist port map (q(63 downto 0), a(5 downto 0), d(63 downto 0), ben(63 downto 0),
				   wen, enable, clk, '1', (others => '0'), (others => '0'), (others => '0'), '0', '0', '0', '0', '0', '1');
    end generate;
    a7d32 : if (abits = 7) generate -- 1p 128x32
      id0 : RM_IHPSG13_1P_256x32_c2_bm_bist port map (q(31 downto 0), a(7 downto 0), d(31 downto 0), ben(31 downto 0),
           wen, enable, clk, '1', (others => '0'), (others => '0'), (others => '0'), '0', '0', '0', '0', '0', '1');
    end generate;
    a9d32 : if (abits = 9) generate -- 1p 512x32
      id0 : RM_IHPSG13_1P_512x32_c2_bm_bist port map (q(31 downto 0), a(8 downto 0), d(31 downto 0), ben(31 downto 0),
				   wen, enable, clk, '1', (others => '0'), (others => '0'), (others => '0'), '0', '0', '0', '0', '0', '1');
    end generate;
  end generate;

-- pragma translate_off
  a_to_high : if (abits /= 6) or (abits /= 7) or (abits /= 9) or (dbits > 32) generate
    x : process
    begin
      assert false
      report  "Unsupported syncram size for gf22: abits= " & integer'image(abits) & " dbits= " & integer'image(dbits)
      severity failure;
      wait;
    end process;
  end generate;
-- pragma translate_on

end;

library ieee;
use ieee.std_logic_1164.all;
library techmap;
use techmap.gencomp.all;

entity gf22fdx_syncram_2p is
  generic (
    abits : integer := 8;
    dbits : integer := 32;
    sepclk: integer := 0
  );
  port (
    rclk: in std_ulogic;
    renable: in std_ulogic;
    raddress: in std_logic_vector(abits-1 downto 0);
    dataout: out std_logic_vector(dbits-1 downto 0);
    wclk: in std_ulogic;
    waddress: in std_logic_vector(abits-1 downto 0);
    datain: in std_logic_vector(dbits-1 downto 0);
    wenable: in std_ulogic;
    tBist: in std_ulogic;
    tLogic: in std_ulogic;
    tScan: in std_ulogic;
    tStab: in std_ulogic;
    tWbt: in std_ulogic;
    resetFuse: in std_ulogic;
    smp_ma: in std_logic_vector(11 downto 0);
    r2p_ma: in std_logic_vector(8 downto 0);
    ch_bus_r2p: in std_logic_vector(11 downto 0);
    ch_bus_smp: in std_logic_vector(11 downto 0);
    tck: in std_ulogic;
    eh_bus_r2p: in std_logic_vector(43 downto 0);
    eh_bus_smp: in std_logic_vector(30 downto 0);
    eh_diagSel: in std_logic_vector(3 downto 0);
    eh_memEn: in std_logic_vector(3 downto 0);
    he_status: out std_logic_vector(3 downto 0);
    he_data: out std_logic_vector(3 downto 0);
    mempres: out std_logic_vector(3 downto 0);
    fShift: in std_ulogic;
    fDataIn: in std_ulogic;
    fBypass: in std_ulogic;
    fEnable: in std_ulogic;
    fDataOut: out std_ulogic
  );
end;

architecture rtl of gf22fdx_syncram_2p is

  component generic_syncram_2p
  generic (
    abits    : integer := 8;
    dbits    : integer := 32;
    sepclk   : integer := 0;
    pipeline : integer := 0;
    rdhold   : integer := 0
  );
  port (
    rclk      : in  std_ulogic;
    wclk      : in  std_ulogic;
    rdaddress : in  std_logic_vector (abits -1 downto 0);
    wraddress : in  std_logic_vector (abits -1 downto 0);
    data      : in  std_logic_vector (dbits -1 downto 0);
    wren      : in  std_ulogic;
    q         : out std_logic_vector (dbits -1 downto 0);
    rden      : in  std_ulogic := '1'
    );
  end component;

  component RM_IHPSG13_2P_256x32_c2_bm_bist is
  port (
  A_DOUT      : out std_logic_vector(31 downto 0);
	A_ADDR      : in  std_logic_vector(7 downto 0);
	A_DIN       : in  std_logic_vector(31 downto 0);
	A_BM        : in  std_logic_vector(31 downto 0);
	A_WEN       : in  std_logic;
	A_MEN       : in  std_logic;
	A_CLK       : in  std_logic;
  A_REN       : in  std_logic;
  A_BIST_DIN  : in  std_logic_vector(31 downto 0);
  A_BIST_BM   : in  std_logic_vector(31 downto 0);
  A_BIST_ADDR : in  std_logic_vector(7 downto 0);
  A_BIST_MEN  : in  std_logic;
  A_BIST_REN  : in  std_logic;
  A_BIST_WEN  : in  std_logic;
  A_BIST_CLK  : in  std_logic;
  A_BIST_EN   : in  std_logic;
  A_DLY       : in  std_logic;

  B_DOUT      : out std_logic_vector(31 downto 0);
  B_ADDR      : in  std_logic_vector(7 downto 0);
  B_DIN       : in  std_logic_vector(31 downto 0);
  B_BM        : in  std_logic_vector(31 downto 0);
  B_WEN       : in  std_logic;
  B_MEN       : in  std_logic;
  B_CLK       : in  std_logic;
  B_REN       : in  std_logic;
  B_BIST_DIN  : in  std_logic_vector(31 downto 0);
  B_BIST_BM   : in  std_logic_vector(31 downto 0);
  B_BIST_ADDR : in  std_logic_vector(7 downto 0);
  B_BIST_MEN  : in  std_logic;
  B_BIST_REN  : in  std_logic;
  B_BIST_WEN  : in  std_logic;
  B_BIST_CLK  : in  std_logic;
  B_BIST_EN   : in  std_logic;
  B_DLY       : in  std_logic
       );
  end component;

  signal d, q, qb, ben : std_logic_vector(63 downto 0);
  signal ar, aw : std_logic_vector(17 downto 0);
  constant synopsys_bug : std_logic_vector(63 downto 0) := (others => '0');

begin

  ben <= (others => '1');
  ar(abits -1 downto 0) <= raddress;
  aw(abits -1 downto 0) <= waddress;
  d(dbits -1 downto 0) <= datain(dbits -1 downto 0);
  ar(17 downto abits) <= synopsys_bug(17 downto abits);
  aw(17 downto abits) <= synopsys_bug(17 downto abits);
  d(63 downto dbits) <= synopsys_bug(63 downto dbits);
  dataout <= q(dbits -1 downto 0);
  he_status <= (others => '0'); he_data <= (others => '0'); mempres <= (others => '0'); fDataOut <= '0';

  d32_2p : if (dbits <= 32) generate
    a7d32 : if (abits = 7) generate -- 2p 128x32
      id0 : RM_IHPSG13_2P_256x32_c2_bm_bist port map (q(31 downto 0), ar(7 downto 0), (others => '0'), ben(31 downto 0), '0',
          '1', rclk, renable, (others => '0'), (others => '0'), (others => '0'), '0', '0', '0', '0', '0', '1',
          qb(31 downto 0), aw(7 downto 0), d(31 downto 0), ben(31 downto 0), wenable, '1', wclk, '0', 
          (others => '0'), (others => '0'), (others => '0'), '0', '0', '0', '0', '0', '1');
    end generate;
  end generate;

  d64_2p : if (dbits > 32) and (dbits <= 64) generate
    a7d40 : if (abits = 7) generate -- 2p 128x64
      id0 : RM_IHPSG13_2P_256x32_c2_bm_bist port map (q(31 downto 0), ar(7 downto 0), (others => '0'), ben(31 downto 0), '0',
          '1', rclk, renable, (others => '0'), (others => '0'), (others => '0'), '0', '0', '0', '0', '0', '1',
          qb(31 downto 0), aw(7 downto 0), d(31 downto 0), ben(31 downto 0), wenable, '1', wclk, '0', 
          (others => '0'), (others => '0'), (others => '0'), '0', '0', '0', '0', '0', '1');
      id1 : RM_IHPSG13_2P_256x32_c2_bm_bist port map (q(63 downto 32), ar(7 downto 0), (others => '0'), ben(63 downto 32), '0',
          '1', rclk, renable, (others => '0'), (others => '0'), (others => '0'), '0', '0', '0', '0', '0', '1',
          qb(63 downto 32), aw(7 downto 0), d(63 downto 32), ben(63 downto 32), wenable, '1', wclk, '0', 
          (others => '0'), (others => '0'), (others => '0'), '0', '0', '0', '0', '0', '1');
    end generate;
  end generate;

  a_to_high : if (abits /= 7) or (dbits > 64) generate

    x0 : generic_syncram_2p
      generic map (
        abits => abits,
        dbits => dbits,
        sepclk => sepclk,
        pipeline => 0,
        rdhold => 0
      )
      port map (
        rclk => rclk,
        wclk => wclk,
        rdaddress => raddress,
        wraddress => waddress,
        data => datain,
        wren => wenable,
        q => dataout,
        rden => renable
      );

    -- pragma translate_off
      x : process
      begin
        assert false
          report  "A generic_syncram_2p will be inferred: abits= " & integer'image(abits) & " dbits= " & integer'image(dbits)
          severity warning;
        wait;
      end process;
    -- pragma translate_on
  end generate;

end;
