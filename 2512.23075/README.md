# 当速度扼杀稳定性：训练与推理不匹配引发的强化学习崩溃

本目录收录所给 Notion 博客的完整抓取快照和中文 LaTeX 译写版。阅读入口为 [中文 PDF](main.pdf)，排版入口为 [main.tex](main.tex)。原文首发于 2025 年 9 月 17 日，本地抓取与译写日期为 2026 年 10 月 18 日。[^article]

目录沿用博客关联论文的 arXiv ID `2512.23075`；翻译对象是博客《When Speed Kills Stability: Demystifying RL Collapse from the Training-Inference Mismatch》。关联论文现题为《Trust Region Masking for Long-Horizon LLM Reinforcement Learning》，与该博客的题名、作者表及内容范围不同。[^paper]

## 内容与对照

中文文稿包含内容提要、更新动态、五节正文、完整图注，以及原页面两层折叠内容中的代码和数学推导。共覆盖 271 个页面内容块、22 个独立公式和 29 张配图。公式从页面的 LaTeX 表达式提取，仅进行分组、断行等排版适配；图内英文保留原样，图注译为中文。正文中的“我们”指原作者。

| 材料 | 入口 |
| --- | --- |
| 中文排版源码 | [main.tex](main.tex)、[sections/](sections/) |
| 英文原文导出 | [original.en.md](source/original.en.md) |
| 原始 Notion 数据与 HTML | [source/](source/)、[original-page.html](source/original-page.html)；HTML 为页面壳，正文见 JSON 快照 |
| 原文配图及校验值 | [figures/](figures/)、[images.json](source/images.json) |
| 页面来源、日期与署名 | [metadata.json](source/metadata.json) |
| 原文代码与引用块 | [K3 估计器](source/k3_vllm_kl.py)、[原始 BibTeX](source/original-citation.bib) |
| 完整性核对与编译检查 | [覆盖核对](source/coverage.json)、[快照校验清单](source/snapshot-manifest.json)、[验证结果](source/validation.json) |

页面署名的最后一位作者是 Yu Shen，页面 BibTeX 中的最后一位作者却是 Jiang, Zhuo；两处均按原文保留，并在译写说明中注明。另以“译注”标出未归一化状态占用测度、优势的样本估计、TIS/MIS 引入偏差、BF16 机制假设，以及图 17 正文与图注对稳定性描述的差别。实验结论保留模型、硬件和任务条件，未将其扩展为通用保证。

## 编译

使用 Tectonic 0.17.0 完成编译。源码使用 `ctexart`，需要文泉驿正黑（WenQuanYi Zen Hei，包括 Mono 字体族）与 Liberation Serif/Sans/Mono 字体。Tectonic 首次运行会按需下载 TeX 包。

在本目录执行：

```bash
./build.sh
```

若 Tectonic 未加入 `PATH`，可以指定可执行文件。当前机器验证命令为：

```bash
TECTONIC=/tmp/multi-harness-authoring/tectonic ./build.sh
```

输出为 `main.pdf`，编译日志与中间文件保存在 `build/`。其他机器可将 `TECTONIC` 替换为当地安装路径；字体缺失时，安装相应字体，或在 `main.tex` 中修改字体设置。这里只记录实际使用的 Tectonic 编译结果，未单独验证系统 XeLaTeX。

## 抓取与重建

日常编辑可直接修改 `main.tex` 和 `sections/*.tex`。需要从快照重新生成时，应修改 [translation.py](source/translation.py) 中的译文，再运行生成脚本；重新生成会覆盖中文 TeX 文件。

```bash
# 仅从已保存快照重新导出英文原文并核对配图，不重新抓取网页。
python source/crawl.py --reuse-snapshot

# 核对译文覆盖与图片 SHA-256，并生成中文 LaTeX。
python source/build_tex.py
```

重新抓取公开页面需要 Python 和 `requests`。下列命令会更新本目录的原文快照和配图；若网页结构或块顺序已改变，需要重新核对译文映射后再生成 TeX：

```bash
python source/crawl.py
```

原文、代码与配图的权利归原作者或相应权利人；本目录保留来源，不另行声称对原始材料拥有许可。

[^article]: Jiacai Liu、Yingru Li、Yuqian Fu、Jiawei Wang、Qian Liu、Yu Shen（按页面署名）。[作者 Notion 原文](https://yingru.notion.site/When-Speed-Kills-Stability-Demystifying-RL-Collapse-from-the-Training-Inference-Mismatch-271211a558b7808d8b12d403fd15edda)；[作者短链](https://richardli.xyz/rl-collapse)。

[^paper]: Yingru Li 等。[Trust Region Masking for Long-Horizon LLM Reinforcement Learning，arXiv:2512.23075](https://arxiv.org/abs/2512.23075)。仅用于核对目录编号及关联关系，本地未将该论文替代为博客译文。
