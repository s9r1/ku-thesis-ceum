#!/usr/bin/env perl
use strict;
use warnings;

use Digest::SHA           qw(sha1_hex);
use File::Basename        qw(dirname);
use File::Spec::Functions qw(file_name_is_absolute catfile);
use Fcntl                 qw(:flock);
use Cwd                   qw(getcwd abs_path);

$jobname = 'your_name';

my $tex_opts = '-synctex=1 -file-line-error -halt-on-error -interaction=nonstopmode';
$latex    = "internal mylatex uplatex %Y %R $tex_opts %O %S";
$lualatex = "lualatex $tex_opts %O %S";
$dvipdf   = 'dvipdfmx %O -o %D %S';
$pdf_mode = 3;

$bibtex     = 'upbibtex %O %S';
$biber      = 'biber --bblencoding=utf8 -u -U --output_safechars %O %S';
$bibtex_use = 2;

$makeindex = 'upmendex %O -o %D %S -s jpbase';

$do_cd = 1;

$clean_ext = "$clean_ext fmt sha1 fmtlock deps";

# （開発用）
# ソース1行目が"% $pdf_mode = 4;"などの場合にpdf_modeを切り替える
# foreach my $arg (@ARGV) { # latexmk実行時の引数が@ARGVに入る
#     next if $arg =~ /^-/;
#     next unless $arg =~ /\.tex\z/i; # ソースは拡張子付き（%DOC_EXT%）で呼び出されている前提
#     next unless -f $arg && -r _;

#     open(my $fh, '<', $arg) or next;
#     my $first = <$fh>;
#     close($fh);

#     if (defined $first && $first =~ /^\s*%\s*\$?pdf_mode\s*=\s*([0-5])\s*;?(?=\s|$)/i) {
#         $pdf_mode = 0 + $1;
#         last;
#     }
# }

# ローカルのsty,clsが更新された場合にfmtを再生成するかどうか
our $TRACK_STY = 0; # 不要な場合は0にする

# do_cdされる前に実行ディレクトリ（プロジェクトルート）を取得する。ローカルsty,clsの収集に使う
# 必要なら $out_dir = "$PRJ_ROOT/out"; $aux_dir = "$PRJ_ROOT/.aux"; もあり
# "latex-workshop.latex.build.fromWorkspaceFolder": true が前提
my $PRJ_ROOT = abs_path(getcwd());
$TRACK_STY = 0 unless defined $PRJ_ROOT;

my $IS_WIN    = ($^O =~ /MSWin32|cygwin|msys/i) ? 1 : 0;
my $MAX_FILES = 1000; # プリアンブル精査対象ファイル数の上限。\inputがループして無限に続く場合などを除外

# 当該jobでfmtを使ってタイプセットすべきかをキャッシュしておく
my %fmt_enabled; # job -> (undef|0|1)

sub mylatex {
    my ($engine, $auxdir, $job, @args) = @_;

    my $src  = pop @args; # "hoge.tex" <- $quote_filenames = 1;
    my $opts = join(' ', @args);

    my $src_path = $src;
    $src_path =~ s/^"(.*)"\z/$1/; # 念のためファイル操作に使うものは""を外す

    my $fmt_path  = catfile($auxdir, "$job.fmt");
    my $sha_path  = catfile($auxdir, "$job.sha1");
    my $deps_path = catfile($auxdir, "$job.deps");
    my $lock_path = catfile($auxdir, "$job.fmtlock");

    my $cmd_fmt   = "$engine -fmt \"$fmt_path\" $opts $src";
    my $cmd_plain = "$engine $opts $src";

    open(my $lk, '>>', $lock_path) or die "Cannot open lock file $lock_path: $!";
    flock($lk, LOCK_EX);

    # 同一ビルド中の2回目以降のタイプセット
    if (defined $fmt_enabled{$job}) {
        if ($fmt_enabled{$job}) {
            print "mylatex: (cached) using fmt ...\n";
            return Run_subst($cmd_fmt);
        } else {
            print "mylatex: (cached) normal latex ...\n";
            return Run_subst($cmd_plain);
        }
    }

    my $sig_current = _calc_sig($src_path, $deps_path); # 現在のdepsで計算。後で更新が必要
    my $sig_saved   = _read_1line($sha_path);

    # プリアンブル部の編集、あるいはdeps内ファイルの編集を検知
    $fmt_enabled{$job} = (-e $fmt_path) && (defined $sig_saved) && ($sig_saved eq $sig_current);

    # fmt,deps,sha1を作る
    if (!$fmt_enabled{$job}) {
        # iniモードでの実行でfmtを生成する。同時に-recorderで現段階のflsを生成する
        print "mylatex: making fmt in ini mode...\n";
        my $amp_format = qq("&$engine"); # WindowsでもUNIXでも実行できるように
        my $ini_rc     = Run_subst("$engine -ini $opts -recorder -jobname=\"$job\" -output-directory=\"$auxdir\" $amp_format mylatexformat.ltx $src");

        if (($ini_rc == 0) && (-e $fmt_path)) {
            # ini実行時のflsを使ってローカルのsty等のパスをdepsに記録
            my $fls_path = catfile($auxdir, "$job.fls");
            _update_deps_from_fls($fls_path, $deps_path) if $TRACK_STY;

            # ソースのプリアンブルとdepsを使ってsha1を更新
            $sig_current = _calc_sig($src_path, $deps_path);
            _write_1line($sha_path, $sig_current);
            $fmt_enabled{$job} = 1;
        } else {
            warn "mylatex: fmt not found after ini; fallback to normal compile\n";
        }
    }

    if ($fmt_enabled{$job}) {
        print "mylatex: fmt detected & signature unchanged, so running with fmt...\n";
        return Run_subst($cmd_fmt);
    } else {
        print "mylatex: running normal latex (no fmt)...\n";
        return Run_subst($cmd_plain);
    }
}

