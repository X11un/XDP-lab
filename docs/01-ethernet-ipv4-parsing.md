# Step 1 — Ethernet / IPv4 parsing and first filtering rule

Source file: [`src/lb.bpf.c`](../src/lb.bpf.c)
Attached interface: `lb-front` (client-facing side of the load balancer)

## Goal

Before doing any load-balancing, the program needs to correctly parse the
packets arriving on the interface. This first step of the XDP program does
two things:

1. Parse the Ethernet header, then the IPv4 header.
2. Apply a simple filtering rule as a test: if the packet is ICMP, drop it
   (`XDP_DROP`) instead of letting it through.

This step is deliberately basic. Its main purpose is to validate that the
program loads correctly on `lb-front`, that bounds-checked parsing works,
and that the `XDP_DROP` / `XDP_PASS` behavior is the expected one, before
moving on to the actual load-balancing logic.

## Code

```c
#include <linux/bpf.h>
#include <linux/if_ether.h>
#include <linux/ip.h>
#include <linux/in.h>

#include <bpf/bpf_helpers.h>
#include <bpf/bpf_endian.h>


// Parse Ethernet & IPv4

SEC("xdp")
int xdp_lb(struct xdp_md *ctx){
    void *data = (void *)(long)ctx->data;
    void *data_end = (void *)(long)ctx->data_end;

    struct ethhdr *eth = data;

    if ((void*)(eth + 1) > data_end)
        return XDP_ABORTED;

    if (eth->h_proto != bpf_htons(ETH_P_IP))    // h_proto is network byte order (big-endian)
        return XDP_PASS;


    struct iphdr *ip = (void *)(eth + 1);       // IPv4 header right after Ethernet

    if ((void *)(ip + 1) > data_end)            // Bounds check, stop if it exceeds data_end
        return XDP_ABORTED;

    if (ip->protocol == IPPROTO_ICMP)           // 1 = ICMP
        return XDP_DROP;


    return XDP_PASS;
}


char LICENSE[] SEC("license") = "GPL";
```

## Explanation

- **Bounds-checking**: the eBPF verifier requires every memory access to be
  provably safe. That's why the end-of-struct pointers (`eth + 1`, `ip + 1`)
  are systematically compared to `data_end` before dereferencing anything.
  Without this, the program would be rejected at load time.
- **`eth->h_proto`**: this field is in network byte order (big-endian),
  hence the use of `bpf_htons(ETH_P_IP)` to correctly compare it against
  `0x0800`.
- **ICMP filtering**: `ip->protocol == IPPROTO_ICMP` (value `1`) identifies
  ICMP packets and drops them with `XDP_DROP`. Everything else (TCP, UDP,
  other IP protocols) is passed through with `XDP_PASS`.

## Building and loading the program

```bash
make bpf          # compiles src/lb.bpf.c -> build/lb.bpf.o
sudo make xdp-load # attaches build/lb.bpf.o to the lb-front interface
make xdp-status    # confirms the XDP program is attached
```

## Observed behavior in the lab

Once the program is loaded on `lb-front`, ICMP traffic is indeed blocked:

```bash
sudo ip netns exec client ping 10.201.0.2
```

Result: the ping gets no reply (packets are lost), which is the expected
behavior since the XDP program explicitly drops all ICMP packets crossing
`lb-front`, before they even reach the load balancer's network stack. This
is also visible with `make lab-test`, which pings `10.200.0.1`,
`10.201.0.2`, and `10.202.0.2`: the pings fail while the program is loaded.

To go back to normal behavior:

```bash
sudo make xdp-unload
```

Conversely, non-ICMP traffic (e.g. TCP) on the same path keeps flowing
normally, confirming that the filtering rule targets `IPPROTO_ICMP`
specifically rather than all IPv4 traffic.
