#!/usr/bin/perl

use warnings;
use strict;
use Data::Dumper;
use SOAP::Lite;

@ARGV==1 or die;
my ($dist) = @ARGV;

my $debbugs_soap= 'Debbugs/SOAP';
my $debbugs_uri= 'http://bugs.debian.org/cgi-bin/soap.cgi';

my $usertag_owner= 'autopkgtest@packages.debian.org';
my $usertag_name= "autopkgtest";

my $soap= SOAP::Lite->uri($debbugs_soap)->proxy($debbugs_uri);

open D, "> /dev/null" or die $!;

my $bugs_ut= $soap->get_usertag($usertag_owner, $usertag_name)->result();
printf D "bugs_ut: %s\n", Dumper($bugs_ut);

my $bugs_rq= [map { [bug => $_, dist => $dist] } @{$bugs_ut->{$usertag_name}}];
printf D "bugs_rq: %s\n", Dumper($bugs_rq);

my $stats= $soap->get_status($bugs_rq)->result();
printf D "bugs_rq: %s\nstats: %s\n", Dumper($bugs_rq), Dumper($stats);

my $stat;

sub badbug ($) {
    my ($msg) = @_;
    die "BAD BUG - $msg:\n".Dumper($stat)."\n - $msg !";
}

foreach $stat (values %$stats) {
    printf D "==========\n%s\n", Dumper($stat);
    next if $stat->{'pending'} eq 'done';
    my $fv= $stat->{'found_versions'};
    @$fv or badbug("pending but not found");
    $fv= $fv->[$#$fv];
    my $src= $fv =~ m,/, ? $` : $stat->{'package'};
    $src !~ m/[^-+.0-9a-z]/ and $src =~ m/^[0-9a-z]/ or badbug('bad package');
    my $id= $stat->{'id'};
    $id !~ m/\D/ and $id =~ m/^[1-9]/ or badbug("bad id");
    printf "%s %d\n", $src, $id
	or die $!;
}

STDOUT->error and die $!;
close STDOUT or die $!;
