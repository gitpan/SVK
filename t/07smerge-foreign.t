#!/usr/bin/perl
use Test::More tests => 1;
use strict;
require 't/tree.pl';
our $output;
my ($xd, $svk) = build_test('mac', 'linux');
my ($copath) = get_copath ('obra');
$svk->checkout ('//', $copath);
mkdir "$copath/trunk";
overwrite_file ("$copath/trunk/foo", "foobar\n");
overwrite_file ("$copath/trunk/test.pl", qq|#!/usr/bin/perl\n|);
$svk->add ("$copath/trunk");
$svk->commit ('-m', 'init', "$copath");
$svk->copy ('-m', 'branch stable', '//trunk', '//stable');

my ($srepospath, $spath) = $xd->find_repos ('//trunk');
$svk->mirror ('/mac/upstream', "file://${srepospath}");
$svk->sync ('/mac/upstream');

($copath) = get_copath ('obra-mac');
$svk->copy ('-m', 'local branch trunk on mac', '/mac/upstream/trunk', '/mac/local/trunk');
$svk->copy ('-m', 'local branch stable on mac', '/mac/upstream/stable', '/mac/local/stable');
$svk->checkout ('/mac/local', $copath);
overwrite_file ("$copath/trunk/test.pl", qq|#!/usr/bin/perl\n# mac local trunk\n|);
$svk->commit ('-m', 'change trunk on mac local', $copath);
overwrite_file ("$copath/stable/test.pl", qq|#foobar stable\n#!/usr/bin/perl\n# mac local trunk\n|);
$svk->commit ('-m', 'change stable on mac local', $copath);
$svk->smerge ('-m', 'merge trunk -> stable on mac', '/mac/local/trunk', '/mac/local/stable');
$svk->smerge ('-m', 'merge back trunk from mac', '/mac/local/trunk', '/mac/upstream/trunk');
$svk->smerge ('-m', 'merge back stable from mac', '/mac/local/stable', '/mac/upstream/stable');

$svk->mirror ('/linux/upstream', "file://${srepospath}");
$svk->sync ('/linux/upstream');

($copath) = get_copath ('obra-linux');
$svk->copy ('-m', 'local branch trunk on linux', '/linux/upstream/trunk', '/linux/local/trunk');
$svk->copy ('-m', 'local branch stable on linux', '/linux/upstream/stable', '/linux/local/stable');
$svk->checkout ('/linux/local', $copath);
overwrite_file ("$copath/trunk/test.pl", qq|#!/usr/bin/perl\n# mac local trunk\n# linux local trunk\n|);
$svk->commit ('-m', 'change trunk on linux local', $copath);
$svk->smerge ('-m', 'merge trunk -> stable on linux', '/linux/local/trunk', '/linux/local/stable');
ok ($output =~ m|base /upstream/trunk:4|, 'base is foreign');
