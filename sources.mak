BOARD_DIR=../rtl
TDC_DIR=../tdc-core
GENCORES_DIR=../general-cores

BOARD_SRC=$(wildcard $(BOARD_DIR)/*.v)
TDC_SRC=$(wildcard $(TDC_DIR)/core/*.vhd)
GENRAMS_SRC=$(wildcard $(GENCORES_DIR)/modules/genrams/*.vhd) $(wildcard $(GENCORES_DIR)/modules/genrams/xilinx/*.vhd)

CORES_SRC_VHDL=$(GENRAMS_SRC) $(TDC_SRC) $(TDCHI_SRC)
