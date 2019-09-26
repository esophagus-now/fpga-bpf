#include <stdio.h>
#include <pcap.h>

int main(int argc, char **argv) {
	FILE *bin_file = fopen("prog.bpf", "wb");
	
	struct bpf_program fp = {0, NULL};
	//char filter_exp[] = "tcp port 100 and 200";
	
	if (argc != 2) {
		puts("Usage: compilefilt FILTER-TEXT");
		return -1;
	}
	
	if(pcap_compile_nopcap(65535, DLT_EN10MB, &fp, argv[1], 1, PCAP_NETMASK_UNKNOWN) < 0) {
		puts("Could not compile program");
	} else {
		//Write bin file
		fwrite(fp.bf_insns, 64, fp.bf_len, bin_file);
		for (int i = 0; i < fp.bf_len; i++) {
			printf("%04x%02x%02x%08x\n",
				fp.bf_insns[i].code,
				fp.bf_insns[i].jt,
				fp.bf_insns[i].jf,
				fp.bf_insns[i].k
			);
		}
	}
	
	fclose(bin_file);
	pcap_freecode(&fp);
	return 0;
}
