use strict;
package Device::Ericsson::AccessoryMenu::Menu;
use base 'Device::Ericsson::AccessoryMenu::State';
__PACKAGE__->mk_accessors( qw( menu selected ) );

sub on_enter {
    my $self = shift;
    my $selected = $self->selected || 1;

    my $name   = $self->menu->[0];
    my @pairs  = $self->_get_pairs;
    my $titles = join ',', map { qq{"$_->[0]"} } @pairs;
    my $length = scalar @pairs;
    $self->parent->send( qq{AT*EASM="$name",1,$selected,$length,$titles} );
    $self->parent->expect( 'OK' );
}

sub handle {
    my $self = shift;
    my $line = shift;

    if ($line =~ /EAMI: (\d+)/) { # menu item
        my $item = $1;
        if ($item == 0) { # back up
            $self->parent->exit_state;
            return;
        }

        my @pairs = $self->_get_pairs;
        unshift @pairs, []; # dummy one so the offsets all work out
        my ($name, $action) = @{ $pairs[ $item ] };

        $self->selected( $item );
        print "invoking $item: $action\n";
        $action = $action->( $self ) if ref $action eq 'CODE';
        if (ref $action eq 'ARRAY') { # wander down
            $self->parent->enter_state( 'Menu', menu => [ $name => $action ] );
            return;
        }
        if (defined $action && !ref $action) {
            $self->parent->enter_state( 'Text', ( title => $name,
                                                  text  => $action ) );
            return;
        }
        # update and resend
        $self->on_enter;
    }
}

sub _get_pairs {
    my $self = shift;

    my @menu = @{ $self->menu };
    my @entries = @{ $menu[1] };
    my @pairs;
    while (@entries) {
        push @pairs, [ shift @entries, shift @entries ];
    }
    print map { "$_->[0]: $_->[1]\n"} @pairs
      if $self->parent->debug;
    return @pairs;
}

1;

