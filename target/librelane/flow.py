import argparse
import os
from typing import List, Type, Tuple
from librelane.steps import Step, OpenROADStep, Yosys, Misc, OpenROAD, Odb, Checker, Magic, Netgen, KLayout, Verilator
from librelane.steps.step import ViewsUpdate, MetricsUpdate
from librelane.flows import Flow, FlowError
from librelane.flows.classic import Classic
from librelane.state.state import State
from librelane.config.variable import Variable
from librelane.config.config import Config
from librelane.logging import info
from decimal import Decimal
from librelane.common import Path
from typing import (
    Any,
    List,
    Dict,
    Literal,
    Set,
    Tuple,
    Optional,
    Union,
)


@Step.factory.register()
class CustomGlobalPlacement(OpenROAD.GlobalPlacement):
    """
    Performs a faster timing driven global placement.
    """

    id = "OpenROAD.CustomGlobalPlacement"
    name = "Custom Global Placement"

    config_vars = OpenROAD.GlobalPlacement.config_vars + [
        Variable(
            "PL_CUSTOM_GPL_SCRIPT",
            Path,
            "A custom TCL script for global placement. If not provided, the default GPL script will be used.",
            default="./custom_gpl.tcl"
        )
    ]

    def get_script_path(self):
        return self.config["PL_CUSTOM_GPL_SCRIPT"]


@Flow.factory.register()
class CheshireFlow(Classic):
    """
    Classic flow with custom global placement.
    """

    Steps = [
        Verilator.Lint,
        Checker.LintTimingConstructs,
        Checker.LintErrors,
        Checker.LintWarnings,
        Yosys.JsonHeader,
        Yosys.Synthesis,
        Checker.YosysUnmappedCells,
        Checker.YosysSynthChecks,
        Checker.NetlistAssignStatements,        
        OpenROAD.CheckSDCFiles,
        OpenROAD.CheckMacroInstances,
        OpenROAD.Floorplan,
        OpenROAD.DumpRCValues,
        Odb.CheckMacroAntennaProperties,
        Odb.SetPowerConnections,
        Odb.ManualMacroPlacement,
        OpenROAD.CutRows,
        OpenROAD.TapEndcapInsertion,
        Odb.AddPDNObstructions,
        OpenROAD.GeneratePDN,
        Odb.RemovePDNObstructions,
        Odb.AddRoutingObstructions,
        OpenROAD.GlobalPlacementSkipIO,
        OpenROAD.IOPlacement,
        Odb.CustomIOPlacement,

        Odb.ApplyDEFTemplate,
#        OpenROAD.GlobalPlacement,
        CustomGlobalPlacement,
        Odb.WriteVerilogHeader,
        Checker.PowerGridViolations,
        OpenROAD.RepairDesignPostGPL,
        Odb.ManualGlobalPlacement,
        OpenROAD.DetailedPlacement,
        OpenROAD.CTS,
        OpenROAD.STAMidPNR,
        OpenROAD.ResizerTimingPostCTS,
        OpenROAD.STAMidPNR,
        OpenROAD.GlobalRouting,
        OpenROAD.CheckAntennas,
        OpenROAD.RepairDesignPostGRT,
        Odb.DiodesOnPorts,
        Odb.HeuristicDiodeInsertion,
        OpenROAD.RepairAntennas,
        OpenROAD.ResizerTimingPostGRT,
        OpenROAD.STAMidPNR,
        OpenROAD.DetailedRouting,
        Odb.RemoveRoutingObstructions,
        OpenROAD.CheckAntennas,
        Checker.TrDRC,
        Odb.ReportDisconnectedPins,
        Checker.DisconnectedPins,
        Odb.ReportWireLength,
        Checker.WireLength,
        OpenROAD.FillInsertion,
        Odb.CellFrequencyTables,
        OpenROAD.RCX,
        OpenROAD.STAPostPNR,
        OpenROAD.IRDropReport,
        Magic.StreamOut,
        KLayout.StreamOut,
        KLayout.Render,
        Magic.WriteLEF,
        Odb.CheckDesignAntennaProperties,
        KLayout.XOR,
        Checker.XOR,
        Checker.SetupViolations,
        Checker.HoldViolations,
        Checker.MaxSlewViolations,
        Checker.MaxCapViolations,
        Misc.ReportManufacturability
    ]

# usage: python3 flow.py config_c910.yaml
def main():
    parser = argparse.ArgumentParser(description="Start the Cheshire librelane flow")
    parser.add_argument(
        "config_path",
        nargs="?",
        default="./config_cva6_custom.yaml",
        help="Path to the config YAML file to use for the flow",
    )
    args = parser.parse_args()


    flow = CheshireFlow(
        args.config_path,
        design_dir = ".",
    )

    # start flow from first step
    flow.start()

    # start flow from previous step
    # C910
    # flow.start(with_initial_state=State.loads(Path("/foss/designs/cheshire_oc/cheshire/target/librelane/runs/RUN_2026-07-29_22-05-40/27-odb-applydeftemplate/state_in.json").read_text()), tag="RUN_2026-07-29_22-05-40")
    # Sargantana
    # flow.start(with_initial_state=State.loads(Path("/foss/designs/cheshire_oc/cheshire/target/librelane/runs/RUN_2026-07-31_09-21-00/28-odb-applydeftemplate/state_in.json").read_text()), tag="RUN_2026-07-31_09-21-00")


if __name__ == "__main__":
    main()