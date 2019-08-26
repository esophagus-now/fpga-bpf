#include <stdio.h>
#include <pcap.h>

int main(int argc, char **argv) {
	pcap_t *handle; 
	char errbuf[PCAP_ERRBUF_SIZE];
	struct bpf_program fp = {0, NULL};
	//char filter_exp[] = "tcp port 100 and 200";
	bpf_u_int32 dummymask = 0;
	
	if (argc != 2) {
		puts("Usage: compilefilt FILTER-TEXT");
		return -1;
	}
	
	handle = pcap_open_dead(0,65535);
	if (!handle) {
		printf("pcap_create failed: %s\n", errbuf);
	}
	
	if(pcap_compile(handle, &fp, argv[1], 1, dummymask) < 0) {
		pcap_perror(handle, "pcap_compile failed: ");
	} else {
	
		for (int i = 0; i < fp.bf_len; i++) {
			printf("%04x%02x%02x%08x\n",
				fp.bf_insns[i].code,
				fp.bf_insns[i].jt,
				fp.bf_insns[i].jf,
				fp.bf_insns[i].k
			);
		}
	}
	
	pcap_freecode(&fp);
	pcap_close(handle);
	return 0;
}
