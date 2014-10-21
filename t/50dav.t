#!/usr/bin/perl -w
use strict;
# XXX: apache::test seems to alter inc to use blib
require SVK::Command::Merge;

# XXX: apache::TestConfig assumes lib.pm is compiled.
require lib;

use SVK::Util qw(can_run);

BEGIN {
    require 't/tree.pl';
    plan (skip_all => "Test does not run under root") if $> == 0;
    eval { require Apache2 };
    eval { require Apache::Test;
	   $Apache::Test::VERSION >= 1.18 }
	or plan (skip_all => "Apache::Test 1.18 required for testing dav");
    plan (skip_all => "Test does not work with BDB") if $ENV{SVNFSTYPE} eq 'bdb';
}

use Apache::TestConfig;
use File::Spec::Functions qw(rel2abs catdir);

our $output;

my ($xd, $svk) = build_test('test');

my $tree = create_basic_tree ($xd, '/test/');
my ($srepospath, $spath, $srepos) = $xd->find_repos ('/test/A', 1);
my (undef, undef, $repos) = $xd->find_repos ('//', 1);

my $apache_root = rel2abs (catdir ('t', 'apache_svn'));
my $apxs = $ENV{APXS} || can_run('apxs2') || can_run ('apxs');
die unless $apxs;
my $cfg = Apache::TestConfig->new
    ( top_dir => $apache_root,
      t_dir => $apache_root,
      apxs => $apxs,
 )->httpd_config;
unless ($cfg->can('find_and_load_module') and
	$cfg->find_and_load_module ('mod_dav.so') and
	$cfg->find_and_load_module ('mod_dav_svn.so')) {
    plan skip_all => "Can't find mod_dav_svn";
}

plan_svm tests => 11;

$cfg->postamble (Location => "/svn",
		 qq{DAV svn\n    SVNPath $srepospath\n});
$cfg->generate_httpd_conf;
my $server = $cfg->server;
$server->start;
ok ($server->ping, 'server is alive');

my $uri = 'http://'.$server->{name}.'/svn';

$svk->mirror ('//remote', "$uri/A");

is_output ($svk, 'sync', ['//remote'],
	   ["Syncing $uri/A",
	    'Retrieving log information from 1 to 2',
	    'Committed revision 2 from revision 1.',
	    'Committed revision 3 from revision 2.']);

my ($copath, $corpath) = get_copath ('dav');

$svk->cp (-m => 'local', '//remote' => '//local');

$svk->checkout ('//local', $copath);

append_file ("$copath/Q/qu", "some changes\n");
append_file ("$copath/be", "changes\n");

is_output ($svk, 'commit', [-m => "L\x{e9}on is a nice guy.", $copath],
	   ["Can't decode commit message as utf8.", "try --encoding."]);
is_output ($svk, 'commit', [-m => "L\x{e9}on is a nice guy.", '--encoding', 'iso-8859-1', $copath],
	   ["Committed revision 5."]);
$svk->smerge (-Cm => 'foo', -f => '//local/');

my $uuid = $repos->fs->get_uuid;

is_output ($svk, 'smerge', [-m => 'foo', -f => '//local/'],
	   ['Auto-merging (0, 5) /local to /remote (base /remote:3).',
	    "Merging back to mirror source $uri/A.",
	    'U   Q/qu',
	    'U   be',
	    "New merge ticket: $uuid:/local:5",
	    'Merge back committed as revision 3.',
	    "Syncing $uri/A",
	    'Retrieving log information from 3 to 3',
	    'Committed revision 6 from revision 3.']);
$svk->switch ('//remote', $copath);
append_file ("$copath/Q/qu", "More changes in iso-8859-1\n");
is_output ($svk, 'commit', [-m => "L\x{e9}on has a nice name.", $copath],
	   ["Commit into mirrored path: merging back directly.",
	    "Can't decode commit message as utf8.", "try --encoding."]);
is_output_like ($svk, 'commit', [-m => "L\x{e9}on has a nice name.", '--encoding', 'iso-8859-1', $copath],
		qr'Committed revision');

$svk->rm (-m => 'mkdir', '/test/A/Q');
$svk->mkdir (-m => 'mkdir', '//local/Q/foo');
set_editor(<< "TMP");
\$_ = shift;
open _ or die \$!;
\@_ = ("from editor\n", <_>);
close _;
unlink \$_;
open _, '>', \$_ or die \$!;
print _ \@_;
close _;
TMP

# when merge/commit failed, log message should be somewhere.

chdir ($copath);
$svk->sm(-f => '//local');
ok (my ($filename) = $output =~ m/saved in (.*)\./s);
is_file_content ($filename, "from editor\n");

$server->stop;


append_file ("be", "changes\n");

is_output ($svk, 'commit', [],
	   ['Commit into mirrored path: merging back directly.',
	    'Waiting for editor...',
	    "Merging back to mirror source $uri/A.",
	    qr"RA layer request failed: OPTIONS request failed on '/svn/A': OPTIONS of '/svn/A': could not connect to server .*",
	    qr'Commit message saved in (.*)\.']);
($filename) = $output =~ m/saved in (.*)\./s;
is_file_content ($filename, "from editor\n");
