%%%%%%%%%
%
% Basic style file for THU-C3I papers, internal reports, and unpublished %
% papers.
%
% This class allows for several options depending on the preferences of the authors.
% Use it in the following way, with the full set of option possible:
% \documentclass[11pt, a4paper, twocolumn, copyright, nonumbering,
% internal, thu]{thuc3i}
%
% Options:
%    - 11pt: Sets the normal font size of the text. Can be only 10, 11, 12pt.
%    - a4paper: Paper size. Usually would not adjust.
%    - twocolumn: Makes the paper into two column mode; single column by default.
%    - copyright: Add a copyright statement to the first page of the paper in the left footnote
%    - nonumbering: Uses unnumbered sections.
%    - confidential: add labels for internal only reports that should not be shared externally.
%           Can only use techreportnumber with this option.
%.   - thu/c3i/full: select a template for different logo styles. Use thu for THU logo, c3i for C3I logo, or c3i-full for full THU-C3I logo (default).
%
% Date of Paper
%   The report is by default given the current date in the top right. If you want to fix the
%   date: add the date to your preamble with your own date as follows:
%   \renewcommand{\today}{1 January 2000}
%
% Confidentiality
%   Change the confidentiality statement for internal docs by adding this in the preamble
%   \renewcommand{\internalonly}{Confidential.}
%
%  
%
% ----------------
% Licence: This template is released under the Creative Commons licence
% Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
%
%
% Known issues:
%   - Package todonotes does not work in the abstract
%
% Version history:
% v0.5, March 2025 - Allow for more logos. Change too google.cls
% v0.4, Sept 2023 - Update to Google DeepMind unit
% v0.31, May 2019 - Allow corresponding authors without internal option
% v0.3, March 2019 - Math font consistency, better handling of optional arguments
% v0.2, January 2019 - Consistency of fonts, margins, additional notes
% v0.1, December 2018 - Initial version for testing
%
% Ongoing Review
%    We review and improve this regularly.
%    Send comments to shakir@
%
%
% %%%%%%%%%%%%%%%
\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{thuc3i} % no versioning; versioning does not work well with arxiv.

%%======== Package options and base class ========
\RequirePackage{xifthen}
\newboolean{nonumbering}
\newboolean{address}
\newboolean{copyright}
\newboolean{confidential}
\DeclareOption{nonumbering}{\setboolean{nonumbering}{true}}
\DeclareOption{address}{\setboolean{address}{true}}
\DeclareOption{copyright}{\setboolean{copyright}{true}}
\DeclareOption{confidential}{\setboolean{confidential}{true}}
\DeclareOption*{\PassOptionsToClass{\CurrentOption}{extarticle}}
\ProcessOptions
\LoadClass{extarticle}

%%======== Packages Required ========
% Fonts and language
\AtEndOfClass{\RequirePackage[tracking=smallcaps]{microtype}}

\RequirePackage[english]{babel}
\RequirePackage{amsthm, amsmath, amsfonts, amssymb}
\RequirePackage{cmap}

\RequirePackage{url}
\RequirePackage[colorlinks=true, allcolors=darkblue]{hyperref}
\RequirePackage{pifont}
\RequirePackage[dvipsnames]{xcolor}
\RequirePackage{textcomp} % For copyright symbol styling
\RequirePackage[overload]{textcase}
%\RequirePackage{balance}
%% *Graphics, tables and other formatting
\RequirePackage{graphicx}
\RequirePackage{colortbl}
\RequirePackage{booktabs}
% \RequirePackage[most]{tcolorbox}

%% Define dark blue color for hyperlinks
\definecolor{darkblue}{rgb}{0, 0, 0.5}
\RequirePackage{changepage}
\RequirePackage{enumitem} % For reducing bullet list item separation
\RequirePackage{tabularx}
\RequirePackage{datetime}
% Headers and footers
\RequirePackage{fancyhdr}  % custom headers/footers
\RequirePackage{lastpage}  % Number of pages in the document
% Lists and their spacing
\RequirePackage{enumitem}
\setlist[itemize]{noitemsep}
\setlist[itemize]{nosep}
% \setlist[itemize]{itemsep=0pt, parsep=0pt, topsep=0pt, partopsep=0pt}
\setlist[enumerate]{noitemsep}
% Title, Abstract, Bibliography
\RequirePackage[explicit]{titlesec}
\RequirePackage{bibentry}
% \RequirePackage{mdframed}
\RequirePackage{caption}
\RequirePackage{needspace}
\RequirePackage{soul}
\RequirePackage{kvoptions}


