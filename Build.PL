use strict;
use Module::Build;

Module::Build
  ->new( module_name => "Device::Ericsson::AccessoryMenu",
         license     => 'perl',
         requires    => {
             'Device::SerialPort' => 0,
             'Test::More'         => 0,
         },
         create_makefile_pl => 'traditional',
         sign => 1,
       )
  ->create_build_script;
