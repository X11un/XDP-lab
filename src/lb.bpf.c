#include <linux/bpf.h>
#include <linux/if_ether.h>
#include <linux/ip.h>
#include <linux/in.h>
#include <linux/tcp.h>

#include <bpf/bpf_helpers.h>
#include <bpf/bpf_endian.h>


#define LB_VIP 0x0AC80064                       // 10.200.0.100

SEC("xdp")
int xdp_lb(struct xdp_md *ctx){
    
    void *data = (void *)(long)ctx->data;
    void *data_end = (void *)(long)ctx->data_end;


// Parser Ethernet    
    struct ethhdr *eth = data;

    if ((void*)(eth + 1) > data_end)
        return XDP_ABORTED;

    if (eth->h_proto != bpf_htons(ETH_P_IP))    // h_proto network byte order big-endian
        return XDP_PASS;


// IPV4    
    struct iphdr *ip = (void *)(eth + 1);       // Header IPV4 after Ethernet

    if ((void *)(ip + 1) > data_end)            // Bounds check if exceed data_end stop
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