%%======== Can use any of these fonts ========
%\RequirePackage{charter}
%\RequirePackage[scaled]{helvet}
%\RequirePackage{bookman}
%\RequirePackage{times}
%\RequirePackage[default]{opensans} %fosfamily
%\usepackage{antpolt}
% Math fonts
%\RequirePackage{mathpazo} % Palatino
%\usepackage{euler} % for math fints

% Use Bitstream Charter as the main font. Does not include a typewriter font.
\RequirePackage{XCharter}
\RequirePackage[xcharter,bigdelims,vvarbb]{newtxmath}

% Use the typewriter font from lmodern, scaled up to match Charter's xheight.
% You may wish to add the "p" option to use the proportional font instead of
% the monospaced one, which might look nicer in cases where you do not need
% aligned columns
\RequirePackage[scaled=1.1]{zlmtt}

%%======== Margins and column spacing ========
\RequirePackage[left=2.2cm,%
right=2.2cm,%
top=3cm,%
bottom=3cm,%
headheight=40pt,%
headsep=20pt,%
%showframe, % for testing
a4paper]{geometry}%
\setlength{\columnsep}{15pt} % Distance between the two columns of text
\setlength{\parindent}{0pt}
% \setlength{\parindent}{1.5em}
\setlength{\parskip}{0.5\baselineskip}

%% *Custom font sizes and styles
\newcommand{\watermarkfont}{\color{black50}\normalfont\fontsize{10}{12}\selectfont}
% \newcommand{\headerfont}{\normalfont\sffamily\fontsize{8}{10}\selectfont}
\newcommand{\headerfont}{\color{black}\normalfont\bfseries\fontsize{10}{12}\selectfont}
\newcommand{\titlefont}{\color{darkblue}\normalfont\bfseries\fontsize{18}{23}\selectfont}
\newcommand{\datesfont}{\normalfont\sffamily\itshape\fontsize{8}{10}\selectfont}
\newcommand\urlheaderfont{\color{blue}\fontsize{8}{10}\selectfont}
\newcommand{\absfont}{\linespread{1.2}\fontsize{10}{12}\selectfont}
\newcommand{\keywordstitlefont}{\bfseries\linespread{1.2}\fontsize{8}{10}\selectfont}
\newcommand{\keywordsfont}{\itshape\linespread{1.2}\fontsize{11}{12}\selectfont}
\newcommand{\copyrightfont}{\normalfont\fontsize{7}{9}\selectfont}
\newcommand{\footerfont}{\color{black}\normalfont\fontsize{10}{12}\selectfont}
\newcommand{\subjectfont}{\color{white}\bfseries\fontsize{10}{12}\selectfont}
\newcommand{\headingfont}{\color{darkblue}\bfseries\fontsize{13}{14}\selectfont}

