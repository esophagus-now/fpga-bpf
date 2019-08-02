# fpga-bpf

In 1992/1993, Steve McCanne and Van Jacobson of Lawrence Berkely Labs [proposed the BSD packet filter](https://www.tcpdump.org/papers/bpf-usenix93.pdf) architecture, as part of the [`tcpdump` project](https://www.tcpdump.org/). `tcpdump` was a network analysis utility which, along with the help of some code added to the Linux kernel, copied any incoming or outgoing network packet into userspace. Then, the `tcpdump` program could be used to run some basic analytics. In particular, there was a simple query language to filter out certain packets (for example, "show me all incoming TCP packets on port 4444").

However, McCanne and Jacobson realized that it's very inefficient to copy _every single packet_ into userspace to only then discard over 90% of them. So, it would be better to only copy out the ones we want in the first place.

Problem was, to change which packets are copied to userspace, code inside the Linux kernel would have to be changed. Instead, the solution was basically to add an "interpreter" into the Linux kernel. Then, userspace programs could send new "scripts" (which would be run by the interpreter) anytime they wanted to change the packet filter.

## The BSD Packet Filter Virtual Machine (BPFVM)

Enter the BSD packet filter virtual machine. The "interpreter" in  the kernel is essentially an emulator for a very simple processor architecture*, which I've summarized in [this file](BPFVM.txt). McCanne went on to write a fairly sophisticated compiler which could accept human-readable filter specifications, and compile a working BPF machine code program.

*There were similar solutions already out there. However, in [a talk given by Steve McCanne](https://www.youtube.com/watch?v=XHlqIqPvKw8), he explains that the BPF VM architecture was specifically designed for fast emulation on a regular RISC CPU (and with minimal memory accesses).

## (e)BPF in modern times

Since the BPFVM emulator runs inside the Linux kernel, it is very important that there are no security concerns or bugs. There are some extra rules for correct BPF programs, such as disallowing backwards jumps (which makes looping impossible) and very strict runtime memory bounds-checking.

Fast-forward a bit, and the BPF emulator code had been in the kernel for about 20 years, and was a very stable/safe way to upload new functionality into a running kernel from userspace. Sound useful?

Well, a lot of other people thought so, and in ~2010 Eric Dumazet added a [just-in-time compiler](https://lwn.net/Articles/437981/) for extra speed. There were more and more ways to use BPF to trace other parts of the Linux kernel (such as Unix domain sockets), and it became cumbersome to have the [BPF emulator stuck inside the networking code](https://lwn.net/Articles/599755/) where it had been for 20 years.

Eventually, eBPF (extended BPF) was added to Linux, and [there are some really impressive things you can do with it](https://www.youtube.com/watch?v=JRFNIKUROPE). Once again, it's basically a safe (and fast) scripting language for the Linux kernel.

## BPF in an FPGA

This project essentially builds a soft CPU for FPGAs which runs BPF as its native instruction set. This is part of a larger effort to make FPGAs easier to debug. One of my short-term goals is to make it possible to use Wireshark on arbitrary connections in your FPGA design.

The repository is not super organized right now, but I've left some comments at the start of each file. Also, I've drawn a few diagrams which I'll find some nice way to upload (probably using github's wiki feature, which I haven't figured out how to use yet).
