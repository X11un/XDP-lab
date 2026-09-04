#include <linux/bpf.h>
#include <linux/if_ether.h>
#include <linux/ip.h>
#include <linux/in.h>

#include <bpf/bpf_helpers.h>
#include <bpf/bpf_endian.h>


// Parser Ethernet & IPV4

SEC("xdp")
int xdp_lb(struct xdp_md *ctx){
    
    void *data = (void *)(long)ctx->data;
    void *data_end = (void *)(long)ctx->data_end;

    struct ethhdr *eth = data;

    if ((void*)(eth + 1) > data_end)
        return XDP_ABORTED;

    if (eth->h_proto != bpf_htons(ETH_P_IP))    // h_proto network byte order big-endian
        return XDP_PASS;


    struct iphdr *ip = (void *)(eth + 1);       // Header IPV4 after Ethernet

    if ((void *)(ip + 1) > data_end)            // Bounds check if exceed data_end stop
        return XDP_ABORTED;

    if (ip->protocol == IPPROTO_ICMP)           // 1 = ICMP
        return XDP_DROP;


    return XDP_PASS;
}


char LICENSE[] SEC("license") = "GPL";