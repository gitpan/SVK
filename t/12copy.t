#!/usr/bin/perl -w
use strict;
BEGIN { require 't/tree.pl' };
plan_svm tests => 50;

our ($output, $answer);
my ($xd, $svk) = build_test('foo');
$svk->mkdir ('-m', 'init', '//V');
my $tree = create_basic_tree ($xd, '//V');
$svk->mkdir ('-m', 'init', '//new');
our ($copath, $corpath) = get_copath ('copy');
is_output_like ($svk, 'copy', [], qr'SYNOPSIS', 'copy - help');

$svk->checkout ('//new', $copath);

is_output ($svk, 'copy', ['//V/me', '//V/D/de', $copath],
	   [__"A   $copath/me",
	    __"A   $copath/de"]);
is_output ($svk, 'cp', ['//V/me', $copath],
	   [__"Path $copath/me already exists."]);

is_output ($svk, 'copy', ['//V/me', '//V/D/de', "$copath/me"],
	   [__"$corpath/me is not a directory."], 'multi to nondir');
is_output ($svk, 'copy', ['//V/me', "$copath/me-copy"],
	   [__"A   $copath/me-copy"]);
is_output ($svk, 'copy', ['//V/D/de', "$copath/de-copy"],
	   [__"A   $copath/de-copy"]);
is_output ($svk, 'copy', ['//V/D', "$copath/D-copy"],
	   [__"A   $copath/D-copy",
	    __"A   $copath/D-copy/de"]);
$svk->copy ('//V', "$copath/V-copy");

is_output ($svk, 'copy', ['//V', '/foo/bar', "$copath/V-copy"],
	   ['Different depots.']);
append_file ("$copath/me-copy", "foobar");
append_file ("$copath/V-copy/D/de", "foobar");
$svk->rm ("$copath/V-copy/B/fe");
is_output ($svk, 'status', [$copath],
	   [__('A + t/checkout/copy/D-copy'),
	    __('A + t/checkout/copy/V-copy'),
	    __('D   t/checkout/copy/V-copy/B/fe'),
	    __('M   t/checkout/copy/V-copy/D/de'),
	    __('A + t/checkout/copy/de'),
	    __('A + t/checkout/copy/de-copy'),
	    __('A + t/checkout/copy/me'),
	    __('M + t/checkout/copy/me-copy')]);
$svk->commit ('-m', 'commit depot -> checkout copies', $copath);
is_copied_from ("$copath/me", '/V/me', 3);
is_copied_from ("$copath/me-copy", '/V/me', 3);
is_copied_from ("$copath/D-copy/de", '/V/D/de', 3);
is_copied_from ("$copath/D-copy", '/V/D', 3);

is_output ($svk, 'copy', ['-m', 'more than one', '//V/me', '//V/D', '//V/new'],
	   ["Copying more than one source requires //V/new to be directory."]);

$svk->mkdir ('-m', 'directory for multiple source cp', '//V/new');
is_output ($svk, 'copy', ['-m', 'more than one', '//V/me', '//V/D', '//V/new'],
	   ["Committed revision 7."]);
is_copied_from ("//V/new/me", '/V/me', 3);
is_copied_from ("//V/new/D", '/V/D', 3);

is_output ($svk, 'rm', ['-m', 'die!', '//V/D/de'],
	   ["Committed revision 8."]);
$svk->update ($copath);

is_output ($svk, 'copy', ["//V/D/de", "$copath/de-revive"],
	   ['Path /V/D/de does not exist.']);
is_output ($svk, 'copy', ['-r7', "//V/D/de", "$copath/de-revive"],
	   [__('A   t/checkout/copy/de-revive')]);
is_output ($svk, 'status', [$copath],
	   [__("A + $copath/de-revive")]
	  );
is_output ($svk, 'commit', ['-m', 'commit file copied from entry removed later', $copath],
	   ['Committed revision 9.']);
is_copied_from ("//new/de-revive", '/V/D/de', 3);

# proper anchoring
$svk->copy ('//V/A/be', "$copath/be-alone");
$svk->copy ('//V/A', "$copath/A-prop");
$svk->ps ('newprop', 'prop after cp', "$copath/be-alone");
$svk->ps ('newprop', 'prop after cp', "$copath/A-prop/be");

is_output ($svk, 'pl', ["$copath/be-alone"],
	   [__("Properties on $copath/be-alone:"),
	    '  newprop', '  svn:keywords']);

is_output ($svk, 'pl', ["$copath/A-prop/be"],
	   [__("Properties on $copath/A-prop/be:"),
	    '  newprop', '  svn:keywords']);

mkdir ("$copath/newdir");
$svk->add ("$copath/newdir");
my $status = [status_native ($copath, 'A  ', 'newdir/A',
			     'A  ', 'newdir/A/Q',
			     'A  ', 'newdir/A/Q/qu',
			     'A  ', 'newdir/A/Q/qz',
			     'A  ', 'newdir/A/be')];

