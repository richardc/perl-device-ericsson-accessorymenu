#!perl -w
use strict;
use Test::More tests => 2;

my $pkg = 'Device::T68i::Remote';
use_ok('Device::T68i::Remote');
my $remote = Device::T68i::Remote->new;

isa_ok( $remote, $pkg );

$remote->menu( [
    'Remote' => [
        pause => sub { print "# paused\n" },
        Volume => [
            up   => sub { print "# vol +\n" },
            down => sub { print "# vol -\n" },
           ],
       ],
   ]);

$remote->port( bless {}, 'DummyPort' );

$remote->register_menu;

$remote->send_menu;

package DummyPort;
sub write {
    my ($self, $what) = @_;
    print "# wrote '$what'\n";
    return length $what;
}

