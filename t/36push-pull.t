#!/usr/bin/perl -w
use strict;
use Test::More;
use Cwd;
use File::Path;

BEGIN { require 't/tree.pl' };
plan_svm tests => 12;

my $initial_cwd = getcwd;

# build another tree to be mirrored ourself
my ($xd, $svk) = build_test('test');

my $tree = create_basic_tree ($xd, '/test/');

my ($copath_test, $corpath_test) = get_copath ('push-pull-test');
my ($copath_default, $corpath_default) = get_copath ('push-pull-default');
my ($copath_second, $corpath_second) = get_copath ('push-pull-second');

my ($test_repospath, $test_a_path, $test_repos) =$xd->find_repos ('/test/A', 1);
my $test_uuid = $test_repos->fs->get_uuid;

my ($default_repospath, $default_path, $default_repos) =$xd->find_repos ('//A', 1);
my $default_uuid = $default_repos->fs->get_uuid;

my $uri = uri($test_repospath);
$svk->mirror ('//m', $uri.($test_a_path eq '/' ? '' : $test_a_path));

$svk->sync ('//m');

$svk->copy ('-m', 'branch', '//m', '//l');
$svk->checkout ('//l', $corpath_default);

ok (-e "$corpath_default/be");
append_file ("$corpath_default/be", "from local branch\n");
mkdir "$corpath_default/T/";
append_file ("$corpath_default/T/xd", "local new file\n");

$svk->add ("$corpath_default/T");
$svk->delete ("$corpath_default/Q/qu");

$svk->commit ('-m', 'local modification from branch', "$corpath_default");

append_file ("$corpath_default/T/xd", "more content\n");
$svk->commit ('-m', 'second local modification from branch', "$corpath_default");

chdir ($corpath_default);
is_output ($svk, "push", [], [
        "Auto-merging (0, 6) /l to /m (base /m:3).",
        "===> Auto-merging (0, 4) /l to /m (base /m:3).",
        "Merging back to mirror source $uri/A.",
        "Empty merge.",
        "===> Auto-merging (4, 5) /l to /m (base /m:3).",
        "Merging back to mirror source $uri/A.",
        "D   Q/qu",
        "A   T",
        "A   T/xd",
        "U   be",
        "New merge ticket: $default_uuid:/l:5",
        "Merge back committed as revision 3.",
        "Syncing $uri/A",
        "Retrieving log information from 3 to 3",
        "Committed revision 7 from revision 3.",
        "===> Auto-merging (5, 6) /l to /m (base /l:5).",
        "Merging back to mirror source $uri/A.",
        "U   T/xd",
        "New merge ticket: $default_uuid:/l:6",
        "Merge back committed as revision 4.",
        "Syncing $uri/A",
        "Retrieving log information from 4 to 4",
        "Committed revision 8 from revision 4."]);

append_file ("$corpath_default/T/xd", "even more content\n");
$svk->commit ('-m', 'third local modification from branch', "$corpath_default");

append_file ("$corpath_default/be", "more content\n");
$svk->commit ('-m', 'fourth local modification from branch', "$corpath_default");

is_output ($svk, 'push', ['-l'], [
        "Auto-merging (6, 10) /l to /m (base /l:6).",
        "Merging back to mirror source $uri/A.",
        "U   T/xd",
        "U   be",
        "New merge ticket: $default_uuid:/l:10",
        "Merge back committed as revision 5.",
        "Syncing $uri/A",
        "Retrieving log information from 5 to 5",
        "Committed revision 11 from revision 5."]);


$svk->checkout ('/test/A', $corpath_test);

# add a file to remote
append_file ("$corpath_test/new-file", "some text\n");
$svk->add ("$corpath_test/new-file");

$svk->commit ('-m', 'making changes in remote depot', "$corpath_test");

chdir ($corpath_default);
is_output ($svk, "pull", [], [
        "Syncing $uri/A",
        "Retrieving log information from 6 to 6",
        "Committed revision 12 from revision 6.",
        "Auto-merging (3, 12) /m to /l (base /l:10).",
        "A   new-file",
        "New merge ticket: $test_uuid:/A:6",
        "Committed revision 13.",
        "Syncing //l(/l) in $corpath_default to 13.",
        "A   new-file"]);


