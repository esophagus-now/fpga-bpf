# A little something I borrowed from Clark Shen (clarkshen.com)
include config.mk

all: clean
	# Package IP nicely using Vivado
	vivado -mode tcl -nolog -nojournal -source scripts/ip_package.tcl -tclargs $(ip_name) $(part_name)
	# Clean up after Vivado...
	rm -f *log
	# Not 100% sure what Clark was using this for
	touch .timestamp

clean:
	rm -rf $(ip_name)
