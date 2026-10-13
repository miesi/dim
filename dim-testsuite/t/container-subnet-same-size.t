# ITOUDP-5900 / ITOUDP-5905: a Subnet may have exactly the size of its
# Container. Everything else at the same size stays forbidden.
$ ndcli create container 192.168.0.0/16 layer3domain default
INFO - Creating container 192.168.0.0/16 in layer3domain default

# use case: a /24 handed out as a whole and configured as one /24 on an irb
$ ndcli create container 192.168.178.0/24 layer3domain default comment:FritzBox
INFO - Creating container 192.168.178.0/24 in layer3domain default
$ ndcli create pool fritzbox layer3domain default
$ ndcli modify pool fritzbox add subnet 192.168.178.0/24 gw 192.168.178.1
INFO - Created subnet 192.168.178.0/24 in layer3domain default
WARNING - Creating zone 178.168.192.in-addr.arpa without profile
WARNING - Primary NS for this Domain is now localhost.

$ ndcli list containers layer3domain default 192.168.178.0/24
layer3domain: default
192.168.178.0/24 (Container) comment:FritzBox
  192.168.178.0/24 (Subnet) pool:fritzbox

$ ndcli show container 192.168.178.0/24 layer3domain default
comment:FritzBox
created:2026-10-13 12:58:55
ip:192.168.178.0/24
layer3domain:default
modified:2026-10-13 12:00:00
modified_by:admin
status:Container

# DIM does not reserve the gateway: get ip hands it out like any other address
$ ndcli modify pool fritzbox get ip
created:2026-10-13 12:00:00
gateway:192.168.178.1
ip:192.168.178.1
layer3domain:default
mask:255.255.255.0
modified:2026-10-13 12:00:00
modified_by:admin
pool:fritzbox
reverse_zone:178.168.192.in-addr.arpa
status:Static
subnet:192.168.178.0/24

# use case: a routed transit link, documented as the /31 it is
$ ndcli create container 192.168.232.0/31 layer3domain default "comment:transit xy"
INFO - Creating container 192.168.232.0/31 in layer3domain default
$ ndcli create pool transit-xy layer3domain default
$ ndcli modify pool transit-xy add subnet 192.168.232.0/31 --no-default-reserve
INFO - Created subnet 192.168.232.0/31 in layer3domain default
WARNING - Creating zone 232.168.192.in-addr.arpa without profile
WARNING - Primary NS for this Domain is now localhost.

# the other order: the Container is added later around an existing Subnet
$ ndcli create pool later layer3domain default
$ ndcli modify pool later add subnet 192.168.10.0/24
INFO - Created subnet 192.168.10.0/24 in layer3domain default
WARNING - Creating zone 10.168.192.in-addr.arpa without profile
WARNING - Primary NS for this Domain is now localhost.
$ ndcli create container 192.168.10.0/24 layer3domain default
INFO - Creating container 192.168.10.0/24 in layer3domain default
$ ndcli list containers layer3domain default 192.168.10.0/24
layer3domain: default
192.168.10.0/24 (Container)
  192.168.10.0/24 (Subnet) pool:later

# the reverse_dns_profile of the same-size Container applies to the Subnet
$ ndcli create zone-profile rev primary ns.example.test. mail hostmaster@example.test
$ ndcli create container 192.168.50.0/24 layer3domain default reverse_dns_profile:rev
INFO - Creating container 192.168.50.0/24 in layer3domain default
$ ndcli create pool withprofile layer3domain default
$ ndcli modify pool withprofile add subnet 192.168.50.0/24
INFO - Created subnet 192.168.50.0/24 in layer3domain default
INFO - Creating zone 50.168.192.in-addr.arpa with profile rev

# still forbidden: two Containers, two Subnets, a Delegation of the size of its
# Subnet, single-address Containers and Subnets, a Subnet without a Container
$ ndcli create container 192.168.178.0/24 layer3domain default
ERROR - 192.168.178.0/24 already exists in layer3domain default with status Container
$ ndcli create pool other layer3domain default
$ ndcli modify pool other add subnet 192.168.178.0/24
ERROR - The subnet '192.168.178.0/24' from layer3domain 'default' cannot be added to the pool 'other' because it is part of the pool 'fritzbox'
$ ndcli modify pool fritzbox get delegation 24
ERROR - No suitable blocks found
$ ndcli create container 192.168.20.1/32 layer3domain default
ERROR - Creating Container blocks with only one IP addresss is not allowed
$ ndcli modify pool other add subnet 192.168.20.1/32
ERROR - Creating Subnet blocks with only one IP addresss is not allowed
$ ndcli modify pool other add subnet 172.16.0.0/24
ERROR - Subnet 172.16.0.0/24 has no parent container

# removing the Subnet keeps the Container
$ ndcli modify pool transit-xy remove subnet 192.168.232.0/31
INFO - Deleting zone 232.168.192.in-addr.arpa
$ ndcli list containers layer3domain default 192.168.232.0/31
layer3domain: default
192.168.232.0/31 (Container) comment:transit xy
  192.168.232.0/31 (Available)

# deleting the Container leaves the Subnet below the next Container up
$ ndcli delete container 192.168.10.0/24 layer3domain default
INFO - Deleting container 192.168.10.0/24 from layer3domain default
$ ndcli show subnet 192.168.10.0/24 layer3domain default
created:2026-10-13 12:00:00
ip:192.168.10.0/24
layer3domain:default
mask:255.255.255.0
modified:2026-10-13 12:00:00
modified_by:admin
pool:later
reverse_zone:10.168.192.in-addr.arpa
status:Subnet