sub _calc_sig {
    my ($src_path, $deps_path) = @_;
    my $pre_sig  = _calc_preamble_sig($src_path);
    my $deps_sig = $TRACK_STY ? _calc_deps_sig($deps_path) : "DEPS_IGNORED\n";
    return sha1_hex("PREAMBLE:$pre_sig\nDEPS:$deps_sig\n");
}

# subfilesや\inputを考慮しながらfmt対象のブリアンブル部をSHA-1化
sub _calc_preamble_sig {
    my ($src_path) = @_;

    my $target = _resolve_subfiles($src_path);

    my %seen; # 同一ファイルの複数回参照は無視
    my @queue = ($target);
    my $acc   = '';
    my $count = 0;

    # .texソースとそこで\inputされたファイルに対してループ
    while (@queue) {
        last if ++$count > $MAX_FILES;

        my $tex_path = shift @queue;
        next if $seen{$tex_path}++;

        my ($preamble, $inputs_ref) = _extract_preamble_and_inputs($tex_path);

        $acc .= "<<FILE:$tex_path>>\n";
        $acc .= $preamble;

        push @queue, @$inputs_ref if $inputs_ref && @$inputs_ref;
    }

    return sha1_hex($acc);
}

# ファイルの有効な1行目が\documentclass[hoge]{subfiles}であればhoge.texを、それ以外は引数の値をそのまま返す
# @param $target .texのパス
# @return プリアンブルハッシュ化の対象にすべき.texのパス
sub _resolve_subfiles {
    my ($target) = @_;
    open(my $fh, '<', $target) or return $target;

    my $first;

    while ($first = <$fh>) {
        $first = _normalize_tex_line($first);
        next if $first eq '';
        last;
    }
    close($fh);

    return $target unless defined $first;

    if ($first =~ /^\\documentclass\s*\[([^\]\\]+)\]\s*\{\s*subfiles\s*\}/i) {
        my $master = $1;
        $master =~ s/^\s+|\s+\z//g;

        if ($master ne '') {
            $master .= ".tex" unless $master =~ /\.tex\z/i;
            $target = catfile(dirname($target), $master);
        }
    }

    return $target;
}

# 空行やコメントは無視してキャッシュ化対象のプリアンブルを抽出する
# @param $tex_path ソースあるいはそこでinputされた.texのパス
# @return (プリアンブル部, その中の\inputのパス配列の参照)
sub _extract_preamble_and_inputs {
    my ($tex_path) = @_;
    my $preamble = '';
    my @inputs;

    open(my $fh, '<', $tex_path) or return ("", []);
    my $dir = dirname($tex_path);

    while (my $line = <$fh>) {
        $line = _normalize_tex_line($line);
        next if $line eq '';

        last
            if $line =~ /\\begin\{document\}/
            || $line =~ /\\endofdump\b/
            || $line =~ /\\csname\s+endofdump\s*\\endcsname/;

        while ($line =~ /\\input\s*(?:\{([^}]+)\}|([^\s]+))/g) {
            my $m    = defined($1) ? $1 : $2;
            my $path = _resolve_input_path($dir, $m);
            push @inputs, $path if defined $path;
        }

        $preamble .= $line . "\n";
    }

    close($fh);
    return ($preamble, \@inputs);
}

# ソースやそこにinputされた.texファイルに記載されたinputのパスを解決する
# @param $dir \inputが書かれた.texのdirパス
# @param $name \input{hoge}のhoge
# @return hogeをパス化したもの。ただし読み込めるかは別
sub _resolve_input_path {
    my ($dir, $name) = @_;
    $name =~ s/^\s+|\s+\z//g; # 前後の空白を削除
    return undef if $name =~ /\\/; # \input{\macro}などを弾く

    my $result = ($name =~ /\.\w+\z/) ? $name : "$name.tex";
    $result = file_name_is_absolute($result) ? $result : catfile($dir, $result);

    return -e $result ? $result : undef;
}

