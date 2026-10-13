"""What may exist at the same address and prefix length?

Inside one layer3domain exactly one combination may share an address and
prefix length: a Container and a Subnet, with the Container as the Subnet's
parent (ITOUDP-5900). Every other combination of statuses is rejected. Across
layer3domains a block may be duplicated if it falls inside
LAYER3DOMAIN_WHITELIST. v4 and v6 blocks never collide, even at prefix 0 where
both have address 0.

Every assertion here also pins down *who* rejects the duplicate. All of DIM's
own errors derive from DimError, so requiring DimError means the application
refused with a message a user can act on -- as opposed to a SQLAlchemy
IntegrityError, which is the uniqueness constraint firing and leaking raw SQL
into the API response. The constraint is a backstop; it should never be what
the user sees.
"""
import pytest

from dim.errors import DimError
from dim.ipaddr import IP
from dim.models import db, Ipblock, Layer3Domain
from tests.util import RPCTest, raises


# Statuses a non-host block can have. Available and Static are excluded: they
# are only valid on host addresses, and Container, Subnet and Delegation are
# only valid on non-host blocks, so the two groups can never meet at the same
# prefix length.
NON_HOST_STATUSES = ['Container', 'Subnet', 'Reserved', 'Dynamic', 'Discovered']

CIDR = '10.1.0.0/24'
PARENT = '10.0.0.0/8'


