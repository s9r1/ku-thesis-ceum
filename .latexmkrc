#!/usr/bin/env perl

# $latex      = 'internal mylatex uplatex %A -synctex=1 -file-line-error -halt-on-error %O %S';
$latex      = 'uplatex -synctex=1 -file-line-error -halt-on-error %O %S';
$dvipdf     = 'dvipdfmx %O -o %D %S';
$pdf_mode   = 3;

$bibtex     = 'upbibtex %O %S';
$biber      = 'biber --bblencoding=utf8 -u -U --output_safechars %O %S';
$bibtex_use = 2;

$makeindex  = 'upmendex %O -o %D %S -s jpbase';

$do_cd      = 1;
$clean_ext  = "$clean_ext fmt";

{
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
}
