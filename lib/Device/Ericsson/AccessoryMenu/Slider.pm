use strict;
package Device::Ericsson::AccessoryMenu::Slider;
use base 'Device::Ericsson::AccessoryMenu::State';
__PACKAGE__->mk_accessors( 'callback' );

sub handle {
    my $self = shift;
    my $line = shift;

    if ($line =~ /^\*EAII: 15,(\d+)$/) {
        my $value = $1;
        $self->callback($value) if $self->callback;
        return;
    }
    if ($line =~ /\*EAII: [04]/) {
        $self->parent->exit_state;
        return;
    }
    warn "Slider got unexpected 'line'\n" if $self->parent->debug;
}

1;