class SameSizeTest(RPCTest):
    def setUp(self):
        RPCTest.setUp(self)
        # Subnet and Delegation are only valid underneath a Container. This one
        # is strictly larger than CIDR, so it never collides with it.
        self.r.ipblock_create(PARENT, status='Container', layer3domain='default')

    def make(self, status, cidr=CIDR, layer3domain='default'):
        '''Create a block of *status* at *cidr* through the API a user would use.'''
        if status == 'Subnet':
            pool = 'pool_%s' % layer3domain
            if not self.r.ippool_list(pool):
                self.r.ippool_create(pool, layer3domain=layer3domain)
            self.r.ippool_add_subnet(pool, cidr, dont_reserve_network_broadcast=True)
        elif status == 'Delegation':
            pool = 'dpool_%s' % layer3domain
            if not self.r.ippool_list(pool):
                self.r.ippool_create(pool, layer3domain=layer3domain)
                self.r.ippool_add_subnet(pool, cidr, dont_reserve_network_broadcast=True)
            self.r.ippool_get_delegation(pool, int(cidr.split('/')[1]))
        else:
            self.r.ipblock_create(cidr, status=status, layer3domain=layer3domain)

    def tree(self, cidr=CIDR, layer3domain='default'):
        '''(status, ip) of every block below the PARENT container, depth first.'''
        def walk(node):
            yield node['status'], node['ip']
            for child in node.get('children', []):
                if child['status'] != 'Available':
                    yield from walk(child)
        return list(walk(self.r.container_list(PARENT, layer3domain=layer3domain)[0]))

    def test_only_container_and_subnet_share_a_size(self):
        '''Only a Container and a Subnet may share address and prefix length.

        Checked for every ordered pair of statuses, because the two directions
        go through different code: ipblock_create() looks for an existing block
        at the address, while ippool_add_subnet() complains about the status of
        the block it found.
        '''
        for first in NON_HOST_STATUSES:
            for second in NON_HOST_STATUSES:
                self.tearDown()
                self.setUp()
                self.make(first)
                if {first, second} == {'Container', 'Subnet'}:
                    self.make(second)
                else:
                    with raises(DimError):
                        self.make(second)

    def test_subnet_is_child_of_same_size_container(self):
        '''Container first, then the Subnet: the Subnet goes below the Container.'''
        self.make('Container')
        self.make('Subnet')
        assert self.tree() == [('Container', PARENT), ('Container', CIDR), ('Subnet', CIDR)]

    def test_container_is_inserted_above_same_size_subnet(self):
        '''Subnet first, then the Container: the Container goes between.'''
        self.make('Subnet')
        self.make('Container')
        assert self.tree() == [('Container', PARENT), ('Container', CIDR), ('Subnet', CIDR)]

    def test_lookups_by_status(self):
        '''With a Container and a Subnet at one CIDR, the status picks the block.'''
        self.make('Container')
        self.make('Subnet')
        self.r.ipblock_set_attrs(CIDR, {'c': 'container'}, layer3domain='default', status='Container')
        self.r.ipblock_set_attrs(CIDR, {'s': 'subnet'}, layer3domain='default', status='Subnet')
        container = self.r.ipblock_get_attrs(CIDR, layer3domain='default', status='Container')
        subnet = self.r.ipblock_get_attrs(CIDR, layer3domain='default', status='Subnet')
        assert container['status'] == 'Container' and container['c'] == 'container' and 's' not in container
        assert subnet['status'] == 'Subnet' and subnet['s'] == 'subnet' and 'c' not in subnet
        # without a status the inner, more specific block is meant
        assert self.r.ipblock_get_attrs(CIDR, layer3domain='default')['status'] == 'Subnet'

    def test_addresses_of_same_size_subnet(self):
        '''Addresses go below the Subnet, not below the Container.'''
        self.make('Container')
        self.make('Subnet')
        ip = self.r.ippool_get_ip('pool_default')
        assert ip['subnet'] == CIDR
        assert self.r.ipblock_get_attrs(ip['ip'], layer3domain='default')['pool'] == 'pool_default'

    def test_remove_same_size_subnet_keeps_container(self):
        self.make('Container')
        self.make('Subnet')
        self.r.ipblock_remove(CIDR, pool='pool_default', status='Subnet', layer3domain='default')
        assert self.tree() == [('Container', PARENT), ('Container', CIDR)]

    def test_container_may_repeat_in_another_layer3domain(self):
        '''Whitelisted space may exist once per layer3domain.'''
        self.r.layer3domain_create('other', 'vrf', rd='8560:2')
        self.r.ipblock_create(PARENT, status='Container', layer3domain='other',
                              allow_overlap=True)
        self.make('Container', layer3domain='default')
        self.make('Container', layer3domain='other')
        for layer3domain in ('default', 'other'):
            attrs = self.r.ipblock_get_attrs(CIDR, layer3domain=layer3domain)
            assert attrs['status'] == 'Container'
            assert attrs['layer3domain'] == layer3domain

    def test_same_size_pair_in_two_layer3domains(self):
        '''The Container/Subnet pair is a per-layer3domain matter.'''
        self.r.layer3domain_create('other', 'vrf', rd='8560:2')
        self.r.ipblock_create(PARENT, status='Container', layer3domain='other',
                              allow_overlap=True)
        self.make('Container', layer3domain='default')
        self.make('Subnet', layer3domain='default')
        self.make('Container', layer3domain='other')
        # a Subnet overlapping another layer3domain still needs allow_overlap
        with raises(DimError):
            self.make('Subnet', layer3domain='other')
        self.r.ippool_add_subnet('pool_other', CIDR, allow_overlap=True)
        assert self.tree(layer3domain='other') == [('Container', PARENT), ('Container', CIDR), ('Subnet', CIDR)]
        assert self.tree(layer3domain='default') == [('Container', PARENT), ('Container', CIDR), ('Subnet', CIDR)]

    def test_overlapping_subnet_in_another_layer3domain_is_refused_by_default(self):
        self.r.layer3domain_create('other', 'vrf', rd='8560:2')
        self.r.ipblock_create(PARENT, status='Container', layer3domain='other',
                              allow_overlap=True)
        self.make('Subnet', layer3domain='default')
        with raises(DimError):
            self.make('Subnet', layer3domain='other')

    def test_v4_and_v6_default_route_coexist(self):
        '''0.0.0.0/0 and ::/0 both have address 0 and prefix 0.

        They are different blocks and must both be creatable in one
        layer3domain; only the ip version tells them apart.
        '''
        self.r.ipblock_create('0.0.0.0/0', status='Container', layer3domain='default')
        self.r.ipblock_create('::/0', status='Container', layer3domain='default')
        assert self.r.ipblock_get_attrs('0.0.0.0/0', layer3domain='default')['status'] == 'Container'
        assert self.r.ipblock_get_attrs('::/0', layer3domain='default')['status'] == 'Container'

    def test_host_cannot_be_allocated_twice(self):
        self.make('Subnet')
        self.r.ip_mark('10.1.0.5', layer3domain='default')
        with raises(DimError):
            self.r.ip_mark('10.1.0.5', layer3domain='default')

    def test_delegation_cannot_fill_its_whole_subnet(self):
        '''A Delegation as large as its parent Subnet is never handed out.

        The allocator finds no such block (see also
        allocator_test.test_delegation_not_subnet), and creating one directly is
        rejected with a DIM error.'''
        self.make('Subnet')
        assert self.r.ippool_get_delegation('pool_default', 24) == []
        with raises(DimError):
            self.r.ipblock_create(CIDR, status='Delegation', layer3domain='default')

    def test_subnet_needs_a_container(self):
        '''A Subnet outside of any Container is rejected.'''
        self.r.ippool_create('lonely', layer3domain='default')
        with pytest.raises(Exception, match='has no parent container'):
            self.r.ippool_add_subnet('lonely', '192.168.0.0/24')

    def test_no_single_address_container_or_subnet(self):
        '''/32 and /128 Containers and Subnets are rejected.'''
        with pytest.raises(Exception, match='only one IP'):
            self.r.ipblock_create('10.2.0.1/32', status='Container', layer3domain='default')
        self.r.ippool_create('hosts', layer3domain='default')
        with pytest.raises(Exception, match='only one IP'):
            self.r.ippool_add_subnet('hosts', '10.2.0.1/32')

    def test_rebuild_tree_keeps_the_pair(self):
        """manage_dim rebuild_tree puts the Subnet below its same-size Container."""
        self.make('Container')
        self.make('Subnet')
        ip = self.r.ippool_get_ip('pool_default')['ip']
        default = Layer3Domain.query.filter_by(name='default').one()
        # break every parent pointer, then let the tree be rebuilt from scratch
        Ipblock.query.filter_by(layer3domain=default).update({'parent_id': None})
        db.session.commit()
        Ipblock.build_tree_parents(default, 4)
        db.session.commit()
        assert self.tree() == [('Container', PARENT), ('Container', CIDR), ('Subnet', CIDR)]
        static = Ipblock.query_ip(IP(ip), default).one()
        assert static.parent.status.name == 'Subnet' and str(static.parent.ip) == CIDR
