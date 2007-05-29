#!/usr/bin/perl -w
use strict;

sub pr2 { print "$_[0]\n"; }
sub mylog { print @_;}


# to be launched from the git directory
die "usage: $0 commithashafter [commithashbefore]" 
  if(@ARGV <= 0 || @ARGV >= 3);

# update: now I also extract the headers files, the one
# that were modified in the commit and the one that are
# locally used and that may contain useful type information
# for spatch.

# update: now I also extract some include/linux/header.h files, the
# one having the same name of one of the driver.

my $target_dir = "/tmp/extract_c_and_res/$ARGV[0]";
`mkdir -p $target_dir`;
my $old_dir = "/tmp/extract_c_and_res/$ARGV[0]_old";
`mkdir -p $old_dir`;
my $new_dir = "/tmp/extract_c_and_res/$ARGV[0]_new";
`mkdir -p $new_dir`;

my $commit1 = $ARGV[0]; # new
my $commit2 = $ARGV[1] || "$commit1^"; # default parent 

my $gitfile = "$target_dir/$commit1.gitinfo";
my $makefile = "$target_dir/Makefile";

`git show $commit1 > $gitfile `;


# processing the patch 

my @files = ();
my $files = {};
my @driverheaders_in_include = ();


open FILE, "$gitfile" or die "$!";
while(<FILE>) {

  # allow other dir ? # fs|mm   there is drivers under arch/ too
  if(/^diff --git a\/((drivers|sound)\/.*?\.[ch]) b/){ 
        mylog "  $1\n";
        push @files, $1;
        $files->{$1} = 1;                
                        
    }
    elsif(/^diff --git a\/(include\/.*?\.h) b/) {
        mylog "potential header driver $1\n";
        push @driverheaders_in_include, $1;
    }
    elsif(/^diff --git a\//) {
      mylog " not driver:$_";
    }
    elsif(/^diff/) {
      die "PB: strange diff line: $_";
    }
}

# extracting the .c and .h of the patch

my $counter=0;

# to be able to later find the corresponding local included header file
my $kerneldir_of_file = {};

my @finalcfiles = ();
my $finalcfiles = {};

foreach my $f (@files) {
  my ($base) = `basename $f`;
  chomp $base;
  my $res = $base;
  if($base =~ /\.c$/) {
    $res =~ s/\.c$/.res/;
  } 
  if($base =~ /\.h$/) {
    $res =~ s/\.h$/.h.res/;
  } 

  pr2 "processing: $f $base $res";
  if(-e "$target_dir/$base") {
    $counter++;                              
    $base = "${counter}_$base";
    $res = "${counter}_$res";
    pr2 "try transform one file because already exist: $base";
    if($base =~ /\.h$/) {
      die "PB: Two header files share the same name: $base.";
    }

  }                         
  die "PB: one of the file already exist: $base" if (-e "$target_dir/$base");

  `git-cat-file blob $commit2:$f > $target_dir/$base`;
  `git-cat-file blob $commit1:$f > $target_dir/$res`;
  `git-cat-file blob $commit2:$f > $old_dir/$base`;
  `git-cat-file blob $commit1:$f > $new_dir/$base`;

  $kerneldir_of_file->{$base} = `dirname $f`;
  chomp $kerneldir_of_file->{$base};
  push @finalcfiles, $base;
  $finalcfiles->{$base} = 1;


}

# generate Makefile

open MAKE, ">$makefile" or die "$!";
print MAKE "CEDESCRIPTION=\"TODO\"\n";
print MAKE "SP=\"TODO\"\n";
print MAKE "SOURCES = ";
my $last = shift @finalcfiles;
foreach my $f (@finalcfiles) {
  print MAKE "$f \\\n\t";
}
print MAKE "$last\n";


# process potential driver headers of include/

foreach my $f (@driverheaders_in_include) {
  my $base = `basename $f`;
  chomp $base;
  if($base =~ /.h$/) {
    $base =~ s/.h$/.c/;
  } else {
    die "PB: internal error";
  }

#  pr2 "$f $base";
  if(defined($finalcfiles->{$base})) {
    pr2 "found header of driver in include/: $f of $base";
    my $dir = `dirname $f`;
    chomp $dir;
    `mkdir -p $target_dir/$dir`;
    `git-cat-file blob $commit2:$f > $target_dir/$f`;
    `git-cat-file blob $commit1:$f > $target_dir/$f.res`;
    
  }
}

# compute other linux headers not in the patch

my @linuxheaders  = `cd $target_dir; grep -E \"#include +\<.*\>\" *.c *.h`;
foreach my $line (@linuxheaders) {
  chomp $line;
  #pr2 ($line);
  if($line =~ /^(.*)?:#include *\<(.*)\>/) {
    my ($_file, $f) = ($1, $2);

    my $base = `basename $f`;
    chomp $base;
    if($base =~ /.h$/) {
      $base =~ s/.h$/.c/;
    } else {
      die "PB: internal error";
    }

    if(defined($finalcfiles->{$base}) && ! -e "$target_dir/include/$f") {
      pr2 "found header of driver in include/: $f of $base";
      my $dir = `dirname $f`;
      chomp $dir;
      `mkdir -p $target_dir/include/$dir`;
      `git-cat-file blob $commit2:include/$f > $target_dir/include/$f`;
    }
    
  } else { pr2 "pb regexp: $line"; }
}


# compute other local headers not in the patch

my @headers  = `cd $target_dir; grep -E \"#include +\\".*\\"\" *.c *.h`;

my $hfiles = {};
foreach my $line (@headers) {
  chomp $line;
  #pr2 ($line);
  if($line =~ /^(.*)?:#include *"(.*)"/) {

    my ($file, $header) = ($1, $2);
    my $dir = $kerneldir_of_file->{$file};

    my $fullheader = "$dir/$header";
    #pr2 ($fullheader);

    if($files->{$fullheader}) {
      pr2 "INFO: $fullheader was already in commit";
    } else {
      $hfiles->{$fullheader} = 1;
    }
    
  } else { pr2 "pb regexp: $line"; }
  
}


foreach my $h (keys %{$hfiles}) {
  my ($base) = `basename $h`;
  chomp $base;
  pr2 "processing additionnal header file: $h $base";

  if(-e "$target_dir/$base") {
    pr2 "-------------------------------------";
    pr2 "PB: local header $base already exists";
    pr2 "BUT I CONTINUE, but may have more .failed in the end";
    pr2 "-------------------------------------";
  } else {
    `git-cat-file blob $commit2:$h > $target_dir/$base`;
  }
}
