#!/usr/bin/env python3
"""Assemble auditable Chinese LaTeX from the archived Notion block tree."""
import hashlib
import json
import re
from pathlib import Path

from crawl import equation_text
from translation import CAPTIONS, TEXT

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "source"
BLOCKS = json.loads((SOURCE / "blocks.json").read_text(encoding="utf-8"))
IMAGES = json.loads((SOURCE / "images.json").read_text(encoding="utf-8"))
IMAGE_MAP = {image["block_id"]: image for image in IMAGES}
SECTIONS = [(0, "00_frontmatter"), (35, "01_mystery"), (44, "02_conflict"), (52, "03_anatomy"), (137, "04_mitigation"), (262, "05_conclusion")]

PREAMBLE = r"""\documentclass[UTF8,a4paper,11pt,fontset=none]{ctexart}
\usepackage[margin=2.25cm]{geometry}
\usepackage{fontspec}
\setmainfont{Liberation Serif}
\setsansfont{Liberation Sans}
\setmonofont[Scale=0.86]{Liberation Mono}
\setCJKmainfont[AutoFakeBold=2,AutoFakeSlant=0.18]{WenQuanYi Zen Hei}
\setCJKsansfont[AutoFakeBold=2]{WenQuanYi Zen Hei}
\setCJKmonofont{WenQuanYi Zen Hei Mono}
\usepackage{amsmath,amssymb,mathtools}
\usepackage{xcolor,graphicx,adjustbox}
\usepackage{caption,float,placeins}
\usepackage{enumitem,listings}
\usepackage[hyphens]{url}
\usepackage[unicode,colorlinks=true,linkcolor=blue!55!black,urlcolor=blue!65!black]{hyperref}
\usepackage{bookmark}
\hypersetup{pdftitle={当速度扼杀稳定性：揭秘训练与推理不匹配引发的强化学习崩溃},pdfauthor={Jiacai Liu, Yingru Li, Yuqian Fu, Jiawei Wang, Qian Liu, Yu Shen}}
\newcommand{\piv}{\textcolor{red!75!black}{\pi_\theta^{\mathrm{vllm}}}}
\newcommand{\pif}{\textcolor{blue!75!black}{\pi_\theta^{\mathrm{fsdp}}}}
\newcommand{\code}[1]{\texttt{\detokenize{#1}}}
\setlength{\parindent}{2em}
\setlength{\parskip}{0.35em}
\setlength{\emergencystretch}{2em}
\setlist{nosep,leftmargin=2em,topsep=0.4em}
\captionsetup{font=small,justification=justified,singlelinecheck=false}
\lstset{basicstyle=\ttfamily\footnotesize,breaklines=true,columns=fullflexible,keepspaces=true,showstringspaces=false,frame=single,rulecolor=\color{black!20},xleftmargin=0.5em,xrightmargin=0.5em}
\setcounter{tocdepth}{2}
\pagestyle{plain}
\title{\bfseries 当速度扼杀稳定性\\[0.4em]\Large 揭秘训练与推理不匹配引发的强化学习崩溃\\[0.5em]\large When Speed Kills Stability:\\Demystifying RL Collapse from the Training-Inference Mismatch}
\author{Jiacai Liu \and Yingru Li \and Yuqian Fu \and Jiawei Wang \and Qian Liu \and Yu Shen}
\date{原文首发：2025 年 9 月 17 日\\中文抓取译写版：2026 年 10 月 18 日}
\begin{document}
\maketitle
\begin{quote}\small
\textbf{译写说明。}本文根据作者公开 Notion 博客的完整页面快照翻译与重新排版，保留正文五节、更新动态、展开后的折叠推导、代码、原始配图及其链接。图内英文保留原样，图注译为中文。正文中的“我们”均指原作者。译注与原文区分标明。

来源：\href{https://yingru.notion.site/When-Speed-Kills-Stability-Demystifying-RL-Collapse-from-the-Training-Inference-Mismatch-271211a558b7808d8b12d403fd15edda}{作者 Notion 页面}；作者短链：\url{https://richardli.xyz/rl-collapse}。目录采用原文关联的 arXiv ID 2512.23075；本稿翻译对象为该博客。

作者信息按页面署名保留。原文 BibTeX 的最后一名作者为 Jiang, Zhuo，与页面署名中的 Yu Shen 不一致；引用块逐字保存，未擅自合并。
\end{quote}
\clearpage
\tableofcontents
\clearpage
"""


def heading(index, block, title):
    kind = block["type"]
    if kind == "header":
        level = "section"
    elif kind == "sub_header":
        level = "subsection"
    elif kind == "toggle" or block.get("depth", 0) >= 2:
        level = "paragraph"
    else:
        level = "subsubsection"
    out = r"\hypertarget{src-" + block["id"] + "}{}\n"
    out += "\\" + level + "*{" + title + "}\n"
    if level in {"section", "subsection"}:
        # Remove formatting from the PDF outline without altering printed text.
        outline = re.sub(r"\\texttt\{([^{}]*)\}", lambda m: m[1].replace(r"\_", "_"), title)
        out += r"\phantomsection" + "\n" + r"\addcontentsline{toc}{" + level + "}{" + outline + "}\n"
    return out


