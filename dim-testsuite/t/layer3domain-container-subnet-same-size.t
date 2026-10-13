# ITOUDP-5900: the same-size Container/Subnet pair is a per-layer3domain
# matter; the overlap rules between layer3domains stay as they are.
$ ndcli create layer3domain two type vrf rd 0:2

$ ndcli create container 10.0.0.0/8 layer3domain default
INFO - Creating container 10.0.0.0/8 in layer3domain default
$ ndcli create container 10.0.0.0/8 layer3domain two
INFO - Creating container 10.0.0.0/8 in layer3domain two

$ ndcli create container 10.1.0.0/24 layer3domain default
INFO - Creating container 10.1.0.0/24 in layer3domain default
$ ndcli create container 10.1.0.0/24 layer3domain two
INFO - Creating container 10.1.0.0/24 in layer3domain two

$ ndcli create pool p layer3domain default
$ ndcli create pool p2 layer3domain two
$ ndcli modify pool p add subnet 10.1.0.0/24
INFO - Created subnet 10.1.0.0/24 in layer3domain default
WARNING - Creating zone 0.1.10.in-addr.arpa without profile
WARNING - Primary NS for this Domain is now localhost.
$ ndcli modify pool p2 add subnet 10.1.0.0/24
ERROR - 10.1.0.0/24 in layer3domain two would overlap with 10.1.0.0/24 in layer3domain default
$ ndcli modify pool p2 add subnet 10.1.0.0/24 --allow-overlap
INFO - Created subnet 10.1.0.0/24 in layer3domain two
WARNING - 10.1.0.0/24 in layer3domain two overlaps with 10.1.0.0/24 in layer3domain default
INFO - Creating view two in zone 0.1.10.in-addr.arpa without profile

$ ndcli list containers layer3domain two 10.1.0.0/24
layer3domain: two
10.1.0.0/24 (Container)
  10.1.0.0/24 (Subnet) pool:p2
$ ndcli list containers layer3domain default 10.1.0.0/24
layer3domain: default
10.1.0.0/24 (Container)
  10.1.0.0/24 (Subnet) pool:p

$ ndcli modify pool p2 get ip
created:2026-10-13 12:00:00
ip:10.1.0.1
layer3domain:two
mask:255.255.255.0
modified:2026-10-13 12:00:00
modified_by:admin
pool:p2
reverse_zone:0.1.10.in-addr.arpa
status:Static
subnet:10.1.0.0/24

# without a layer3domain the address is ambiguous
$ ndcli show subnet 10.1.0.0/24
ERROR - A layer3domain is needed
$ ndcli show subnet 10.1.0.0/24 layer3domain two
created:2026-10-13 12:00:00
ip:10.1.0.0/24
layer3domain:two
mask:255.255.255.0
modified:2026-10-13 12:00:00
modified_by:admin
pool:p2
reverse_zone:0.1.10.in-addr.arpa
status:Subnet