\newcommand{\keywords}[1]{\def\@keywords{#1}}
\newtoks\correspondingauthor
\newtoks\paperurl
\newtoks\reportnumber

% Dates and Times for footer
% ISO-8601 date format
\newdateformat{monthyeardate}{\THEYEAR-\twodigit{\THEMONTH}-\twodigit{\THEDAY}}

\setcounter{secnumdepth}{3}
\ifthenelse{\boolean{nonumbering}}{\setcounter{secnumdepth}{0}}{}

%%========  Author and affiliation ========
\RequirePackage{authblk}
\setcounter{Maxaffil}{0}
\setlength{\affilsep}{0.5em}
\renewcommand\Authfont{\normalfont\bfseries\fontsize{9}{13}\selectfont}
\renewcommand\Affilfont{\normalfont\fontsize{8}{10}\selectfont}
\makeatletter
\renewcommand\AB@affilsepx{, \protect\Affilfont}
\makeatother
\renewcommand\Authands{ and }

% Role functionality - similar to affil but for author roles
\newcounter{role}
\newcommand\Rolefont{\normalfont\fontsize{10}{12}\selectfont}
\makeatletter
\newcommand\role[2][]{\stepcounter{role}%
  \expandafter\gdef\csname @role\therole\endcsname{#2}%
  \ifx\relax#1\relax
    \expandafter\gdef\csname @rolelabel\therole\endcsname{}%
  \else
    \expandafter\gdef\csname @rolelabel\therole\endcsname{$^{#1}$}%
  \fi
}

% Command to format and display all roles
\newcommand{\@roles}{%
  \ifnum\value{role}>0
    \vskip-2pt
    {\raggedright \Rolefont
      \@tempcnta=1
      \loop
        \ifcsname @role\the\@tempcnta\endcsname
          \csname @rolelabel\the\@tempcnta\endcsname\csname @role\the\@tempcnta\endcsname
          \advance\@tempcnta by 1
          \ifnum\@tempcnta>\value{role}\else, \fi
        \fi
      \ifnum\@tempcnta>\value{role}\else\repeat
    \par}
  \fi
}

% Resource functionality - similar to role but for contact info and resources
\newcounter{resource}
\newcommand\Resourcefont{\normalfont\fontsize{10}{12}\selectfont}
\newcommand\resource[2]{\stepcounter{resource}%
  \expandafter\gdef\csname @resource\theresource\endcsname{#2}%
  \ifx\relax#1\relax
    \expandafter\gdef\csname @resourcelabel\theresource\endcsname{}%
  \else
    \expandafter\gdef\csname @resourcelabel\theresource\endcsname{\protect#1~}%
  \fi
}

% Command to format and display all resources
\newcommand{\@resources}{%
  \ifnum\value{resource}>0
    \vskip-2pt
    {\raggedright \Resourcefont
      \@tempcnta=1
      \loop
        \ifcsname @resource\the\@tempcnta\endcsname
          \csname @resourcelabel\the\@tempcnta\endcsname\csname @resource\the\@tempcnta\endcsname
          \advance\@tempcnta by 1
          \ifnum\@tempcnta>\value{resource}\else, \fi
        \fi
      \ifnum\@tempcnta>\value{resource}\else\repeat
    \par}
  \fi
}
\makeatother

\newcommand{\internalonly}{\hl{Confidential---Do not share or forward externally}}
\newcommand{\copyrightext}{\footerfont \textcopyright\, \the\year{} THU-C3I. All rights
reserved}


%%======== Set template and Logo ========
% --- Provide User Command for PA Name ---

\newcommand{\pafullname}{} % store the PA name

% Command to set header text when no logo is used
\newtoks\headertext
\newcommand{\setheadertext}[1]{\headertext{#1}}

% --- Process Standard Class Options ---
% Still useful for standard options like 10pt, 11pt, etc.
\DeclareOption* {\PassOptionsToClass{\CurrentOption}{article}}
\ProcessOptions\relax % Process standard options like 10pt, etc.

% Declare the options corresponding to the research group
% We use lowercase simple names for the options
\def\@selectedlogo{0} % Default to no logo
\newcommand{\uselogo}[1]{#1}
\DeclareOption{thu}{
    \renewcommand{\pafullname}{Tsinghua University}%
    \renewcommand{\uselogo}[1]{\gdef\@selectedlogo{1}}%
}
\DeclareOption{c3i}{
    \renewcommand{\pafullname}{THU-C3I}%
    \renewcommand{\uselogo}[1]{\gdef\@selectedlogo{2}}%
}
\DeclareOption{c3i-full}{
    \renewcommand{\pafullname}{Tsinghua-C3I}%
    \renewcommand{\uselogo}[1]{\gdef\@selectedlogo{3}}%
}
% --- Default Option ---
% Set a default option if no option is explicitly given in \documentclass
\ExecuteOptions{c3i-full} % Default to full THU-C3I logo

% --- Handle Unrecognized Options ---
% Pass any other options (like '12pt', 'twoside') to the base class ('article')
\DeclareOption* {\PassOptionsToClass{\CurrentOption}{article}}

% --- Process Options ---
% Execute the code associated with the options provided (or the default)
\ProcessOptions\relax

% --- Provide User Command for Company Name ---
% Define a user-friendly command to access the stored full company name
% This should be done *after* \ProcessOptions
\newcommand{\thepa}{\pafullname}


%%======== Header and Footer Content ========
% Header and Footer for the first page
\pagestyle{fancy}   % Enables the custom headers/footers
\fancypagestyle{firststyle}{
	\fancyhead[L]{
	 \ifcase\@selectedlogo % Case 0: No logo
        \ifdefined\headertext
        \if\relax\the\headertext\relax
        \else {\headerfont\the\headertext} \fi
        \else \fi
      \or % Case 1
        \includegraphics[height=18pt]{assets/logo_Google_FullColor}
      \or % Case 2
        \includegraphics[height=18pt]{assets/logo_GoogleDeepMind_FullColor}
      \or % Case 3
        \includegraphics[height=18pt]{assets/logo_GoogleResearch_FullColor}
      \else % Should not happen due to the \uselogo command's checks
      \fi
}
\fancyhead[R]{
	\ifdefined\paperurl
	\if\relax\the\paperurl\relax \else
		\href{\the\paperurl}{\urlheaderfont \itshape \the\paperurl}\\ \fi
	\else 
	\fi
	{\footerfont\itshape\monthyeardate\today}
	\ifthenelse{\boolean{confidential}}{\\ \footerfont \internalonly}{}
}
\fancyhead[C]{}
%
\fancyfoot[L]{
    %\ifthenelse{\boolean{confidential}}{\footerfont \internalonly \\}{\footerfont\bfseries\relax}
    \ifdefined\correspondingauthor
	\if\relax\the\correspondingauthor\relax
	\else \footerfont\itshape  {Corresponding author(s): \the\correspondingauthor \\} \fi
	\else \fi
	\ifthenelse{\boolean{copyright}}{\copyrightext}{}
}
\fancyfoot[R]{
	\ifthenelse{\boolean{confidential}}{
	\ifdefined\reportnumber
	\if\relax\the\reportnumber\relax
	\else \footerfont\itshape  {\footerfont \thepa{} Technical Report \the\reportnumber} \fi
	\else \fi
	}{\footerfont\bfseries\relax}
}
\fancyfoot[C]{
    \footerfont\bfseries\relax}
}

% Header and Footer for pages from 2 onwards
\fancyhead[L,R]{}
\makeatletter
\fancyhead[C]{\footerfont \@title}
% \fancyhead[R]{
% 	\ifthenelse{\boolean{confidential}}{\footerfont \internalonly}{}
% }
\makeatother
\fancyfoot[C]{}
% \fancyfoot[L]{
% 	\ifthenelse{\boolean{confidential}}{\footerfont \internalonly\newline
% 		\ifdefined\reportnumber
% 		\if\relax\the\reportnumber\relax
% 		\else \footerfont {\thepa{} TR-\the\reportnumber} \fi
% 		\else \fi}{\footerfont\bfseries\relax}
% }
\fancyfoot[L]{
	\ifthenelse{\boolean{confidential}}{\footerfont \internalonly}{\footerfont\bfseries\relax}
}
\fancyfoot[R]{\footerfont 	
    %\ifdefined\reportnumber
	%\if\relax\the\reportnumber\relax
	%\else \footerfont\itshape  {\footerfont \thepa{} Technical Report \the\reportnumber} \fi
	%\else \fi \hspace{10mm} 
	\thepage}

% Header and footer rules (coloured).
\renewcommand{\headrulewidth}{1pt}
\renewcommand{\footrulewidth}{1pt}
\let\DefaultHeadRule\headrule
\let\DefaultFootRule\footrule
\renewcommand{\headrule}{\color{black}\DefaultHeadRule}
\renewcommand{\footrule}{\textcolor{black}{\DefaultFootRule}}

\renewenvironment{abstract}
{\par\noindent\\  \ignorespaces}
{\par\bigskip}

%%========  Bibliography using bibtex ========
\addto{\captionsenglish}{\renewcommand{\refname}{References}}
\newcommand{\citeas}[1]{\Needspace*{8\baselineskip}\noindent\bibentry{#1}}
% Uncomment the next line if you want the  numbered refs to be "1." instead of "[1]".
%\makeatletter \renewcommand\@biblabel[1]{#1.} \makeatother

%%======== Abstract and section formatting ========
\def\xabstract{abstract}
\long\def\abstract#1\end#2{\def\two{#2}\ifx\two\xabstract
	\long\gdef\theabstract{\ignorespaces#1}
	\def\go{\end{abstract}}\else
\typeout{^^J^^J PLEASE DO NOT USE ANY \string\begin\space \string\end^^J
	COMMANDS WITHIN ABSTRACT^^J^^J}#1\end{#2}
\gdef\theabstract{\vskip12pt BADLY FORMED ABSTRACT: PLEASE DO
NOT USE {\tt\string\begin...\string\end} COMMANDS WITHIN
THE ABSTRACT\vskip12pt}\let\go\relax\fi
\go}

% Define an environment with abstract content and styling
\makeatletter
\newcommand{\abscontent}{
	\noindent
	% \parbox{\dimexpr\linewidth}{\absfont \theabstract}
	\parbox{\dimexpr\linewidth}{\textbf{Abstract $\vert$} \absfont \theabstract}
	\@ifundefined{@keywords}{}{
		\vskip1em \noindent \keywordsfont  Keywords: \@keywords}
}

\if@twocolumn%
\renewcommand{\maketitle}{
	\twocolumn[
	\begin{adjustwidth}{0pt}{24pt}
		\begin{flushleft}
			{
				{ \raggedright \titlefont
				\@title\par}%
				\vskip11pt
				{\raggedright \@author\par}
				\@roles
				\@resources
				\vskip3pt%
			}%
		\end{flushleft}
	\end{adjustwidth}
	% Add black line above abstract
	\noindent\textcolor{black}{\rule{\linewidth}{1pt}}
	\vskip8pt
		\abscontent
	\vskip20pt%
	]
	\thispagestyle{firststyle}
}%
\else% \@twocolumnfalse
\newcommand{\@pretitlefigure}{}
\newcommand{\pretitlefigure}[1]{\renewcommand{\@pretitlefigure}{#1}}
\renewcommand{\maketitle}{\bgroup\setlength{\parindent}{0pt}
	\begin{adjustwidth}{0pt}{24pt}
		\begin{flushleft}
			{
				{\raggedright \titlefont \@title\par}%
				\vskip11pt
				{\raggedright \@author\par}
				\@roles
				\@resources
				\vskip3pt%
			}%
		\end{flushleft}
	\end{adjustwidth}
	\egroup
	% Add black line above abstract
	\noindent\textcolor{black}{\rule{\linewidth}{1pt}}
	\vskip5pt
	\@pretitlefigure
	{%
		{\abscontent}
	}%
	\thispagestyle{firststyle}
}%
\fi
\makeatother

\titleformat{\section}
{\large\bfseries\headingfont}
{\thesection.}
{0.5em}
%{\MakeUppercase{#1}}[]
{#1}
[]
\titleformat{name=\section,numberless}
{\large\bfseries\headingfont}
{}
{0em}
%{\MakeUppercase{#1}}[]
{#1}
[]
\titleformat{\subsection}
{\color{darkblue}\bfseries}
{\thesubsection.}
{0.5em}
{#1}
[]
\titleformat{\subsubsection}% [runin] If want to have inline for the subsubsect
{\color{darkblue}\bfseries\itshape}
{\thesubsubsection.}
{0.5em}
{#1}
[]

\titlespacing*{\section}{0pc}{3ex plus4pt minus3pt}{5pt}
%\titlespacing*{\section}{0pc}{1ex }{\baselineskip}
\titlespacing*{\subsection}{0pc}{2.5ex plus3pt minus2pt}{2pt}
\titlespacing*{\subsubsection}{0pc}{2ex plus2.5pt minus1.5pt}{2pt}
% \titlespacing*{\paragraph}{0pc}{2ex plus2pt minus1pt}{0pt}
\titleformat{\paragraph}[runin]{\bfseries}{}{-0.5em}{#1}
\titlespacing*{\paragraph}{0pt}{0ex}{.33em}
%%======== Captions in tables and figures ========
\DeclareCaptionLabelSeparator{pipe}{ $\vert$ }% or $\vert$
\captionsetup{labelfont={bf}, %{bf,sf},%
labelsep=space,%
figurename=Figure,%
labelsep=pipe,
singlelinecheck=off,%
%justification=centering
}
