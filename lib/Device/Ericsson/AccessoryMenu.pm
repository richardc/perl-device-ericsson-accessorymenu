use strict;
package Device::Ericsson::AccessoryMenu;
use base 'Class::Accessor::Fast';
__PACKAGE__->mk_accessors( qw( parents current_menu menu port ) );
use vars qw( $VERSION );
$VERSION = '0.5';

use constant debug => 0;

=head1 NAME

Device::Ericsson::AccessoryMenu - allows use of a T68i as a remote control

=head1 SYNOPSIS

 my $remote = Device::Ericsson::AccessoryMenu->new;
 $remote->menu( [ 'Remote' => [ pause  => sub { ... },
                                Volume => [ up   => sub { ... },
                                            down => sub { ... },
                                          ],
                              ],
                ] );

 # on Win32, Win32::SerialPort should be equivalent
 my $port = Device::SerialPort->new('/dev/rfcomm0')
    or die "couldn't connect to T68i";
 $remote->port( $port );

 $remote->register_menu;

 while (1) {
     $remote->control;
 }

=head1 DESCRIPTION

Device::Ericsson::AccessoryMenu provides a framework for adding an
accessory menu to devices that obey the EAM set of AT commands.

This allows you to write programs with similar function to the Romeo
and Clicker applications for OSX, only instead of applescript your
actions invoke perl subroutines (which of course may invoke
applescript events, if that's your desire).

=head1 METHODS

=head2 new

=cut

sub new {
    my $class = shift;
    $class->SUPER::new({ menu => [] });
}

=head2 menu

your menus and actions.

If your action is a subroutine, it will be invoked with the
Device::Ericsson::AccesoryMenu object as its first parameter.

If the action returns a scalar, this is sent on to the phone via
C<send_text>

If your action is, or returns an array reference, then it's taken as a
sub menu.

=head2 port

The serial port to communicate over.

This may be real serial port, or a bluetooth RFCOMM device, just so
long as it looks like a Device::SerialPort or Win32::SerialPort.

=head2 send( $what )

send bytes over the serial port to the phone

=cut

sub send {
    my $self = shift;
    my $what = shift;
    my $count = $self->port->write( "$what\r" );
    $self->port->write_drain;
    print "# send '$what'\n" if debug;
    return $count == length $what;
}

=head2 expect( $what, $timeout )

expects something from the other end

=cut

# lifted from Device::Modem
sub expect {
    my $self = shift;
    my ($expect, $timeout) = @_;

    $timeout ||= 0;
    $timeout = 2000 if $timeout < 2000;

    my $time_slice = 100;                       # single cycle wait time
    my $max_cycles = $timeout / $time_slice;
    my $max_idle_cycles = $max_cycles;

    # If we expect something, we must first match against serial input
    my $done;# = (defined $expect and $expect eq '');

    # Main read cycle
    my ($answer, $cycles, $idle_cycles);
    do {
        my ($howmany, $what) = $self->port->read(100);

        # Timeout count incremented only on empty readings
        if ( defined $what && $howmany > 0 ) {
            $answer .= $what;
            $idle_cycles = 1;
            $max_idle_cycles = 3;
        }
        else {
            ++$idle_cycles;
        }

        ++$done if $expect && $answer && $answer =~ $expect;
        ++$done if $idle_cycles >= $max_idle_cycles;
        ++$done if ++$cycles >= $max_cycles;
        select(undef, undef, undef, $time_slice/1000) unless $done;
    } while ( not $done );

    # Flush receive and trasmit buffers
    $self->port->purge_all;

    # Trim result of beginning and ending CR+LF (XXX)
    if( defined $answer ) {
        $answer =~ s/^[\r\n]+//;
        $answer =~ s/[\r\n]+$//;
    }
    print "# got '$answer'\n" if debug && defined $answer;
    return $answer;
}


=head2 register_menu

Notify the phone that there's an accessory connected

=cut

sub register_menu {
    my $self = shift;

    $self->parents( [] );
    $self->current_menu( $self->menu );

    $self->send( "ATZ" );
    $self->expect( "OK", 5000 );
    $self->send( "ATE=0" );
    $self->expect( "OK" );
    $self->send( 'AT*EAM="'. $self->menu->[0] . '"' );
    $self->expect( "OK" );
}

=head2 send_menu( $selected )

Dump the current menu to the phone

=cut

sub send_menu {
    my $self = shift;
    my $selected = shift || 1;

    my @menu = @{ $self->current_menu };
    my $c;
    my @titles = grep { ++$c % 2 == 1 } @{ $menu[1] };
    my $titles = join ',', map { qq{"$_"} } @titles;
    my $length = scalar @titles;
    $self->send( qq{AT*EASM="$menu[0]",1,$selected,$length,$titles} );
    $self->expect( 'OK' );
}

=head2 send_text( $title, @lines )

Send the text as a message dialog and wait for user input.

=cut

sub send_text {
    my $self = shift;
    my $title = shift;
    @_ = ($title) unless @_;

    $self->send( join ',', qq{AT*EAID=14,2,"$title"}, map { qq{"$_"} } @_ );
    $self->expect( 'OK' );
    do {} while !$self->expect;
}

=head2 control

Respond to what the phone is sending back over the port, invoking
callbacks and all that jazz.

=cut

sub control {
    my $self = shift;

    my $line = $self->expect;
    return unless $line;

    print "# control '$line'\n" if debug;

    if ($line =~ /EAAI/) { # top level menu
        $self->send_menu;
    }

    if ($line =~ /EAMI: (\d+)/) { # menu item
        my $item = $1;
        if ($item == 0) { # back up
            my $up = pop @{ $self->parents } or return;
            $self->current_menu( $up->[0] );
            $self->send_menu( $up->[1] );
            return;
        }

        my @menu = @{ $self->current_menu->[1] };
        my @pairs = [];
        while (@menu) {
            push @pairs, [ shift @menu, shift @menu ];
        }
        my ($name, $action) = @{ $pairs[ $item ] };

        $action = $action->( $self ) if ref $action eq 'CODE';
        if (ref $action eq 'ARRAY') { # wander down
            push @{ $self->parents }, [ $self->current_menu, $item ];
            $self->current_menu( [ $name => $action ] );
            $item = 1;
        }
        $self->send_text( $name, $action ) if defined $action && !ref $action;
        $self->send_menu($item);
    }
}

1;
__END__

=head1 CAVEATS

I have only tested this with a T68i, and with Device::SerialPort.
I've consulted the R320 command set, and this seems portable across
Ericsson devices, but only time will tell.  Feedback welcome.

=head1 TODO

Convenience methods for other C<EAID> values, like the percent input
dialog.

=head1 AUTHOR

Richard Clamp <richardc@unixbeard.net>

Based on the source of bluexmms by Tom Gilbert.

=head1 COPYRIGHT

Copyright (C) 2003, Richard Clamp.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<bluexmms|http://www.linuxbrit.net/bluexmms/>,
L<Romeo|http://www.irowan.com/arboreal/>, L<Device::SerialPort>

=cut
