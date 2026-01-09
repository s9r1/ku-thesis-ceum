\NeedsTeXFormat{LaTeX2e}
\ProvidesExplClass{ku-thesis-ceum}{2026-01-09}{0.1.0}
{Thesis class for CE and UM}

\sys_if_engine_uptex:T{
  \RequirePackage{plautopatch}
}

\DeclareOption*{\PassOptionsToClass{\CurrentOption}{jlreq}}
\ProcessOptions\relax

\LoadClass[
  book,
  openany,
  paper=a4paper,
  jafontsize=11pt,
  jafontscale=0.92,
  line_length=40zw,
  number_of_lines=35,
  headfoot_verticalposition=15mm,
]{jlreq}

\RequirePackage{graphicx}

% ------------------------------------------------------------
% Font
% ------------------------------------------------------------
\sys_if_engine_uptex:T{
  \RequirePackage[T1]{fontenc}
  \RequirePackage{jlreq-deluxe}

  \RequirePackage[haranoaji]{pxchfon}
  \setboldgothicfont{HaranoAjiGothic-Medium.otf}
}
\sys_if_engine_luatex:T{
  \RequirePackage{fontspec}
}

\RequirePackage[scale=1.05,semibold]{sourcesanspro}

% todo: luatexでも同様の処理が必要かどうか
% \bfseriesしたときに和文フォントでbではなくbxを使う
\DeclareFontShape{JY2}{hmc}{b}{n}{<->ssub*hmc/bx/n}{}
\DeclareFontShape{JT2}{hmc}{b}{n}{<->ssub*hmc/bx/n}{}
\DeclareFontShape{JY2}{hgt}{b}{n}{<->ssub*hgt/bx/n}{}
\DeclareFontShape{JT2}{hgt}{b}{n}{<->ssub*hgt/bx/n}{}

% 暫定
% https://github.com/anlp-nenji/nlproceedings/blob/main/nlproceedings.cls
\RequirePackage[defaultsups]{newtxtext}
\RequirePackage[bigdelims,vvarbb]{newtxmath}
\RequirePackage[cal=boondoxo]{mathalfa}

\newcommand{\headfont}{\sffamily\gtfamily\bfseries}

% ------------------------------------------------------------
% Headings
% ------------------------------------------------------------
% frontmatterが奇数ページの場合にmainmatterの前に空ページを足されないように
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
% Abstruct, Acknowledgment
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

% Appendixのページ番号をA-1形式にする
\jlreqsetup{
  appendix_postcode={
    % Hookするタイミングは\appendix後の\chapterの後でないといけない
    % しかしcmd/chapter/afterはHookできないので代わりがここ
    \AddToHookNext{cmd/jlreq@heading@maketoc@chapter/before}{
      \setcounter{page}{1}
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

% chapter関連
\renewcommand{\cftchapfont}{\headfont}
\renewcommand{\cftchappagefont}{\headfont}
\setlength{\cftchapnumwidth}{4zw}

% ------------------------------------------------------------
% Bibliography
% ------------------------------------------------------------
\RequirePackage{jlreq-complements}

\jlreqsetup{
  thebibliography_heading={
    \chapter*{\refname}
    \addcontentsline{toc}{chapter}{\protect\numberline{}\refname}
  }
}

% ------------------------------------------------------------
% Front Cover
% ------------------------------------------------------------
\newcommand\edate[1]{\newcommand\@edate{#1}}
\newcommand\header[1]{\newcommand\@header{#1}}
\newcommand\eheader[1]{\newcommand\@eheader{#1}}
\newcommand\affiliation[1]{\newcommand\@affiliation{#1}}

\renewcommand{\maketitle}{
  \begin{titlepage}
    \noindent
    \begin{minipage}[t]{0.7\textwidth}
      {
        \headfont
        \renewcommand{\jlreqkanjiskip}{0.04zw}
        \normalsize% kanjiskip適用のため必要
        京都大学大学院工学研究科
        \ifdefvoid{\@header}{}{\\\@header}
        \\\@date\par
      }
      \linespread{0.85}\selectfont
      \vspace{1em}
      \ifdefvoid{\@eheader}{}{\@eheader\\}
      Graduate~School~of~Engineering\\
      Kyoto~University
      \ifdefvoid{\@edate}{}{\\\@edate}
    \end{minipage}
    \hfill
    \begin{minipage}[t]{0.25\textwidth}
      \vspace{0pt}
      \raggedleft
      \includegraphics[width=25mm,pagebox=artbox]{E-B.pdf}
      \hspace*{1.5em}
    \end{minipage}

    \vspace{1.2em}
    \hrule height0.75pt
    \vspace{2.5cm}

    {
      \renewcommand{\jlreqkanjiskip}{0.12zw}
      \renewcommand{\jlreqxkanjiskip}{0.08zw}
      \begin{center}
        \fontsize{18pt}{36pt}\selectfont
        \@title
      \end{center}

      \vspace{3.5cm}
      \begin{center}
        \fontsize{16pt}{36pt}\selectfont
        京都大学大学院\hspace{1zw}工学研究科\hspace{1zw}
        \ifdefvoid{\@affiliation}{\@empty}{\@affiliation}
        \par\@author
      \end{center}
    }
  \end{titlepage}
}

% ------------------------------------------------------------
% Convenience Commands / Environments
% ------------------------------------------------------------
\newcommand{\figref}[1]{\figurename\ref{#1}}
\newcommand{\tabref}[1]{\tablename\ref{#1}}
\newcommand{\eqnref}[1]{式\eqref{#1}}
