
use strict;
use warnings;

use Module::Build 0.3601;


my %module_build_args = (
  "build_requires" => {
    "Module::Build" => "0.3601"
  },
  "configure_requires" => {
    "Module::Build" => "0.3601"
  },
  "dist_abstract" => "Wrapper for Perinci Riap clients",
  "dist_author" => [
    "Steven Haryanto <stevenharyanto\@gmail.com>"
  ],
  "dist_name" => "Perinci-Access",
  "dist_version" => "0.36",
  "license" => "perl",
  "module_name" => "Perinci::Access",
  "recommends" => {},
  "recursive_test_files" => 1,
  "requires" => {
    "Log::Any" => 0,
    "Perinci::Access::HTTP::Client" => "0.10",
    "Perinci::Access::Perl" => 0,
    "Perinci::Access::Schemeless" => 0,
    "Perinci::Access::Simple::Client" => "0.13",
    "URI::Split" => 0,
    "perl" => "5.010001"
  },
  "script_files" => [
    "bin/peri-access"
  ],
  "test_requires" => {
    "Capture::Tiny" => 0,
    "Perinci::Examples" => 0,
    "Test::More" => "0.96",
    "Test::Script" => "1.05",
    "blib" => 0
  }
);


unless ( eval { Module::Build->VERSION(0.4004) } ) {
  my $tr = delete $module_build_args{test_requires};
  my $br = $module_build_args{build_requires};
  for my $mod ( keys %$tr ) {
    if ( exists $br->{$mod} ) {
      $br->{$mod} = $tr->{$mod} if $tr->{$mod} > $br->{$mod};
    }
    else {
      $br->{$mod} = $tr->{$mod};
    }
  }
}

my $build = Module::Build->new(%module_build_args);

$build->create_build_script;
