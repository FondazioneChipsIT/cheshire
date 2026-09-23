CHS_CORE ?= CVA6
CHS_CORE_LC ?= $(shell echo $(CHS_CORE) | tr '[:upper:]' '[:lower:]')

POWER ?= 0

LIBRELANE_DIR := $(CHS_ROOT)/target/librelane

# Translate the NOEL-V VHDL to Verilog using GHDL
$(LIBRELANE_DIR)/vhdl/synth/noelv_chs_wrap_post.v: $(LIBRELANE_DIR)/vhdl/yosys_noelv.sh
	cd $(LIBRELANE_DIR)/vhdl && source $(LIBRELANE_DIR)/vhdl/yosys_noelv.sh

chs-ghdl-translate: $(LIBRELANE_DIR)/vhdl/synth/noelv_chs_wrap_post.v

# Run LibreLane flow for the selected core
chs-librelane-run: $(LIBRELANE_DIR)/config_$(CHS_CORE_LC).yaml $(LIBRELANE_DIR)/config_$(CHS_CORE_LC)_power.yaml
# For IIC-OSIC-TOOLS container use OpenROAD-Librelane when running Librelane from Pyhton.
ifdef IIC_OSIC_TOOLS_VERSION
	ln -sf /foss/tools/bin/openroad-librelane /tmp/librelane-bin/openroad
	ln -sf /foss/tools/bin/sta-librelane /tmp/librelane-bin/sta
endif
ifeq ($(POWER), 0)
	cd $(LIBRELANE_DIR) && python3 $(LIBRELANE_DIR)/flow.py $(LIBRELANE_DIR)/config_$(CHS_CORE_LC).yaml
else
	cd $(LIBRELANE_DIR) && python3 $(LIBRELANE_DIR)/flow.py $(LIBRELANE_DIR)/config_$(CHS_CORE_LC)_power.yaml
endif

chs-librelane-openroad: # Open the last LibreLane run in OpenROAD GUI
ifeq ($(POWER), 0)
	cd $(LIBRELANE_DIR) && librelane $(LIBRELANE_DIR)/config_$(CHS_CORE_LC).yaml --last-run --flow OpenInOpenROAD
else
	cd $(LIBRELANE_DIR) && librelane $(LIBRELANE_DIR)/config_$(CHS_CORE_LC)_power.yaml --last-run --flow OpenInOpenROAD
endif

chs-librelane-klayout: # Open the last LibreLane run in KLayout
ifeq ($(POWER), 0)
	cd $(LIBRELANE_DIR) && librelane $(LIBRELANE_DIR)/config_$(CHS_CORE_LC).yaml --last-run --flow OpenInKLayout
else
	cd $(LIBRELANE_DIR) && librelane $(LIBRELANE_DIR)/config_$(CHS_CORE_LC)_power.yaml --last-run --flow OpenInKLayout
endif

CHS_PHONY += chs-librelane-run chs-ghdl-translate chs-librelane-openroad chs-librelane-klayout
