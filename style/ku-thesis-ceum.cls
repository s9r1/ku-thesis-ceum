\NeedsTeXFormat{LaTeX2e}[2022-06-01]
\ProvidesExplClass{ku-thesis-ceum}{2026-11-03}{0.2.0}
{Thesis class for CE and UM}

\sys_if_engine_luatex:F {
  \sys_if_engine_uptex:TF {
    \RequirePackage{plautopatch}
  } {
    \msg_new:nnn { ku-thesis-ceum } { bad-engine }
    { LuaLaTeX~or~upLaTeX~required. }
    \msg_fatal:nn { ku-thesis-ceum } { bad-engine }
  }
}

\str_new:N \g_kuth_degree_str
\str_gset:Nn \g_kuth_degree_str { master }% 未指定対策

\clist_new:N \g__kuth_pass_clist

\bool_new:N \g__kuth_bibsec_bool

\keys_define:nn { ku-thesis-ceum / option } {
  doctor   .code:n = \str_gset:Nn \g_kuth_degree_str { doctor },
  master   .code:n = \str_gset:Nn \g_kuth_degree_str { master },
  bachelor .code:n = \str_gset:Nn \g_kuth_degree_str { bachelor },

  bibsec .bool_gset:N = \g__kuth_bibsec_bool,
  bibsec .default:n = true,

  unknown .code:n = {
    \clist_gput_right:No \g__kuth_pass_clist { \CurrentOption }
  }
}

\ProcessKeyOptions[ku-thesis-ceum/option]
\PassOptionsToClass{\g__kuth_pass_clist}{jlreq}

% jlreq初期化の際にcmrでのサイズ代替を防止
\RequirePackage{fix-cm}

\str_if_eq:VnTF \g_kuth_degree_str { bachelor } {
  \PassOptionsToClass{
    jafontsize=12pt,line_length=36zw,number_of_lines=31
  }{jlreq}
} {
  \PassOptionsToClass{
    jafontsize=11pt,line_length=40zw,number_of_lines=35
  }{jlreq}
}

\LoadClass[
  book,
  openany,
  paper=a4paper,
  jafontscale=0.92,
  baselineskip=1.8zw% デフォルトは1.7zw
]{jlreq}

\RequirePackage{graphicx}
\RequirePackage[superscript]{cite}
\RequirePackage[hidelinks]{hyperref}
\sys_if_engine_uptex:T {
  \RequirePackage{pxjahyper}
}

% ------------------------------------------------------------
% Fonts
% ------------------------------------------------------------
% 和文フォントはjlreq標準を採用

\RequirePackage[scale=1.05,semibold]{sourcesans}
\RequirePackage[defaultsups]{newtxtext}
\RequirePackage[vvarbb,amsthm]{newtxmath}
\RequirePackage[cal=boondoxo]{mathalpha}

\newcommand{\headfont}{\sffamily\bfseries}

% ------------------------------------------------------------
% Headings
% ------------------------------------------------------------
% frontmatterが奇数ページの場合にmainmatter前に空ページが挿入されるのを防止
\jlreqsetup{mainmatter_pagebreak=clearpage}

\ModifyHeading{chapter}{
  font=\headfont\LARGE,
  lines=2,
  after_lines=1
}

\ModifyHeading{section}{
  font=\headfont\large,
  lines=2,
  before_lines=1
}

\ModifyHeading{subsection}{
  font=\headfont,
  lines=1,
  before_lines=1
}

\SetBlockHeadingSpaces{
  {_chapter{*},_section{lines=2,before_lines=0},_subsection{before_lines=0}},
  {_chapter{*},_section{lines=2,before_lines=0}},
  {_section{*},_subsection{before_lines=0}}
}

% ------------------------------------------------------------
% Figures and Tables
% ------------------------------------------------------------
\AddToHook{env/table/begin}{
  \setlength{\belowcaptionskip}{\abovecaptionskip}
}

