# Step 2 — TCP parsing and VIP:port filtering

Source file: [`src/lb.bpf.c`](../src/lb.bpf.c)
Attached interface: `lb-front` (client-facing side of the load balancer)

## Goal

This step builds on [step 1](01-ethernet-ipv4-parsing.md) by going one level
deeper in the packet: after Ethernet and IPv4, the program now parses TCP,
and correctly handles the fact that an IPv4 header does not always have a
fixed size (IP options).

Two changes were made compared to step 1:

1. ICMP is no longer dropped — `IPPROTO_ICMP` now returns `XDP_PASS`. ICMP
   was only used in step 1 to prove that filtering worked at all; the real
   target traffic for a load balancer is TCP, not ICMP.
2. A new rule drops any TCP packet addressed to the VIP `10.200.0.100` on
   port `8080`, as a first, deliberately simple test of "traffic to the
   virtual IP can be intercepted here" — before that traffic is actually
   redirected to a backend in a later step.

## Code

```c
#include <linux/bpf.h>
#include <linux/if_ether.h>
#include <linux/ip.h>
#include <linux/in.h>
#include <linux/tcp.h>

#include <bpf/bpf_helpers.h>
#include <bpf/bpf_endian.h>

#define LB_VIP 0x0AC80064   // 10.200.0.100

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
        return XDP_PASS;

    __u32 ip_header_len = ip->ihl * 4;

    if (ip_header_len < sizeof(*ip))
        return XDP_ABORTED;

    if ((void *)((char *)ip + ip_header_len) > data_end)
        return XDP_ABORTED;


// TCP
    struct tcphdr *tcp = (void *)((char *)ip + ip_header_len);

    if ((void *)(tcp + 1) > data_end)
        return XDP_ABORTED;

    if (ip->daddr == bpf_htonl(LB_VIP) && tcp->dest == bpf_htons(8080)){        // VIP 10.200.0.100:8080
        return XDP_DROP;
    }

    return XDP_PASS;
}


char LICENSE[] SEC("license") = "GPL";
```

## Explanation

- **Variable-length IPv4 header**: an IPv4 header is not always 20 bytes.
  The `ihl` field (Internet Header Length) gives the header length in
  32-bit words, so `ip->ihl * 4` gives the length in bytes. Two checks are
  needed here:
  - `ip_header_len < sizeof(*ip)` rejects a header shorter than the minimum
    valid IPv4 header (a corrupt or malicious `ihl` value).
  - `(char *)ip + ip_header_len > data_end` makes sure that skipping past
    any IP options still stays inside the packet, before touching TCP.
  Without this, TCP parsing would silently assume a fixed 20-byte IPv4
  header and could read out of bounds (or be rejected by the verifier)
  as soon as a packet carries IP options.
- **`struct tcphdr`**: placed right after the (variable-length) IPv4 header.
  The same bounds-check pattern as before applies: `(tcp + 1) > data_end`
  before reading any field of it.
- **VIP filtering**: `ip->daddr` and `tcp->dest` are both in network byte
  order, hence `bpf_htonl(LB_VIP)` and `bpf_htons(8080)`. `LB_VIP` is
  defined as `0x0AC80064`, which is `10.200.0.100` in hex. This condition
  isolates traffic addressed to the load balancer's virtual IP on port
  8080, independently of which backend will eventually serve it.
- **ICMP now passes through**: dropping ICMP was only useful in step 1 to
  confirm the program was active. Now that TCP filtering is in place, ICMP
  is allowed again so the lab's connectivity checks (`ping`) reflect normal
  reachability rather than an artificial block.

## Observed behavior in the lab

Backend HTTP servers were started in each server namespace:

```bash
sudo ip netns exec srv1 \
    python3 -m http.server 8080 \
    --bind 0.0.0.0 \
    --directory "$(pwd)/lab/www/srv1"

sudo ip netns exec srv2 \
    python3 -m http.server 8080 \
    --bind 0.0.0.0 \
    --directory "$(pwd)/lab/www/srv2"
```

Test results with the program loaded on `lb-front`:

| Command | Result |
| --- | --- |
| `sudo ip netns exec client ping 10.201.0.2` | OK — ICMP passes through again |
| `sudo ip netns exec client curl http://10.201.0.2:8080` | OK — direct backend access works |
| `sudo ip netns exec client curl http://10.202.0.2:8080` | OK — direct backend access works |
| `sudo ip netns exec client curl http://10.200.0.100:8080` | Fails — traffic to the VIP:8080 is dropped |

This is the expected behavior at this stage: the VIP:8080 rule currently
only *drops* matching traffic, it does not yet redirect it to a backend. So
direct requests to `srv1`/`srv2` succeed, while requests to the VIP are
blocked outright — this confirms the matching condition (`daddr` + `dest`)
correctly isolates VIP traffic, before the next step wires it to an actual
backend instead of a drop.