# add a file to remote
append_file ("$corpath_test/new-file", "some text\n");
$svk->add ("$corpath_test/new-file");

$svk->commit ('-m', 'making changes in remote depot', "$corpath_test");

chdir ($initial_cwd);

$svk->sync ("//m");

is_output ($svk, "push", ['-C', "--from", "//m", "//l"], [
        "Auto-merging (12, 14) /m to /l (base /m:12).",
        "Incremental merge not guaranteed even if check is successful",
        "U   new-file",
        "New merge ticket: $test_uuid:/A:7"]);

is_output ($svk, "push", ["--from", "//m", "//l"], [
        "Auto-merging (12, 14) /m to /l (base /m:12).",
        "===> Auto-merging (12, 14) /m to /l (base /m:12).",
        "U   new-file",
        "New merge ticket: $test_uuid:/A:7",
        "Committed revision 15."]);

$svk->switch ("//m", $corpath_default);
append_file ("$corpath_default/new-file", "some text\n");
$svk->commit ('-m', 'modification to mirror', "$corpath_default");

is_output ($svk, "pull", ["//l"], [
        "Auto-merging (14, 16) /m to /l (base /m:14).",
        "===> Auto-merging (14, 16) /m to /l (base /m:14).",
        "U   new-file",
        "New merge ticket: $test_uuid:/A:8",
        "Committed revision 17."]);

$svk->copy ('-m', '2nd branch', '//m', '//l2');
$svk->checkout ('//l2', $corpath_second);

is_output ($svk, "pull", [$corpath_default, $corpath_second], [
        "Syncing $uri/A",
        "Syncing //m(/m) in $corpath_default to 18.",
        "Syncing //l2(/l2) in $corpath_second to 18."]);
is_output ($svk, "pull", ['-a'], [
        "Syncing $uri/A",
        "Syncing //m(/m) in $corpath_default to 18.",
        "Syncing //l2(/l2) in $corpath_second to 18.",
        "Syncing /test/A(/A) in $corpath_test to 8.",
        __"U   $corpath_test/new-file"]);

append_file ("$corpath_default/new-file", "some text\n");
$svk->commit ('-m', 'modification to mirror', "$corpath_default");

is_output ($svk, "pull", ['--lump', "//l"], [
        "Auto-merging (16, 19) /m to /l (base /m:16).",
        "U   new-file",
        "New merge ticket: $test_uuid:/A:9",
        "Committed revision 20."]);


my ($copath_subir, $corpath_subdir) = get_copath ('pull-subdir-test');
$svk->sync ('//m');
$svk->mkdir('-m', 'just dir', '//l-sub');
$svk->copy ('-m', 'branch', '//m/T', '//l-sub/sub');
$svk->checkout ('//l-sub', $corpath_subdir);

append_file ("$corpath_default/T/xd", "local changed file\n");
$svk->commit ('-m', 'local modification from branch', "$corpath_default");

chdir ($corpath_subdir);
is_output ($svk, "pull", ["sub"], [
	"Syncing $uri".($test_a_path eq '/' ? '' : $test_a_path),
	"Auto-merging (11, 23) /m/T to /l-sub/sub (base /m/T:11).",
	__("U   xd"),
	"New merge ticket: $test_uuid:/A/T:10",
	"Committed revision 24.",
	"Syncing //l-sub(/l-sub/sub) in ".__("$corpath_subdir/sub to 24."),
       __("U   sub/xd")]);
chdir ($initial_cwd);
our $output;
$svk->cp (-m => 'copy', '/test/A' => '/test/A-cp');
$svk->mkdir (-m => 'dir in A', '/test/A/notforcp');
$svk->mkdir (-m => 'dir in A-ap', '/test/A-cp/cp-only');
$svk->mi ('--detach' => '//m');
$svk->mi ('//all', $uri);
$svk->sync ('-a');

rmtree [$corpath_default];
$svk->checkout ('//all/A-cp', $corpath_default);

TODO: {
local $TODO = 'pull on mirrored path should not smerge from the same source';
is_output ($svk, 'pull', [$copath_default],
	   ["Syncing //all/A-cp(/all/A-cp) in $corpath_default to 32.",
	    __"A   $copath_default/cp-only"]);
}