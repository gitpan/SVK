#!/usr/bin/perl
use strict;
require 't/tree.pl';
require Test::More;
eval "require SVN::Mirror"
or Test::More->import (skip_all => "SVN::Mirror not installed");
Test::More->import ('tests', 3);

# build another tree to be mirrored ourself
my ($xd, $svk) = build_test('test', 'client2');

my $tree = create_basic_tree ($xd, '/test/');
my $pool = SVN::Pool->new_default;

my ($copath, $corpath) = get_copath ('smerge');
my ($scopath, $scorpath) = get_copath ('smerge-source');

my ($srepospath, $spath, $srepos) =$xd->find_repos ('/test/A', 1);
my ($repospath, undef, $repos) =$xd->find_repos ('//', 1);
my ($nrepospath, undef, $nrepos) =$xd->find_repos ('/client2/', 1);

$svk->mirror ('//m', "file://${srepospath}".($spath eq '/' ? '' : $spath));

$svk->sync ('//m');

$svk->copy ('-m', 'branch', '//m', '//l');

$svk->checkout ('/test/', $scopath);
append_file ("$scopath/A/be", "modified on trunk\n");
$svk->commit ('-m', 'commit on trunk', $scopath);
$svk->checkout ('//l', $copath);
append_file ("$copath/Q/qu", "modified on local branch\n");
$svk->commit ('-m', 'commit on local branch', $copath);

$svk->sync ('//m');

$svk->merge ('-a', '-C', '//m', '//l');
$svk->merge ('-a', '-C', '//l', '//m');

$svk->merge ('-a', '-m', 'simple smerge from source', '//m', '//l');

my ($suuid, $srev) = ($srepos->fs->get_uuid, $srepos->fs->youngest_rev);
$svk->update ($copath);
ok (eq_hash (SVK::XD::do_proplist ($xd,
				   repos => $repos,
				   copath => $copath,
				   path => '/l',
				   rev => $repos->fs->youngest_rev,
				  ),
	     {'svk:merge' => "$suuid:/A:$srev",
	      'svm:source' => 'file://'.$srepos->path.'!/A',
	      'svm:uuid' => $suuid }), 'simple smerge from source');

my ($uuid, $rev) = ($repos->fs->get_uuid, $repos->fs->youngest_rev);

$svk->smerge ('-m', 'simple smerge from local', '//l', '//m');

$svk->sync ('//m');

ok (eq_hash (SVK::XD::do_proplist ($xd,
				   repos => $repos,
				   path => '/m',
				   rev => $repos->fs->youngest_rev,
				  ),
	     {'svk:merge' => "$uuid:/l:$rev",
	      'svm:source' => 'file://'.$srepos->path.'!/A',
	      'svm:uuid' => $suuid }),
    'simple smerge back to source');

$svk->smerge ('-C', '//m', '//l');
$svk->smerge ('-m', 'mergedown', '//m', '//l');
$svk->smerge ('-m', 'mergedown', '//m', '//l');
$svk->update ($scopath);
append_file ("$scopath/A/be", "more modification on trunk\n");
mkdir "$scopath/A/newdir";
$svk->add ("$scopath/A/newdir");
$svk->propset ("bzz", "newprop", "$scopath/A/Q/qu");
$svk->commit ('-m', 'commit on trunk', $scopath);
$svk->sync ('//m');

$svk->update ($copath);
append_file ("$copath/be", "modification on local\n");
append_file ("$copath/Q/qu", "modified on local\n");
$svk->commit ('-m', 'commit on local', $copath);
$svk->smerge ('-C', '//m', '//l');
$svk->smerge ('-C', '//m', $copath);
$svk->smerge ('//m', $copath);
$svk->status ($copath);
$svk->revert ("$copath/be");
$svk->resolved ("$copath/be");
$svk->status ($copath);
$svk->commit ('-m', 'merge down committed from checkout', $copath);
rmdir "$copath/newdir";
$svk->revert ('-R', $copath);
ok (-e "$copath/newdir", 'smerge to checkout - add directory');
$svk->mirror ('/client2/trunk', "file://${srepospath}".($spath eq '/' ? '' : $spath));

$svk->sync ('/client2/trunk');
$svk->copy ('-m', 'client2 branch', '/client2/trunk', '/client2/local');


$svk->copy ('-m', 'branch on source', '/test/A', '/test/A-cp');
$svk->ps ('-m', 'prop on A-cp', 'blah', 'tobemerged', '/test/A');
$svk->mirror ('//m-all', "file://${srepospath}/");
$svk->sync ('//m-all');
$svk->smerge ('-C', '//m-all/A', '//m-all/A-cp');
$svk->smerge ('-m', 'merge down', '//m-all/A', '//m-all/A-cp');
$svk->pl ('-v', '//');