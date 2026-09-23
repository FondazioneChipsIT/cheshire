# FairBench

FairBench is a unified and fully open benchmarking platform for RISC-V cores. FairBench is based on the Cheshire SoC that was extended to support four open-source application-class cores: 
* CVA6S+, the dual-issue, in-order member of the CVA6 family, written in SystemVerilog and maintained by the OpenHW Group. 
* NOEL-V, the superscalar successor of Frontgrade Gaisler’s LEON SPARC processors, released as VHDL in the GRLIB library. 
* Sargantana, a 64-bit single-issue core from the Barcelona Supercomputing Center, written in SystemVerilog, that additionally implements a subset of RVV 0.7.1 and a set of custom instructions.
* C910, a commercial high-performance out-of-order core from Alibaba’s T-Head division whose Verilog RTL has been released open-source.

For detailed information on the Cheshire platform consult the [official documentation](https://pulp-platform.github.io/cheshire).

To ensure a transparent and balanced evaluation environment FairBench instantiates every core inside the Cheshire SoC and runs them through the same simulation, benchmarking, and implementation flows.
FairBench offers a fully open-source RTL-to-GDSII flow built on Librelane targeting the IHP 130nm open PDK, alongside two simulation flows based on QuestaSim and Verilator. 

## Initialize the repo

Before initializing the Cheshire environment make sure to have the necessary [dependencies](https://pulp-platform.github.io/cheshire/gs/#dependencies) installed.
For the FairBench flows the following tools are also required:
* Librelane v3.0.2
* OpenROAD 26Q1
* Yosys 0.64 (with Slang plugin)
* Verilator v5.046
* GHDL v6.0.0

It is recommended to use the excellent [IIC-OSIC-TOOLS](https://github.com/iic-jku/IIC-OSIC-TOOLS) container maintained by Harald Pretl that already offers a complete environment with all the necessary tools.
FairBench was tested with version 2026.04 of the [IIC-OSIC-TOOLS](https://github.com/iic-jku/IIC-OSIC-TOOLS) container, but a newer version might also work.

To initialize the repo and download the necessary source files run:
```
make all
```

## Librelane Flow

LibreLane is a Python framework that assembles state-of-the-art open-source EDA tools into a fully automated RTL-to-GDSII flow. 
FairBench Librelane flow can be lauched trough makefile while selecting the desired core with the `CHS_CORE` variable.
For example you can run the RTL-to-GDSII flow for CVA6 with the command:
```
make chs-librelane-run CHS_CORE=CVA6
```
Supported values of CHS_CORE are: `CVA6`, `NOELV`, `C910` and `SARGANTANA`.

These are the default flows, that will preserve most of the SoC and cores hierarchy and will allow you to extract usefull area and timing metrics.
Unfortunatly the netlists produced by these flows are not compatible with Verilator and can't be used for power analysis.
For this reason we made dedicated RTL-to-GDSII flows for power analysis, that work with a fully flattened netlist but retain all the other parameters from the default flows. 
You can lauch the RTL-to-GDSII flows for power analysis by setting the `POWER` variable to 1, for example with the CVA6 core the command will be:
```
make chs-librelane-run CHS_CORE=CVA6 POWER=1
```

## Building Benchmarks

FairBench includes the Coremark, Dhrystone and Embench-iot benchmarks, already configured to run on the Cheshire platform. The RISC-V cores available in FairBench support differenct ISA extensions; to build each benchmark with the best flags available for each core follow the instructions below. 

Each benchmark has its own compilation flags, you can change them inside the respective scripts by following the table below.

|benchmark|flags parameter|parameter location|
|-|-|-|
|Coremark|`PORT_CFLAGS`|`sw/deps/coremark/cheshire/core_portme.mak`|
|Dhrystone|`CHS_SW_DHRYSTONE_FLAGS`|`sw/sw.mk`|
|Embench-IoT|`cflags`|`sw/deps/embench-iot/config/riscv32/boards/cheshire/board.cfg`|

By default the flags are set to the fastest configuration available for CVA6 and NOELV; compilation flags for C910 and Sargantana can be derived from the defaults by removing unsupported ISA extensions, the configurations for each core are listed below.

|Core|ISA Extensions|
|----|----|
|CVA6|rv64imafdc_zba_zbb_zbc_zbs_zbkb_zbkc_zbkx_zicond_zfh_zicbom_zifencei|
|NOELV|rv64imafdc_zba_zbb_zbc_zbs_zbkb_zbkc_zbkx_zicond_zfh_zicbom_zifencei|
|C910|rv64imafdc|
|Sargantana|rv64imafd|

There are dedicated makefile targets to build the benchmarks which can then be executed in the two simulation flows presented below. At the end of every benchmark some metrics will be printed on the Cheshire UART, the simulation testbench frequency is 200Mhz, you can derive the score/Mhz as detailed in the following table.

|benchmark|make target|generated binary location|final score|
|-|-|-|-|
|Coremark|`make chs-coremark`|`sw/deps/coremark/coremark.elf`|(Iterations/Sec)/200 -> CM/Mhz|
|Dhrystone|`make chs-dhrystone`|`sw/deps/dhrystone/dhrystone.dram.elf`|DMIPS/200 -> DMIPS/Mhz|
|Embench-IoT|`make chs-embench-iot`|`sw/deps/embench-iot/bd/src`|instret/cycles -> IPC|

Sargantana doesn't support the C extension for compressed instructions; when removing the C extension from the build flags some compressed instructions might still be injected by the compiler resulting in a broken simulation. This problem is usually fixed by rebuilding the toolchain libraries without the compressed instructions extension.

## Verilator Flow

The Verilator simulation flow supports RTL and gate level simulations, it can be used to extract activity data for power analysis and perfomance metrics from the benchmarks.
Similar to the Librelane flow, you can select the desired core with the `CHS_CORE` variable, while the `BINARY` variable should be set to the path of the binary you want to run.
To run a simple hello world simulation with Sargantana you can use the command:
```
make chs-verilator-all CHS_CORE=SARGANTANA BINARY=sw/tests/helloworld.dram.elf
```
There is a side note for NOEL-V, the core is written in VHDL and thus not supported by Verilator, to avoid this problem FairBench uses GHDL to translate NOEL-V into Verilog.
Before simulating with NOEL-V you need to perform the GHDL translation with the following commands:
```
make chs-ghdl-translate
make chs-verilator-all CHS_CORE=NOELV BINARY=sw/tests/helloworld.dram.elf
```
To run a gate level simulation on a netlist generated by the Librelane flow for power analysis you need to use the `POST_PNR` and `NETLIST_PATH` variables, like the example below:
```
make chs-verilator-all BINARY=sw/tests/helloworld.dram.elf POST_PNR=1 NETLIST_PATH=target/librelane/runs/<timestamp>/53-openroad-fillinsertion/cheshire_wrap.nl.v
```

## QuestaSim Flow

The QuestaSim flow was adapted from the original Cheshire flow to supports RTL simulations for all the 4 cores.
To run the flow with the CVA6 core start QuestaSim in `target/sim/vsim` and run a [simulation](https://pulp-platform.github.io/cheshire/tg/sim) by typing:
```
set BINARY ../../../sw/tests/helloworld.spm.elf
source compile.cheshire_soc.tcl
set SELCFG 0
source start.cheshire_soc.tcl
run -all
```
You can choose which core to instantiate with the `SELCFG` parameter as explained in the table below, after changing `SELCFG` you just need to `source start.cheshire_soc.tcl` and `run -all`.

|SELCFG|Corresponding Core|
|----|----|
|0|CVA6|
|4|C910|
|5|NOELV|
|6|SARGANTANA|

## License

Unless specified otherwise in the respective file headers, all code checked into this repository is made available under a permissive license. All hardware sources and tool scripts are licensed under the Solderpad Hardware License 0.51 (see `LICENSE`) or compatible licenses. Register file code (e.g. `hw/regs/*.sv`) is generated by a fork of lowRISC's [`regtool`](https://github.com/lowRISC/opentitan/blob/master/util/regtool.py) and licensed under Apache 2.0. The USB OHCI controller (`hw/future/UsbOhciAxi4.v`) is generated from the [SpinalHDL](https://github.com/SpinalHDL/SpinalHDL) library licensed under the MIT license. All software sources are licensed under Apache 2.0.

## Publication

If you use Cheshire in your work, you can cite us:

```
@article{ottaviano2023cheshire,
      title   = {Cheshire: A Lightweight, Linux-Capable RISC-V Host
                 Platform for Domain-Specific Accelerator Plug-In},
      author  = {Alessandro Ottaviano and Thomas Benz and
                 Paul Scheffler and Luca Benini},
      journal = {IEEE Transactions on Circuits and Systems II: Express Briefs},
      year    = {2023},
      volume  = {70},
      number  = {10},
      pages   = {3777-3781},
      doi     = {10.1109/TCSII.2023.3289186}
}
```
