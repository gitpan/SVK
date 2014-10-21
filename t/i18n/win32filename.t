#!/usr/bin/perl -w
use strict;
use SVK::Util qw( is_executable to_native from_native);
use SVK::Test;
plan skip_all => "Only needed to test on win32" unless IS_WIN32;
plan tests => 6;
our $output;

mkpath ["t/checkout/filenames"], 0, 0700 unless -d "t/checkout/filenames";

my ($xd, $svk) = build_test('filename_enc');
my ($copath, $corpath) = get_copath ('filenames');
my ($repospath, $path, $repos) = $xd->find_repos ('/filename_enc/', 1);
sub copath { SVK::Path::Checkout->copath($copath, @_) }

$svk->checkout ('//', $copath);

my $file = "\x{a4}\x{a4}\x{a4}\x{e5}\x{c0}\x{c9}.txt";
my $filename = $file;
overwrite_file ("$copath/$file", "new file to add\n");
chdir($copath);

is_output ($svk, 'add', [$file],
	   ['A   '.$file]);
is_output($svk, 'ci', [-m => 'commit single checkout', $file],
	  ['Committed revision 1.']);
append_file($file, "change single file\n");

from_native($filename);
append_file($file, "utf8 filename: $filename\n");
is_output($svk, 'diff', [$file],
	  ['=== '.$filename,
	   '==================================================================',
	   "--- $file\t(revision 1)",
	   "+++ $file\t(local)",
	   '@@ -1 +1,3 @@',
	   ' new file to add',
	   '+change single file',
	   '+utf8 filename: '.$filename,
	  ]);
is_output($svk, 'ci', [-m => 'commit single checkout', $file],
	  ['Committed revision 2.']);

chdir ('..');
chdir ('..');
chdir ('..');
$svk->update ('-r', 1, $copath);
is_file_content (copath("$file"), "new file to add\n");

overwrite_file (copath("$file"),
		"hihi\n");
$svk->update ($copath);
ok ($output =~ m/1 conflict found\./, 'conflict');

$svk->revert ($copath);
$svk->resolved ($copath);

1;
