"""What may exist at the same address and prefix length?

Short answer, as of this commit: inside one layer3domain, nothing may share an
address and prefix length with anything else, in any combination of statuses.
Across layer3domains a block may be duplicated if it falls inside
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

    def test_nothing_shares_a_size_within_one_layer3domain(self):
        '''No two blocks may share address and prefix length in one layer3domain.

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
                with raises(DimError):
                    self.make(second)

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

    @pytest.mark.xfail(reason='the uniqueness constraint rejects this, not the '
                              'application: the user gets a raw '
                              'MySQLdb.IntegrityError instead of a message',
                       strict=True)
    def test_delegation_cannot_fill_its_whole_subnet(self):
        '''A delegation as large as its parent subnet has the parent's address.

        Whether that should be allowed at all is a separate question -- see the
        module docstring of the delegation documentation. What is not
        acceptable either way is the current behaviour: nothing checks it, so
        the uniqueness constraint fires and the raw database error reaches the
        caller.
        '''
        self.make('Subnet')
        with raises(DimError):
            self.r.ippool_get_delegation('pool_default', 24)
