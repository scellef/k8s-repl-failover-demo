# Overview

**Unseal cluster** -- One-node dev cluster used for Transit auto-unseal
**North cluster** -- Three-node Raft cluster used (initially) for DR/Perf Primary
**West cluster** -- Three-node Raft cluster used for DR Secondary
**East cluster** -- Three-node Raft cluster used for Performance Secondary

# Workflow

1. `setup.sh`
  1. Setup unseal cluster
  1. Setup replication clusters
    1. Enable DR/Perf primary
    1. Enable DR secondary
    1. Enable Perf secondary
1. Demote primary, promote DR secondary
1. Demote DR secondary, promote primary
1. Split-head

# Scripts

* `setup.sh`
* `generate-dr-token.sh`
* `generate-root-token.sh`
* `failover.sh`
* `split-head.sh`
* `status.sh`
* `cleanup.sh`
