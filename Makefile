.PHONY: lab-up lab-down lab-reset lab-status lab-test bpf xdp-load xdp-unload xdp-status

lab-up:
	sudo ./lab/setup.sh

lab-down:
	sudo ./lab/cleanup.sh

lab-reset:
	sudo ./lab/cleanup.sh
	sudo ./lab/setup.sh

lab-status:
	sudo ./lab/status.sh


lab-test:
	sudo ip netns exec client ping -c 1 10.200.0.1
	sudo ip netns exec client ping -c 1 10.201.0.2
	sudo ip netns exec client ping -c 1 10.202.0.2


BPF_CLANG := clang
BPF_CFLAGS := -O2 -g -target bpf

BPF_SRC := src/lb.bpf.c
BPF_OBJ := build/lb.bpf.o


.PHONY: bpf

bpf:
	mkdir -p build
	$(BPF_CLANG) $(BPF_CFLAGS) -c $(BPF_SRC) -o $(BPF_OBJ)


XDP_IFACE := lb-font

xdp-load: bpf
	sudo ip link set dev $(XDP_IFACE) xdp obj $(BPF_OBJ) sec xdp

xdp-unload:
	sudo ip link set dev $(XDP_IFACE) xdp off

xdp-status:
	sudo ip -details link show dev $(XDP_IFACE)