def equation(index, block):
    math = equation_text(block.get("properties", {}).get("title", []))
    # MathJax accepts an unbraced \text superscript; TeX requires a group.
    math = re.sub(r"\^\\text\{([^{}]+)\}", r"^{\\text{\1}}", math)
    if math.startswith(r"\small{") and math.endswith("}"):
        math = math[len(r"\small{"):-1]
    rows = [math]
    if index == 169:
        # Two displays avoid a fontspec/amsmath alignment interaction in the
        # available Tectonic bundle while keeping each equality readable.
        split = math.index("\n=")
        rows = [math[:split], "{}" + math[split:].strip()]
    elif index == 58:
        left, right = math.split(" = ", 1)
        rows = [left, "{}= " + right]
    displays = ["\n\\[\n\\adjustbox{max width=0.98\\linewidth}{$\\displaystyle " + row + "$}\n\\]\n" for row in rows]
    return "\n\\vspace{-1em}\n".join(displays)


def figure(indices):
    out = [r"\begin{figure}[H]", r"\centering"]
    for index in indices:
        block = BLOCKS[index]
        image = IMAGE_MAP[block["id"]]
        out.append(f"% source-block: {block['id']} (image)")
        out.append(r"\includegraphics[width=\linewidth,height=0.64\textheight,keepaspectratio]{" + image["path"] + "}")
        if len(indices) > 1:
            out.append(r"\par\smallskip")
    caption = CAPTIONS.get(indices[-1])
    if caption:
        out.append(r"\caption*{" + caption + "}")
    out.append(r"\end{figure}")
    return "\n".join(out) + "\n"


def main():
    (ROOT / "sections").mkdir(exist_ok=True)
    missing = []
    for index, block in enumerate(BLOCKS):
        kind = block["type"]
        if kind in {"page", "quote", "text", "header", "sub_header", "sub_sub_header", "bulleted_list", "numbered_list", "toggle", "external_object_instance"}:
            nonempty = bool("".join(item[0] for item in block.get("properties", {}).get("title", [])).strip())
            if (nonempty or kind == "external_object_instance") and index not in TEXT:
                missing.append((index, kind))
        if kind == "image":
            image = IMAGE_MAP[block["id"]]
            data = (ROOT / image["path"]).read_bytes()
            assert hashlib.sha256(data).hexdigest() == image["sha256"]
            if block.get("properties", {}).get("caption") and index not in CAPTIONS:
                missing.append((index, "caption"))
    if missing:
        raise RuntimeError(f"Missing translations: {missing}")

    translated = []
    for section_no, (start, filename) in enumerate(SECTIONS):
        end = SECTIONS[section_no + 1][0] if section_no + 1 < len(SECTIONS) else len(BLOCKS)
        lines = ["% Chinese translation assembled from source/blocks.json.", "% See source/translation.py for the translation and source/build_tex.py for assembly."]
        list_kind = None
        list_depth = None
        for index in range(start, end):
            block = BLOCKS[index]
            kind = block["type"]
            if list_kind is not None and block["depth"] <= list_depth and kind != list_kind:
                lines.append(r"\end{" + ("itemize" if list_kind == "bulleted_list" else "enumerate") + "}")
                list_kind = None
                list_depth = None
            lines.append(f"% source-block: {block['id']} ({kind}; source-index: {index})")
            translated.append(block["id"])
            if index in {0, 74}:
                # Title is in main.tex; the two panels of Figure 3 are emitted together.
                continue
            if kind in {"bulleted_list", "numbered_list"}:
                if list_kind is None:
                    list_kind = kind
                    list_depth = block["depth"]
                    lines.append(r"\begin{" + ("itemize" if kind == "bulleted_list" else "enumerate") + "}")
                references = {
                    22: (91, "第 3.4 节"),
                    23: (77, "第 3.3 节"),
                    24: (118, "第 3.5 节"),
                    25: (152, "第 4.2.1 节"),
                }
                crossref = ""
                if index in references:
                    target, label = references[index]
                    crossref = r"（见\hyperlink{src-" + BLOCKS[target]["id"] + "}{" + label + "}。）"
                lines.append(r"\item " + TEXT[index] + crossref)
            elif kind in {"header", "sub_header", "sub_sub_header", "toggle"}:
                lines.append(heading(index, block, TEXT[index]))
            elif kind == "equation":
                lines.append(equation(index, block))
            elif kind == "image":
                lines.append(figure([73, 74] if index == 73 else [index]))
            elif kind == "code":
                content = "".join(item[0] for item in block["properties"]["title"])
                code_file = "original-citation.bib" if index == 34 else "k3_vllm_kl.py"
                (SOURCE / code_file).write_text(content.rstrip() + "\n", encoding="utf-8")
                lines.append(r"\lstinputlisting{" + "source/" + code_file + "}")
            elif index in TEXT:
                lines.append(TEXT[index] + "\n")
            # Dividers, empty text, and container nodes carry no additional prose.
        if list_kind:
            lines.append(r"\end{" + ("itemize" if list_kind == "bulleted_list" else "enumerate") + "}")
        (ROOT / "sections" / (filename + ".tex")).write_text("\n\n".join(lines) + "\n", encoding="utf-8")
    inputs = "\n".join(r"\input{sections/" + filename + "}" for _, filename in SECTIONS)
    (ROOT / "main.tex").write_text(PREAMBLE + inputs + "\n\\end{document}\n", encoding="utf-8")

    assert translated == [block["id"] for block in BLOCKS]
    report = dict(blocks=len(BLOCKS), display_equations=sum(block["type"] == "equation" for block in BLOCKS), images=len(IMAGES), translated_text_blocks=len(TEXT), translated_captions=len(CAPTIONS), source_blocks_covered=len(translated), missing_translations=[], image_checksums="all matched", source_block_ids=translated)
    (SOURCE / "coverage.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: value for key, value in report.items() if key != "source_block_ids"}, ensure_ascii=False))


if __name__ == "__main__":
    main()