# depsに載っているファイルに対してmtime/sizeで署名を作る
sub _calc_deps_sig {
    my ($deps_path) = @_;
    return sha1_hex("NO_DEPS\n") unless defined $deps_path && -e $deps_path;

    open(my $fh, '<', $deps_path) or return sha1_hex("NO_DEPS\n");

    my @paths;

    while (my $line = <$fh>) {
        $line = _strip_eol($line);
        next if $line eq '';
        push @paths, $line;
    }
    close($fh);

    my $acc = '';

    foreach my $path (@paths) {
        if (-e $path) {
            my @st    = stat($path);
            my $mtime = $st[9] // 0;
            my $size  = $st[7] // 0;
            $acc .= "$path\0$mtime\0$size\n";
        } else {
            $acc .= "$path\0MISSING\n";
        }
    }

    return sha1_hex($acc);
}

# flsから取得したローカルのsty,clsをdepsに書き込む
sub _update_deps_from_fls {
    my ($fls_path, $deps_path) = @_;

    if (!-e $fls_path) {
        warn "mylatex: no .fls found ($fls_path). deps list not updated.\n";
        return;
    }

    my $deps = _extract_local_sty_from_fls($fls_path, $PRJ_ROOT);

    open(my $fh, '>', $deps_path) or die "Cannot write $deps_path: $!";
    print $fh "$_\n" for @$deps;
    close($fh);

    print "mylatex: deps updated: " . scalar(@$deps) . " files\n";
}

# ini実行時のflsのINPUTを精査し、$PRJ_ROOT以下で読み込まれているsty,cls配列の参照を返す
# @param $fls flsの相対/絶対パス
# @param $root ルートの絶対パス
sub _extract_local_sty_from_fls {
    my ($fls, $root) = @_;

    my $pwd; # INPUTが相対パスの場合に備えている。しかし、styやclsでそうなる場合があるかは不明
    my %seen;
    my @out;

    open(my $fh, '<', $fls) or return [];

    while (my $line = <$fh>) {
        $line = _strip_eol($line);

        if ($line =~ /^PWD\s+(.+)\s*\z/) {
            $pwd = $1;
            next;
        }

        next unless $line =~ /^INPUT\s+(.+)\s*\z/;
        my $input = $1;
        next unless $input =~ /\.(cls|sty)\z/i;

        # INPUT extractbb -B artbox -O hoge.pdfのような例を弾く
        # 空白ありの相対パスは知りません
        next if $input =~ /\s/ && !file_name_is_absolute($input);

        if (!file_name_is_absolute($input)) {
            next unless defined $pwd;
            $input = catfile($pwd, $input);
        }

        my $abs_input = abs_path($input) // next;
        next unless _is_path_under_root($abs_input, $root);

        my $key = _normalize_path_for_compare($abs_input);
        next if $seen{$key}++;
        push @out, $abs_input;
    }
    close($fh);

    @out = sort @out; # deps署名の安定性のため
    return \@out;
}

# targetファイルがrootディレクトリに含まれるかどうか
# @param $abs_target abs_path済みのファイルパス
# @param $abs_root abs_path済みのディレクトリパス
sub _is_path_under_root {
    my ($abs_target, $abs_root) = @_;
    return 0 unless defined $abs_target && defined $abs_root;

    $abs_target = _normalize_path_for_compare($abs_target);
    $abs_root   = _normalize_path_for_compare($abs_root);

    $abs_root .= '/' unless $abs_root =~ /\/\z/; # /a/b -> /a/b/
    return index($abs_target, $abs_root) == 0 ? 1 : 0;
}

# @param $path abs_path済みのパス
sub _normalize_path_for_compare {
    my ($path) = @_;
    return '' unless defined $path;

    # $path =~ s|/+$|| unless $path eq '/'; # 末尾の/は削除
    $path =~ s|\\|/|g; # /で統一
    $path = lc($path) if $IS_WIN; # WIN系では小文字で統一
    return $path;
}

# ファイルの一行目を読み込んで返す
sub _read_1line {
    my ($path) = @_;
    open(my $fh, '<', $path) or return undef;
    my $line = <$fh>;
    close($fh);
    return undef unless defined $line;
    $line =~ s/[\r\n]+\z//;
    return $line;
}

# ファイルを上書きする
sub _write_1line {
    my ($path, $value) = @_;
    open(my $fh, '>', $path) or die "Cannot write $path: $!";
    print $fh "$value\n";
    close($fh);
}

# コメント、改行コード、前後の空白を削除
# コメント判定は非エスケープの%以降。verbatim|%|とかを削除してしまうのは御愛嬌
sub _normalize_tex_line {
    my ($line) = @_;
    return undef unless defined $line;
    $line = _strip_eol($line);
    $line =~ s/(?<!\\)(?:\\\\)*\K%.*\z//; # コメントを削除
    $line =~ s/^\s+|\s+\z//g; # 前後の空白を削除
    return $line;
}

# chompの代わり
sub _strip_eol {
    my ($s) = @_;
    return undef unless defined $s;
    $s =~ s/[\r\n]+\z//;
    return $s;
}
