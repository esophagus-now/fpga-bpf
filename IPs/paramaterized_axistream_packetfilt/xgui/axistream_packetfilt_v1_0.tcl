# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "AXI_ADDR_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "BASEADDR" -parent ${Page_0}
  ipgui::add_param $IPINST -name "CODE_ADDR_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "N" -parent ${Page_0}
  ipgui::add_param $IPINST -name "PACKET_BYTE_ADDR_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "SNOOP_FWD_ADDR_WIDTH" -parent ${Page_0}


}

proc update_PARAM_VALUE.AXI_ADDR_WIDTH { PARAM_VALUE.AXI_ADDR_WIDTH } {
	# Procedure called to update AXI_ADDR_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.AXI_ADDR_WIDTH { PARAM_VALUE.AXI_ADDR_WIDTH } {
	# Procedure called to validate AXI_ADDR_WIDTH
	return true
}

proc update_PARAM_VALUE.BASEADDR { PARAM_VALUE.BASEADDR } {
	# Procedure called to update BASEADDR when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.BASEADDR { PARAM_VALUE.BASEADDR } {
	# Procedure called to validate BASEADDR
	return true
}

proc update_PARAM_VALUE.CODE_ADDR_WIDTH { PARAM_VALUE.CODE_ADDR_WIDTH } {
	# Procedure called to update CODE_ADDR_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.CODE_ADDR_WIDTH { PARAM_VALUE.CODE_ADDR_WIDTH } {
	# Procedure called to validate CODE_ADDR_WIDTH
	return true
}

proc update_PARAM_VALUE.N { PARAM_VALUE.N } {
	# Procedure called to update N when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.N { PARAM_VALUE.N } {
	# Procedure called to validate N
	return true
}

proc update_PARAM_VALUE.PACKET_BYTE_ADDR_WIDTH { PARAM_VALUE.PACKET_BYTE_ADDR_WIDTH } {
	# Procedure called to update PACKET_BYTE_ADDR_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.PACKET_BYTE_ADDR_WIDTH { PARAM_VALUE.PACKET_BYTE_ADDR_WIDTH } {
	# Procedure called to validate PACKET_BYTE_ADDR_WIDTH
	return true
}

proc update_PARAM_VALUE.SNOOP_FWD_ADDR_WIDTH { PARAM_VALUE.SNOOP_FWD_ADDR_WIDTH } {
	# Procedure called to update SNOOP_FWD_ADDR_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.SNOOP_FWD_ADDR_WIDTH { PARAM_VALUE.SNOOP_FWD_ADDR_WIDTH } {
	# Procedure called to validate SNOOP_FWD_ADDR_WIDTH
	return true
}


proc update_MODELPARAM_VALUE.AXI_ADDR_WIDTH { MODELPARAM_VALUE.AXI_ADDR_WIDTH PARAM_VALUE.AXI_ADDR_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.AXI_ADDR_WIDTH}] ${MODELPARAM_VALUE.AXI_ADDR_WIDTH}
}

proc update_MODELPARAM_VALUE.BASEADDR { MODELPARAM_VALUE.BASEADDR PARAM_VALUE.BASEADDR } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.BASEADDR}] ${MODELPARAM_VALUE.BASEADDR}
}

proc update_MODELPARAM_VALUE.CODE_ADDR_WIDTH { MODELPARAM_VALUE.CODE_ADDR_WIDTH PARAM_VALUE.CODE_ADDR_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.CODE_ADDR_WIDTH}] ${MODELPARAM_VALUE.CODE_ADDR_WIDTH}
}

proc update_MODELPARAM_VALUE.PACKET_BYTE_ADDR_WIDTH { MODELPARAM_VALUE.PACKET_BYTE_ADDR_WIDTH PARAM_VALUE.PACKET_BYTE_ADDR_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.PACKET_BYTE_ADDR_WIDTH}] ${MODELPARAM_VALUE.PACKET_BYTE_ADDR_WIDTH}
}

proc update_MODELPARAM_VALUE.SNOOP_FWD_ADDR_WIDTH { MODELPARAM_VALUE.SNOOP_FWD_ADDR_WIDTH PARAM_VALUE.SNOOP_FWD_ADDR_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.SNOOP_FWD_ADDR_WIDTH}] ${MODELPARAM_VALUE.SNOOP_FWD_ADDR_WIDTH}
}

proc update_MODELPARAM_VALUE.N { MODELPARAM_VALUE.N PARAM_VALUE.N } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.N}] ${MODELPARAM_VALUE.N}
}

