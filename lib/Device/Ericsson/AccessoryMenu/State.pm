use strict;
package Device::Ericsson::AccessoryMenu::State;
use base 'Class::Accessor::Fast';
__PACKAGE__->mk_accessors( 'parent' );

sub on_exit {}
sub on_enter {}

1;
