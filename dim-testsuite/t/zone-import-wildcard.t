# ITOUDP-7962: a wildcard A/AAAA record in an imported zone must be imported
# without its PTR (with a warning) instead of being dropped with
# "Invalid ptrdname".
$ ndcli create container 10.0.0.0/8 layer3domain default
INFO - Creating container 10.0.0.0/8 in layer3domain default
$ ndcli create pool p layer3domain default
$ ndcli modify pool p add subnet 10.0.0.0/24
INFO - Created subnet 10.0.0.0/24 in layer3domain default
WARNING - Creating zone 0.0.10.in-addr.arpa without profile
WARNING - Primary NS for this Domain is now localhost.

$ cat <<EOF | ndcli import zone example.test
example.test.           600 IN SOA ns.example.test. hostmaster.example.test. 2026101301 600 180 604800 600
example.test.           600 IN NS  ns.example.test.
ns.example.test.        600 IN A   10.0.0.2
*.client.example.test.  600 IN A   10.0.0.5
*.client.example.test.  600 IN AAAA 2001:db8::5
EOF
INFO - Creating zone example.test
RECORD - example.test. 600 IN SOA ns.example.test. hostmaster.example.test. 2026101301 600 180 604800 600
INFO - Creating RR @ SOA ns.example.test. hostmaster.example.test. 2026101301 600 180 604800 600 in zone example.test
RECORD - ns.example.test. 600 IN A 10.0.0.2
INFO - Marked IP 10.0.0.2 from layer3domain default as static
INFO - Creating RR ns A 10.0.0.2 in zone example.test
INFO - Creating RR 2 PTR ns.example.test. in zone 0.0.10.in-addr.arpa
RECORD - example.test. 600 IN NS ns.example.test.
INFO - Creating RR @ NS ns.example.test. in zone example.test
RECORD - *.client.example.test. 600 IN A 10.0.0.5
WARNING - Not creating a PTR record for the wildcard record *.client.example.test.
INFO - Marked IP 10.0.0.5 from layer3domain default as static
INFO - Creating RR *.client A 10.0.0.5 in zone example.test
RECORD - *.client.example.test. 600 IN AAAA 2001:db8::5
WARNING - Not creating a PTR record for the wildcard record *.client.example.test.
INFO - Marked IP 2001:db8::5 from layer3domain default as static
INFO - Creating RR *.client AAAA 2001:db8::5 in zone example.test

$ ndcli list zone example.test
record    zone         ttl   type  value
@         example.test 600   SOA   ns.example.test. hostmaster.example.test. 2026101301 600 180 604800 600
@         example.test       NS    ns.example.test.
*.client  example.test       A     10.0.0.5
*.client  example.test       AAAA  2001:db8::5
ns        example.test       A     10.0.0.2

$ ndcli list zone 0.0.10.in-addr.arpa
record zone                ttl   type value
@      0.0.10.in-addr.arpa 86400 SOA  localhost. hostmaster.0.0.10.in-addr.arpa. 2026101301 14400 3600 605000 86400
2      0.0.10.in-addr.arpa       PTR  ns.example.test.
