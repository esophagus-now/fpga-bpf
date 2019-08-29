#include <iostream>
#include <pcap.h>
#include <boost/asio.hpp>
#include <cstring>

using std::cout;
using std::cerr;
using std::ostream;
using namespace boost::asio;
using boost::asio::ip::tcp;

ostream& el(ostream& o) {return o << "\n";}

tcp::socket *psock;
char receive_buf[80];

void handler(
  const boost::system::error_code& error, // Result of operation.
  std::size_t bytes_transferred           // Number of bytes received.
) {
	cout << "Received " << bytes_transferred << " bytes" << el;
	int i = 0;
	do {
		cout << receive_buf[i];
	} while(receive_buf[i++] != '\n');
	//just keep swallowing received messages
	psock->async_receive(buffer(receive_buf), handler);
}

int main(int argc, char **argv) {
	/* Quick check to program arugments */
	if (argc != 2) {
		cout << "Usage: sendfilt FILTER-TEXT" << el;
		return -1;
	}
	
	cout << "Using default address 192.168.1.10:7" << el;
	
	/* Variables for using pcap */
	pcap_t *handle;				//Handle to pcap context
	char errbuf[PCAP_ERRBUF_SIZE];		//String to store error messages
	struct bpf_program fp = {0, NULL};	//Store compiled BPF code
	bpf_u_int32 dummymask = 0;		//Needed a dummy argument to pcap_compile
	
	handle = pcap_open_dead(DLT_EN10MB, 65535);	//Open dummy pcap "connection"
	if (!handle) {
		cerr << "pcap_create failed: " << errbuf << el;
	}
	
	//Try compiling filter code
	if(pcap_compile(handle, &fp, argv[1], 1, dummymask) < 0) {
		pcap_perror(handle, "pcap_compile failed: ");
	} else {
		//If compile succeeded, send code to FPGA
		try {
			//Create a tcp socket and connect it to the FPGA
			io_context ctx;
			tcp::socket sock(ctx);
			psock = &sock;
			sock.connect(tcp::endpoint(
				ip::make_address("192.168.1.10"), 
				7
			));
			
			//We want to swallow any messages that come back so that
			//we don't clog up the FPGA's TCP send queue
			//sock.async_receive(buffer(receive_buf), handler);
			
			//Stop the packet filter before we write instructions
			sock.send(buffer("4,0\n\r"));
			cout << "Stopped packet filter..." << el;
			for (int i = 0; i < int(fp.bf_len); i++) {
				char line[80];
				sprintf(line,
					"C,%04x%02x%02x\n\r8,%08x\n\r",
					fp.bf_insns[i].code,
					fp.bf_insns[i].jt,
					fp.bf_insns[i].jf,
					fp.bf_insns[i].k
				);
				sock.send(buffer(line, strlen(line)));
				//ctx.run(); //let any async_receives through
			}
			cout << "Succesfully sent new program" << el;
			//Restart the packet filter with the new code
			sock.send(buffer("4,1\n\r"));
			cout << "Succesfully restarted packet filter" << el;
			//ctx.run(); //let any async_receives through
		} catch (std::exception &e) {
			cerr << e.what() << el;
		}
	}
	
	pcap_freecode(&fp);
	pcap_close(handle);
	return 0;
}