is_output ($svk, 'copy', ['//V/A', "$copath/newdir"],
	   $status);
is_output ($svk, 'status', ["$copath/newdir/A", "$copath/A-prop"],
	   [status_native ($copath, 'A +', 'A-prop', ' M ', 'A-prop/be',
			   'A  ', 'newdir', 'A +', 'newdir/A')]);

$svk->status ("$copath/newdir/A");
$svk->revert ('-R', $copath);
TODO: {
local $TODO = 'revert removes known nodes copied';
is_output ($svk, 'status', [$copath], []);
}
# copy on mirrored paths
my ($srepospath, $spath, $srepos) = $xd->find_repos ('/foo/', 1);
my $uri = uri($srepospath);
create_basic_tree ($xd, '/foo/');
$svk->mirror ('//foo-remote', $uri);
$svk->sync ('//foo-remote');
$svk->update ($copath);

is_output ($svk, 'cp', ['//V/new', '//foo-remote/new'],
	   ['Different sources.']);

is_output ($svk, 'cp', ['-m', 'copy directly', '//V/me', '//V/me-dcopied'],
	   ['Committed revision 13.']);
is_copied_from ("//V/me-dcopied", '/V/me', 3);

is_output ($svk, 'cp', ['-m', 'copy for remote', '//foo-remote/me', '//foo-remote/me-rcopied'],
	   [
	    "Merging back to mirror source $uri.",
	    'Merge back committed as revision 3.',
	    "Syncing $uri",
	    'Retrieving log information from 3 to 3',
	    'Committed revision 14 from revision 3.']);

is_copied_from ("//foo-remote/me-rcopied", '/foo-remote/me', 12);
is_copied_from ("/foo/me-rcopied", '/me', 2);


rmtree ([$copath]);
$svk->checkout ('//foo-remote', $copath);

is_output ($svk, 'cp', ['//V/me', "$copath/me-rcopied"],
	   ['Different sources.']);
$svk->copy ('-m', 'from co', "$copath/me", '//foo-remote/me-rcopied.again');
is_copied_from ("//foo-remote/me-rcopied.again", '/foo-remote/me', 12);
is_copied_from ("/foo/me-rcopied.again", '/me', 2);

append_file ("$copath/me", "bzz\n");
is_output_like ($svk, 'copy', ['-m', 'from co, modified', "$copath/me", '//foo-remote/me-rcopied.modified'],
		qr/modified/);
$svk->revert ('-R', $copath);
$svk->copy ("$copath/me", "$copath/me-cocopied");
is_output ($svk, 'status', [$copath],
	   [__("A + $copath/me-cocopied")]
	  );
is_output ($svk, 'cp', ["$copath/me", "$copath/me-cocopied"], [__("Path $copath/me-cocopied already exists.")]);

$svk->commit ('-m', 'commit copied file in mirrored path', $copath);
is_copied_from ("/foo/me-cocopied", '/me', 2);

is_output ($svk, 'cp', ['-m', 'copy directly', '//V/me', '//V/A/Q/'],
	   ['Committed revision 17.']);
is_copied_from ("//V/A/Q/me", '/V/me', 3);

is_output ($svk, 'cp', ['-m', 'copy directly', '//V/me', '//V/newdir-with-p/me-dcopied'],
	   [qr'Transaction is out of date',
	    'Please update checkout first.']);
is_output ($svk, 'cp', ['-p', '-m', 'copy directly', '//V/me', '//V/newdir-with-p/me-dcopied'],
	   ['Committed revision 18.']);

is_copied_from ("//V/A/Q/me", '/V/me', 3);

require Cwd;
my $cwd = Cwd::cwd();
mkdir "$corpath-some";
chdir "$corpath-some";
$answer = 'somepath';
is_output ($svk, 'cp', ['-m', '', '//V/me'],
	   ['Committed revision 19.',
            'Syncing //somepath(/somepath) in '.__("$corpath-some/somepath to 19."),
            'A   somepath']);
is_copied_from ("//somepath", '/V/me', 3);
unlink "$corpath-some/somepath";
rmdir "$corpath-some";
chdir $cwd;

$svk->copy ("$copath/A", "$copath/B/A-cp-in-B");
is_output ($svk, 'status', [$copath],
	   [__("A + $copath/B/A-cp-in-B")]
	  );
$svk->update ($copath);

is_output ($svk, 'commit', ['-m', 'commit copied file in mirrored path', $copath],
	   ['Commit into mirrored path: merging back directly.',
	    "Merging back to mirror source $uri.",
	    'Merge back committed as revision 6.',
	    "Syncing $uri",
	    'Retrieving log information from 6 to 6',
	    'Committed revision 20 from revision 6.']);

sub is_copied_from {
    unshift @_, $svk;
    goto \&is_ancestor;
}
