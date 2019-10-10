# A little something I borrowed from Clark Shen (clarkshen.com)

# I was getting extremely tired od repackaging the IP every time, so this is a
# little script that does it

# Call as:
# vivado -mode tcl -nolog -nojournal -source scripts/ip_package.tcl -tclargs $ip_name $part_name

# Note the "start_gui" line in the comments, and the "done with gui" line
# Essentially, the first time I ran this script, I didn't know what I would need
# to run for the TCL commands. So, I used the GUI and then copy-pasted the TCL
# commands from the console. These commands lie between the two comment lines
# mentioned above

set ip_name [lindex $argv 0]
set part_name [lindex $argv 1]
set project_name ${ip_name}
create_project ${project_name} ${project_name} -part $part_name
import_files ../Sources
set_property top axistream_packetfilt [current_fileset]
update_compile_order -fileset sources_1
ipx::package_project -root_dir ${project_name}/${project_name}.srcs/sources_1/imports -vendor Marco_Merlini -library fpga_bpf -taxonomy /UserIP

# start GUI
set_property interface_mode monitor [ipx::get_bus_interfaces snoop -of_objects [ipx::current_core]]
ipx::associate_bus_interfaces -busif snoop -clock axi_aclk [ipx::current_core]
ipx::associate_bus_interfaces -busif fwd -clock axi_aclk [ipx::current_core]

set_property display_name {AXI Lite address width} [ipgui::get_guiparamspec -name "AXI_ADDR_WIDTH" -component [ipx::current_core] ]
set_property tooltip {Width of control bus address} [ipgui::get_guiparamspec -name "AXI_ADDR_WIDTH" -component [ipx::current_core] ]
set_property widget {textEdit} [ipgui::get_guiparamspec -name "AXI_ADDR_WIDTH" -component [ipx::current_core] ]

set_property display_name {Base address} [ipgui::get_guiparamspec -name "BASEADDR" -component [ipx::current_core] ]
set_property tooltip {Please set this equal to the address used in the Address Editor} [ipgui::get_guiparamspec -name "BASEADDR" -component [ipx::current_core] ]
set_property widget {hexEdit} [ipgui::get_guiparamspec -name "BASEADDR" -component [ipx::current_core] ]
set_property value 0xA0000000 [ipx::get_user_parameters BASEADDR -of_objects [ipx::current_core]]
set_property value 0xA0000000 [ipx::get_hdl_parameters BASEADDR -of_objects [ipx::current_core]]

set_property display_name {Code address width} [ipgui::get_guiparamspec -name "CODE_ADDR_WIDTH" -component [ipx::current_core] ]
set_property tooltip {The instruction capacity is 2 to the power of this number} [ipgui::get_guiparamspec -name "CODE_ADDR_WIDTH" -component [ipx::current_core] ]
set_property widget {textEdit} [ipgui::get_guiparamspec -name "CODE_ADDR_WIDTH" -component [ipx::current_core] ]

set_property display_name {Packet byte address width} [ipgui::get_guiparamspec -name "PACKET_BYTE_ADDR_WIDTH" -component [ipx::current_core] ]
set_property tooltip {The capacity of the packet buffers is 2 to the power of this number (in bytes)} [ipgui::get_guiparamspec -name "PACKET_BYTE_ADDR_WIDTH" -component [ipx::current_core] ]
set_property widget {textEdit} [ipgui::get_guiparamspec -name "PACKET_BYTE_ADDR_WIDTH" -component [ipx::current_core] ]

set_property display_name {Snooper Forwader address width} [ipgui::get_guiparamspec -name "SNOOP_FWD_ADDR_WIDTH" -component [ipx::current_core] ]
set_property tooltip {The width of the snooper and forwarder data is 2 to the power of (byte address width minus this number) in bytes} [ipgui::get_guiparamspec -name "SNOOP_FWD_ADDR_WIDTH" -component [ipx::current_core] ]
set_property widget {textEdit} [ipgui::get_guiparamspec -name "SNOOP_FWD_ADDR_WIDTH" -component [ipx::current_core] ]
set_property value 6 [ipx::get_user_parameters SNOOP_FWD_ADDR_WIDTH -of_objects [ipx::current_core]]
set_property value 6 [ipx::get_hdl_parameters SNOOP_FWD_ADDR_WIDTH -of_objects [ipx::current_core]]

set_property display_name {Number of parallel filters} [ipgui::get_guiparamspec -name "N" -component [ipx::current_core] ]
set_property tooltip {If packet filter bandiwdth is your bottleneck, increase this number} [ipgui::get_guiparamspec -name "N" -component [ipx::current_core] ]
set_property widget {textEdit} [ipgui::get_guiparamspec -name "N" -component [ipx::current_core] ]
set_property value 2 [ipx::get_user_parameters N -of_objects [ipx::current_core]]
set_property value 2 [ipx::get_hdl_parameters N -of_objects [ipx::current_core]]

set_property display_name {Enable pessimistic registers} [ipgui::get_guiparamspec -name "PESSIMISTIC" -component [ipx::current_core] ]
set_property tooltip {Enables a few internal registers. Greatly eases timing, slightly reduces performance} [ipgui::get_guiparamspec -name "PESSIMISTIC" -component [ipx::current_core] ]
set_property widget {checkBox} [ipgui::get_guiparamspec -name "PESSIMISTIC" -component [ipx::current_core] ]
set_property value true [ipx::get_user_parameters PESSIMISTIC -of_objects [ipx::current_core]]
set_property value true [ipx::get_hdl_parameters PESSIMISTIC -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_user_parameters PESSIMISTIC -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_hdl_parameters PESSIMISTIC -of_objects [ipx::current_core]]

set_property range {4096} [ipx::get_address_blocks -of_objects [ipx::get_memory_maps -of_objects [ipx::current_core ]]]
set_property range_dependency {} [ipx::get_address_blocks -of_objects [ipx::get_memory_maps -of_objects [ipx::current_core ]]]
# done with GUI

ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::save_core [ipx::current_core]
close_project 
exit
