#!/usr/bin/env perl

my $args = ' -synctex=1 -file-line-error -halt-on-error %O %S';

# $latex      = 'internal mylatex uplatex %A'.$args;
$latex      = 'uplatex'.$args;
$lualatex   = 'lualatex'.$args;

$pdf_mode   = 3;

$dvipdf     = 'dvipdfmx %O -o %D %S';

$bibtex     = 'upbibtex %O %S';
$biber      = 'biber --bblencoding=utf8 -u -U --output_safechars %O %S';
$bibtex_use = 2;

$makeindex  = 'upmendex %O -o %D %S -s jpbase';

$do_cd      = 1;
$clean_ext  = "$clean_ext fmt";

# 開発用
# foreach my $arg (@ARGV) {
#     next if $arg =~ /^-/;
#     next unless $arg =~ /\.tex$/i;
#     next unless -f $arg && -r _;

#     open(my $fh, '<', $arg) or next;
#     my $first = <$fh>;
#     close($fh);

#     if (defined $first && $first =~ /^\s*%\s*\$?pdf_mode\s*=\s*([0-5])\s*;?\s*$/i) {
#         $pdf_mode = 0 + $1;
#         last;
#     }
# }

sub mylatex {
  my ($engine, $base, @args) = @_;
  my $com = join(' ', @args);

  my $auxdir = $aux_dir || '.';
  my $fmt_path = "$auxdir/$base.fmt";

  unless (-e $fmt_path){
    print "mylatex: making $fmt_path in ini mode... \n";
    Run_subst("$engine -ini -jobname=\"$base\" -output-directory=\"$auxdir\" \\\&$engine mylatexformat.ltx %S");
  }
  print "mylatex: $fmt_path detected, so running normal latex... \n";
  return Run_subst("$engine -fmt \"$fmt_path\" $com");
}