% ------------------------------------------------------------
% Abstract, Acknowledgment
% ------------------------------------------------------------
\NewDocumentCommand{\Yoshi}{O{論文要旨}}{
  \clearpage
  {\centering\headfont #1\par}
  \vspace{\baselineskip}
}

\NewDocumentCommand{\Shaji}{O{謝辞}}{
  \chapter*{#1}
  \addcontentsline{toc}{chapter}{\protect\numberline{}#1}
}

% ------------------------------------------------------------
% Bibliography
% ------------------------------------------------------------
\bool_if:NT \g__kuth_bibsec_bool {
  \RequirePackage{chapterbib}
}

\jlreqsetup{
  thebibliography_heading={
    \bool_if:NTF \g__kuth_bibsec_bool {
      \section*{\refname}
    } {
      \chapter*{\refname}
      \addcontentsline{toc}{chapter}{\protect\numberline{}\refname}
    }
  }
}

\renewcommand{\@citess}[1]{
  % \kern0ptで1)前の和文とのアキ追加を防止
  % )ではなく\symbol{41}なのはtex-fmtの都合
  \kern0pt\textsuperscript{#1\symbol{41}}
}
\renewcommand{\@biblabel}[1]{#1\symbol{41}}

% ------------------------------------------------------------
% Appendix
% ------------------------------------------------------------
\jlreqsetup{
  appendix_postcode={
    % Hookのタイミングは\appendix後の\chapterの後
    % しかしcmd/chapter/afterはHookできないので代わりがここ
    \AddToHookNext{cmd/jlreq@heading@maketoc@chapter/before}{
      \renewcommand{\thepage}{\thechapter-\arabic{page}}
    }
    \AddToHook{cmd/jlreq@heading@maketoc@chapter/before}{
      \setcounter{page}{1}
    }
  }
}

% ------------------------------------------------------------
% Table of Contents
% ------------------------------------------------------------
\RequirePackage{tocloft}

\renewcommand{\cfttoctitlefont}{\headfont\LARGE}
\setlength{\cftbeforetoctitleskip}{0pt}
\setlength{\cftaftertoctitleskip}{1\baselineskip}
\pretocmd{\@cfttocstart}{\clearpage}{}{}

\renewcommand{\cftchapfont}{\headfont}
\renewcommand{\cftchappagefont}{\headfont}
\setlength{\cftchapnumwidth}{4\zw}

\setcounter{tocdepth}{2}

% ------------------------------------------------------------
% Front Cover
% ------------------------------------------------------------
\newcommand\edate[1]{\newcommand\@edate{#1}}
\newcommand\affiliation[1]{\newcommand\@affiliation{#1}}

\renewcommand{\maketitle}{
  \str_if_eq:VnTF \g_kuth_degree_str { master } {
    \__kuth_master_cover:
  } {
    \__kuth_common_cover:
  }
}

\cs_new_protected:Npn \__kuth_common_cover: {
  \begin{titlepage}
    \centering
    \renewcommand{\jlreqkanjiskip}{0.12\zw}
    \vspace*{3.5cm}
    \fontsize{20pt}{36pt}\selectfont
    \@title\par
    \vfill
    {
      \fontsize{18pt}{36pt}\selectfont
      \@date\par
      \str_if_eq:VnT \g_kuth_degree_str { bachelor } {
        京都大学工学部地球工学科土木工学コース\par
        \vspace{6mm}
      }
    }
    \vspace{2mm}
    \@author\par
    \vspace{3.5cm}
  \end{titlepage}
}

\cs_new_protected:Npn \__kuth_master_cover: {
  \begin{titlepage}
    \vspace*{1mm}
    \noindent
    \begin{minipage}[t]{0.7\textwidth}
      \vspace{0pt}
      {
        \headfont
        \renewcommand{\jlreqkanjiskip}{0.05\zw}
        \jafontsize{12pt}{18pt}\selectfont
        京都大学大学院工学研究科\par
        都市社会工学専攻修士論文\par
        \@date\par
      }
      \vspace{6mm}
      \fontsize{12pt}{15pt}\selectfont
      Master's~Thesis\par
      Department~of~Urban~Management\par
      Graduate~School~of~Engineering\par
      Kyoto~University
      \ifdefvoid{\@edate}{}{\par\@edate}
    \end{minipage}
    \hfill
    \begin{minipage}[t]{0.25\textwidth}
      \vspace{0pt}
      \raggedleft
      \includegraphics[width=2.5cm,pagebox=artbox]{E-B.pdf}
      \hspace*{5mm}
    \end{minipage}

    \vspace{4.5mm}
    \hrule height0.75pt
    \vspace{2.5cm}

    \centering
    \renewcommand{\jlreqkanjiskip}{0.12\zw}
    \fontsize{18pt}{36pt}\selectfont
    \@title\par
    \vspace{3.5cm}
    \fontsize{16pt}{36pt}\selectfont
    京都大学大学院\hspace{1\zw}工学研究科\hspace{1\zw}都市社会工学専攻
    \ifdefvoid{\@affiliation}{}{\par\@affiliation}
    \par\@author\par
  \end{titlepage}
}

% ------------------------------------------------------------
% Convenience Commands / Environments
% ------------------------------------------------------------
\newcommand{\figref}[1]{\figurename\ref{#1}}
\newcommand{\tabref}[1]{\tablename\ref{#1}}
\newcommand{\eqnref}[1]{式\eqref{#1}}
