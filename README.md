# XDP-lab

Small experimental XDP/eBPF load-balancing laboratory.

The goal of this project is to build a Layer 4 load balancer step by step using Linux XDP and eBPF.

## Lab topology

```text
                  VIP
             10.200.0.100
                   |
                   |
client -------- load balancer
10.200.0.2     10.200.0.1
                  /   \
                 /     \
                /       \
        10.201.0.2     10.202.0.2
           srv1           srv2
```

## Start the lab
`make lab-up`

## Check the lab
`make lab-status`

## Test connectivity
`make lab-test`

## Destroy the lab
`make lab-down`

## Documentation

The project moves forward in small incremental steps (packet parsing,
filtering, then full L4 load-balancing). Each step is documented in the
[`docs/`](docs/) folder, with the corresponding code, the behavior observed
in the lab, and the commands used to verify it.

- [docs/01-ethernet-ipv4-parsing.md](docs/01-ethernet-ipv4-parsing.md) —
  Ethernet/IPv4 parsing and first filtering rule (ICMP drop)