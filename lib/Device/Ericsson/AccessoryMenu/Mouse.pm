use strict;
package Device::Ericsson::AccessoryMenu::Mouse;
use base 'Device::Ericsson::AccessoryMenu::State';
__PACKAGE__->mk_accessors( qw( callback ) );

sub on_enter {
    die "";

    my $title = $args{title} || 'Mouse';
    # show the user a dialog they can quit from
    $self->send( qq{AT*EAID=13,2,"$title"} );
    $self->expect( 'OK' );
    # and put them into Event Reporting mode.
    $self->send( qq{AT+CMER=3,2,0,0,0} );
    $self->expect( 'OK' );
}

sub on_exit {
    my $self = shift;

    # reset spy mode
    $self->parent->send( qq{AT+CMER=0,0,0,0,0} );
    $self->parent->expect( 'OK' );
}

sub handle {
    my $self = shift;
    my $line = shift;

    my $upup = 0;
    if ($got =~ /\+CKEV: (?:(.),(.))?/) {
        my ($key, $updown) = ($1, $2);
        unless (defined $key) {
            # this seems glitchy on my phone. oh well - hack it
            $key    = "^";
            $updown = $upup ^= 1;
        }
        $args{callback}->($key, $updown) if $args{callback};
    }
    if ($got =~ /\*EAII/) { # backup
        $self->parent->exit_state;
        return;
    }
}

1;
