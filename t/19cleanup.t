#!/usr/bin/perl -w
use Test::More tests => 11;
use strict;
require 't/tree.pl';

my ($xd, $svk) = build_test();
our $output;
my ($copath, $corpath) = get_copath ('cleanup');

my ($repospath) = $xd->find_repos ('//');

$xd->{svkpath} = $repospath;
$xd->{statefile} = "$repospath/svk.config";
$xd->{giantlock} = "$repospath/svk.giant";

$xd->giant_lock;
is_file_content ($xd->{giantlock}, $$, 'giant locked');
ok ($xd->{giantlocked}, 'giant locked');
$xd->store;
ok ($xd->{updated}, 'marked as updated');
ok (!$xd->{giantlocked}, 'giant unlocked');
$xd->giant_lock;
$svk->checkout ('//', $copath);
ok (!$xd->{giantlocked}, 'giant unlocked after command invocation');
is_output_like ($svk, 'cleanup', [$copath], qr'not locked');
$xd->giant_lock;
$xd->lock ($corpath);
is ($xd->{checkout}->get ($corpath)->{lock}, $$, 'copath locked');
# fake lock by other process
$xd->{checkout}->store ($corpath, {lock => $$+1});
$xd->store;
$xd->load;
$svk->update ($copath);
ok ($@ =~ qr'already locked', 'command not allowed when copath locked');
chdir ($copath);
is_output_like ($svk, 'cleanup', [], qr'Cleaned up stalled lock');
is ($xd->{checkout}->get ($corpath)->{lock}, undef,  'unlocked');
eval { $xd->giant_lock };
ok ($@ =~ qr'another svk', 'command not allowed when giant locked');
