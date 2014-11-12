package Getopt::Long::Patch::DumpSpec;

# DATE
# VERSION

use 5.010001;
use strict;
no warnings;

use Data::Dump;
use Module::Patch 0.19 qw();
use base qw(Module::Patch);

our %config;

sub _dump {
    print "# BEGIN DUMPSPEC $config{-tag}\n";
    dd @_;
    print "# END DUMPSPEC $config{-tag}\n";
}

sub _GetOptions(@) {
    # discard optional first hash argument
    if (ref($_[0]) eq 'HASH') {
        shift;
    }
    my %spec = @_;
    _dump(\%spec);
    exit 0;
}

sub _GetOptionsFromArray(@) {
    # discard array
    shift;
    # discard optional first hash argument
    if (ref($_[0]) eq 'HASH') {
        shift;
    }
    my %spec = @_;
    _dump(\%spec);
    exit 0;
}

sub _GetOptionsFromString(@) {
    # discard string
    shift;
    # discard optional first hash argument
    if (ref($_[0]) eq 'HASH') {
        shift;
    }
    my %spec = @_;
    _dump(\%spec);
    exit 0;
}

sub patch_data {
    return {
        v => 3,
        patches => [
            {
                action      => 'replace',
                sub_name    => 'GetOptions',
                code        => \&_GetOptions,
            },
            {
                action      => 'replace',
                sub_name    => 'GetOptionsFromArray',
                code        => \&_GetOptionsFromArray,
            },
            {
                action      => 'replace',
                sub_name    => 'GetOptionsFromString',
                code        => \&_GetOptionsFromString,
            },
        ],
        config => {
            -tag => {
                schema  => 'str*',
                default => 'TAG',
            },
        },
   };
}

1;
# ABSTRACT: Patch Getopt::Long to dump option spec

=for Pod::Coverage ^(patch_data)$
