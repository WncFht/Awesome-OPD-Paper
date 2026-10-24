# Sampled-token OPD 的失效设置与 On／Off-policy、Replay、Reuse

更新：2026-10-24。阅读对象是纯文本、外部教师蒸馏；核对相关论文的方法、实验设置、主要结果与关键消融，不把 OPSD 或混合任务奖励 RL 的结果当作核心证据。本文对应两个问题：基本 sampled-token OPD 在哪里失效、怎样修复；在线采样、离线轨迹和复用机制分别改变了什么。

原有[论文分组清单](2026-10-24-纯文本外部教师OPD论文筛选.md)保留检索功能。本笔记补读 Lightning OPD、Lightning OPD 2.0 与 Semi-OPD，它们虽然不满足“当前学生持续在线采样”的严格口径，却是回答离线学生回放问题的直接比较对象。以下区分论文结果、作者解释和综合判断；没有在本地复现实验。

## 1. 先固定基本形式与比较维度

### 1.1 基本 sampled-token OPD

记当前学生为 $p_\theta$，冻结外部教师为 $q$，前缀为 $s_t=(x,y_{<t})$。最基本的局部 sampled-token OPD 是：

$$
y\sim p_\theta(\cdot\mid x),\qquad
A_\theta(s_t,y_t)=\log q(y_t\mid s_t)-\log p_\theta(y_t\mid s_t),
$$

$$
\widehat g_{\mathrm{local}}
=-\sum_t\operatorname{sg}[A_\theta(s_t,y_t)]
\nabla_\theta\log p_\theta(y_t\mid s_t).
$$

上式是最小化损失时的梯度估计方向，$\operatorname{sg}$ 表示停止梯度。它只使用实际采样词元的师生 log-prob；不额外使用正确性奖励，不求整个词表的 KL，也不沿后续所有位置传播 return-to-go。工程实现还可能使用旧学生、重要性比率、裁剪与不同长度归约，这些都需要单独记录。Revisiting OPD 对局部与序列级估计器作了明确区分。[^revisiting]

有两个容易混淆的点：

- **一个随机采样词元不等于 deterministic top-1。** THUNLP 的支持集消融发现，sampled-token 与较大的 top-k 可以接近，而固定 argmax 的 top-1 明显更差。不能用 top-1 失败证明随机单词元估计必然失败。[^rethinking]
- **局部梯度不等于完整序列 KL 的精确梯度。** 完整序列目标还涉及当前动作对未来前缀和未来教师信号的影响；只保留即时 $A_t$ 会省去未来耦合。Revisiting OPD 的分析与 toy 实验指出，恢复更多未来耦合也会增加方差，不能直接把“补齐 return-to-go”当作通用修复。[^revisiting]

在固定前缀、温度为 1、没有 top-p 截断且确实按 $p_\theta$ 采样时，有：

$$
\mathbb E_{a\sim p_\theta(\cdot\mid s)}[A_\theta(s,a)]
=-D_{\mathrm{KL}}(p_\theta(\cdot\mid s)\Vert q(\cdot\mid s))\leq 0.
$$

因此，平均优势为负本身不说明教师失效。更应该检查负信号是否集中在极端尾部、是否对应真正错误、以及抑制这些词元后概率是否流向有用候选。这是由基本公式得到的判断；它不替代论文中的具体诊断。

### 1.2 拆开四个轴，才知道论文在比较什么

| 轴 | 需要记录的内容 | 不能混同的情况 |
| --- | --- | --- |
| 前缀分布 $d_\mu(s)$ | 当前学生、旧学生、初始学生、教师、师生混合或教师修整轨迹 | 固定教师回答与固定初始学生回答都是 off-policy，但不是同一种数据 |
| 固定前缀上的动作／支持集 | 学生随机词元、教师随机词元、学生 top-k、教师 top-k、全词表 | 旧前缀可配当前完整教师分布，也可只有旧动作的一次评分 |
| 局部目标 | 前向 KL、反向 KL、JSD、skew KL、CE、混合目标 | on-policy 不自动等于反向 KL；off-policy 不自动等于 SFT |
| 新鲜度与缓存 | 当前或旧 advantage；缓存响应、教师分数、采样概率或 top-k 支持集 | “用了 replay”不足以确定估计器是否有偏或教师是否仍需在线 |

Decoupling KL and Trajectories 与 September Systematic Study 都把前缀来源与 KL 方向独立控制，这是理解该方向最有用的共同坐标。[^decoupling][^systematic]

## 2. 基本 sampled-token OPD 的失效证据

### 2.1 直接针对 sampled-token 的设置

| 论文与位置 | 设置与失效表现 | 深入诊断 | 修复及其边界 |
| --- | --- | --- | --- |
| Revisiting OPD，§2–4、表1、表3 | Qwen2.5-7B-Instruct 学生，OpenThinker3-7B 教师，DAPO 数学训练。AIME24 pass@1 从学生 13.3 降到 sampled-token OPD 的 10.0；但五项平均分从 28.2 升到 36.4 | 单词元信号失衡；学生前缀上的教师反馈不可靠；特殊词元与 tokenizer 不匹配 | 保留 sampled-token 时，mask 后 AIME24 为 26.7、五项均分 40.7；换 teacher-top-K LSM 后均分约 41.5–41.7。这里有单任务负迁移，不能写成所有任务完全不学习 |
| Demystifying OPD，§4–5、图4、图6–9 | Qwen3-1.7B-Base 学生，对比 Qwen3-1.7B／4B 及其 GRPO 教师。最强 4B-GRPO 教师的部分训练曲线长期停滞；另有响应过长、提前结束、优势上升而准确率下降的现象 | 师生失配；逐词元信号与正确性不一致；长度归约产生可利用的优化捷径 | 直接裁剪或对数压缩 log-ratio；不同教师下效果不同。硬裁剪在较大失配下更有效，不能把一种变换当作通用答案 |
| Semi-OPD，§2–5、图2、图5、图7–9 | 17 个师生对，含 Qwen3 thinking 学生与更大 thinking 教师。低初始重叠时在线 OPD 常明显落后于固定初始学生回放；部分 thinking 配置在训练中性能崩塌 | 在线 rollout 变长、出现异常模式；学生越更新，后续前缀越不适合教师监督 | 固定初始学生轨迹、一次缓存教师分数、重算当前学生优势。14/17 个配置的曲线面积比较偏向 Semi-OPD；初始学生过弱时固定回放反而不如在线 OPD |
| TIDE，§2–4 | 比较 JustRL-1.5B → R1-Distill-1.5B 与 Qwen3-8B → Qwen3-1.7B-Base 等失配程度不同的配置；诊断重复序列上的退化一致 | 学生过量概率词元带来极端负更新；教师偏好的缺失词元不容易被学生采到；重复可使教师也局部跟随 | 有界处理 excess 信号，并增加教师 top-K deficit 监督。这已超出“只取一个学生采样词元”的原始形式 |

上述数字分别属于各论文自己的协议，不能横向按绝对分数排名。Revisiting 的 13.3 → 10.0 与平均分上涨同时成立；Demystifying 的停滞曲线也不能替代该文表格中的其他检查点成绩。[^revisiting][^demystifying][^semi][^tide]

### 2.2 有帮助，但不能全部算作 sampled-token 直接证据的论文

**THUNLP《Rethinking OPD》值得重点读，但要标清默认设置。** 附录表2默认是 Student Top-K、$K=16$；主实验中的不学习、回退和长序列失稳，不能全部归到 sampled-token 名下。该文另在 §6.3 直接比较了 sampled-token 与不同大小的 top-k。[^rethinking]

这篇论文最有价值的设置包括：

- R1-Distill-1.5B 学生：JustRL-1.5B 教师带来明显提升，同家族 R1-Distill-7B 教师却几乎没有收益。
- JustRL-1.5B 学生：向较弱的训练前检查点蒸馏会丢掉 RL 收益；向分数略高的 R1-Distill-7B 蒸馏也出现近似回退。
- Qwen3-1.7B-Base → Qwen3-4B Non-thinking：先用教师生成回答做 SFT 冷启动，再做 OPD，明显好于直接开始。
- 长 rollout 设置：在其选定模型对上，3K／7K 比 10K／15K 更稳定；长序列的失稳从后部向前部传播。

作者将这些现象解释为思考模式兼容性与可迁移新能力的问题。实验能支持“教师 benchmark 分数不足以预测蒸馏效果”，但不能据此证明所有 OPD 都必须使用特定家族或 RL 教师。[^rethinking]

该文还有一项直接限制了简单解释：成功与失败教师的整条轨迹奖励都能区分正确与错误回答，报告 AUROC 约 0.73 与 0.75。失败教师并非没有全局信息。作者提出逐词元梯度方向不一致、聚合后部分抵消的几何解释，但明确说没有直接验证这个假说。不能把它写成已证实的失败原因。[^rethinking]

**ESR 与 KAT 说明前缀问题会超出单词元 Monte Carlo 噪声。** ESR 的方法式写的是逐位置分布 KL，不能把所有跨模型崩溃表格直接当作 sampled-token 消融。其教师续写探针更有解释力：教师从原问题作答约 65.30% avg@4，接收 100／300 个学生前缀词元后约为 62.70%／51.75%。KAT 则发现持续低 KL 可能对应教师跟随已退化的局部续写，而不是任务已学好。[^esr][^kat]

**States, Not Tokens 的“超过受损教师”主要结果也不是基本 sampled-token。** 正文 §2.5、§6 说明其成功版本从学生前缀采样教师短续写，再用 CE 训练。单步 logit matching 在该小规模 Qwen3-0.6B-Base／GSM8K 设置中降至约4.0%，但文中不足以把这一对照精确认定为本节定义的 sampled-token 估计器。它支持“监督时间范围可能重要”的研究假说，不宜当作已严格控制的 sampled-token 失败消融。[^states]

### 2.3 我对原因的梳理

1. **教师在自己的轨迹上强，不保证在学生前缀上会教。** 早期错误会把后续状态推到教师不熟悉的区域；教师可能继续错误逻辑，也可能只在少量位置提供纠正线索。
2. **局部偏好不是任务价值。** 增大一个词元的教师似然，不保证增加最终解对的概率；对一条错误轨迹中所有位置套同一结论，也定位不了真正错误发生在哪里。
3. **单样本与反向 KL 有自己的覆盖和尾部问题。** 不常被学生采到的教师模式难进入更新；教师几乎不支持而学生常采到的词元，又可能产生极端 log-ratio。
4. **在线采样会改变下一轮训练数据。** 参数更新、长度增长、坏前缀与更差监督可能相互强化。离线回放冻结了这条反馈路径，因而有时不仅更快，也更稳定。
5. **实现细节可能被误读为机制失败。** mask、chat template、tokenizer、采样温度／top-p、优势是否重算、长度归约与结束词元处理都可能改变结论。

这些是对多篇证据的综合判断，不是某一篇论文已经证明的统一理论。特别是“低重叠不好”与“高重叠也可能退化”并不矛盾：初始健康轨迹上的候选兼容性，与训练后期重复上下文制造的局部一致，含义不同。

### 2.4 如果尽量保留 sampled-token，修复顺序是什么

| 层次 | 可以做什么 | 仍保留了什么／改变了什么 |
| --- | --- | --- |
| 实现与初始化 | 对齐模板、特殊词元、概率计算；必要时短 SFT／LoRA 冷启动 | 主体可以继续使用 sampled-token；冷启动本身增加离线阶段 |
| 信号幅度 | 对数压缩、硬裁剪，监测极端优势与长度 | 仍只用采样词元反馈，但已改变更新权重 |
| 轨迹深度 | 短前缀、按可靠性停止生成，避免全量学习退化后缀 | 保留学生采样；改变受监督状态范围，可能损失后续推理阶段覆盖 |
| Replay 估计器 | 重算当前学生优势；适用时做动作级 IS；增加每个前缀的局部 MC 样本 | 能改善采样方差和动作陈旧，不会自动修复前缀分布 |
| 监督升级 | LSM／teacher-top-K、前向 KL 补充、TIDE deficit 监督 | 已不再是最基本的一词元 sampled-token 形式，应单独记为方法改动 |
| 数据升级 | SKD、TRB、TRD、Relay 或固定初始学生缓存 | 改变行为策略或训练轨迹分布；不能宣称只是修好了同一个无偏估计器 |

前四行是尽量维持轻量监督的路线，后两行处理更深的支持集或状态分布问题。当前证据支持分层修复，不支持“一直加 top-k／一直加长度／始终保持最新采样就能解决”。

## 3. On／Off-policy 研究的主要结论

### 3.1 把“前缀来自谁”和“用什么 KL”分开

在固定前缀 $s$ 上，前向 KL 是 $D_{\mathrm{KL}}(q\Vert p_\theta)$，反向 KL 是 $D_{\mathrm{KL}}(p_\theta\Vert q)$。两种前缀来源与两种 KL 可以自由组合：

| 前缀来源 | 前向 KL | 反向 KL |
| --- | --- | --- |
| 教师轨迹 | 常见 soft-label KD；教师采样硬标签是 CE 的 Monte Carlo 版本 | 教师前缀上的反向 KL 蒸馏 |
| 当前学生轨迹 | 学生访问状态、教师给完整／软目标的 on-policy KD | 常见 OPD；sampled-token 是其中一种局部估计方式 |

**两项受控研究不支持一个普遍的 KL 胜者。** Decoupling 在 Qwen3-0.6B、128／4096 词元的数学蒸馏中，反向 KL 的 Avg@k 通常更好，但长序列下熵和多样性代价更明显，学生前缀平均也有优势。September Systematic Study 主实验是 Llama-3.1-8B → Llama-3.2-1B、医学／科学／Countdown、150 步、每组3个种子，发现前向 KL 的准确率和稳定性更稳健，学习率对遗忘与更新稀疏性的影响大于采样策略。后者的主要轨迹较短，另有较长数学实验，但只有单次运行的部分结论应谨慎解释。[^decoupling][^systematic]

共同点是：前向 KL 对前缀来源更稳健；反向 KL 对采样策略和支持失配更敏感。分歧是：在给定任务、师生对、长度和超参数下，哪一种得到更高的最终准确率。不能把其中一篇的排名直接推广到另一篇的设置。

固定前缀上，前向 KL 的学生 logit 梯度是 $p_\theta(v)-q(v)$；反向 KL 的梯度还含学生概率与 log-ratio 项。这个差异解释了为什么“换轨迹”和“换 KL”不能混为一个干预，也解释了学生缺少的教师模式与极端尾部为何影响反向 KL。它不是前向 KL 在所有任务上必胜的证明。[^systematic]

### 3.2 理论研究说明什么时候在线反馈有价值

**When Does Online IL Help** 区分学生能否表示教师策略的 realizability。其受控实验中，可实现教师下的离线 SFT 已能恢复教师表现，在线 OPD 没有进一步提高精度或训练效率；失配条件下则分析离线学习的信息限制与在线反馈可能有帮助的结构。不能只用“长链会累积错误”解释所有在线优势。[^realizability]

**NAIL** 在带噪声专家设定下给出离线与在线信息条件的理论分离，并在合成任务及 GSM8K 中测试。实用版本的重要变化是区分 rollout 策略与评分策略：采用贪心 rollout，而不把评估分布也一并变成确定性分布；其理论算法与实际梯度实验实现也不是同一份指数权重程序。[^nail]

这些理论没有直接否定 Semi-OPD：理论中的离线比较通常只提供专家轨迹；Semi-OPD 提供初始学生访问状态上的教师评分，两者拥有的信息不同。理论最有用的结论是明确数据访问与模型假设，而不是给所有 replay 方法判优劣。

## 4. Replay／Reuse 的三条主线

### 4.1 在线缓冲回放：DistiLLM

DistiLLM 的 §3.2、算法1与 §5.2 最接近通常意义上的 replay buffer。它缓存的是学生生成回答，缓冲满后用新回答替换最老样本，再从中取样训练。它还混用固定数据，按验证损失调节使用学生输出的概率 $\phi$。新的学生回答生成频率设为 $\lambda_R=\phi(1-t/T)$：训练早期学生变化快，较强调补入新回答；后期学生趋于稳定，较多重用已有回答。[^distillm]

这篇论文同时改了损失，使用 skew KL／skew reverse KL。不能把全部提升归到 replay 上。其消融显示，迁移到 ImitKD、GKD 时 off-policy 复用有性能损失，而 DistiLLM 的损失与调度组合较能保住效果；特定实验的复用方案比 on-policy／mixed 方案快约 2.2–3.4 倍。[^distillm]

**能支持的结论：** 适当维护、逐渐增加利用的学生轨迹缓冲能节省生成成本，但 replay 的可用程度依赖损失与更新强度。该文缓存学生文本，不应未经证据就等同于“一次缓存全部教师 logits，随后不再跑教师”。

### 4.2 永久冻结初始学生缓存：Lightning 与 Semi-OPD

共同计算流程是：

$$
\pi_0\ \xrightarrow{\text{一次生成}}\ \{x,y,s_t\}
\ \xrightarrow{\text{教师一次评分}}\ \{\log q(y_t\mid s_t)\}
\ \xrightarrow{\text{多步训练}}\ p_\theta.
$$

响应和教师 log-prob 固定，当前学生 log-prob 不固定：

$$
A_\theta(s_t,y_t)=\underbrace{\log q(y_t\mid s_t)}_{\text{缓存}}
-\underbrace{\log p_\theta(y_t\mid s_t)}_{\text{每步重算}}.
$$

**Lightning OPD** 从 base 学生开始，先用同一教师生成的数据做 SFT，再从 SFT 学生生成离线轨迹并缓存教师分数，训练时无需在线教师。论文强调 SFT 数据生成教师与 OPD 教师的一致性。其 Qwen3-8B-Base／Qwen3-32B 配置中，表1的 AIME24 为 OPD 68.5、Lightning 69.9；表2的 OPD 阶段成本从120降到30 GPU-hours，包含该阶段的轨迹收集、预评分和优化。不能把它当作包含任意额外 SFT 成本的所有流程通用加速比。[^lightning]

其理论结果有条件：需要支持覆盖、优势／score 有界等假设；共享零点的直接结论还要求教师可由学生策略类表示。teacher consistency 的梯度差异上界并不单独证明“换教师必然失败”或“使用同一教师就一定成功”。[^lightning]

**Lightning OPD 2.0** 保留冻结 replay，处理 SFT 数据生成者与后续 OPD 教师不一致的情况。它缓存教师与参考学生对同一词元的 log-prob，把教师—参考差异中跨样本重复、可由词元及粗上下文预测的部分当作风格偏差代理，通过按 rollout 交叉拟合估计并减去，再构造参考锚定的更新。这里的“风格”是操作性代理，不是已识别的因果风格因素；它是调整监督信号，不是修复 replay 新鲜度。[^lightning2]

**Semi-OPD** 通常直接从已有 instruction-tuned 学生开始，省去额外教师回答 SFT。它明确问：保持最新学生采样是否总有价值？17个配置的初始 top-64 重叠与相对收益有关，曲线面积比较在14/17个配置上偏向 Semi-OPD；低重叠时收益通常更大。低重叠示例约为62.5%，高重叠 Nemotron 示例约为89.3%，这些是实验点，不是可直接部署的统一阈值。[^semi]

Semi-OPD 的关键消融比“更快”更重要：

1. **换成固定教师轨迹，效果下降。** 固定缓存的优势不是任意静态数据都能带来，初始学生的轨迹结构仍有价值。
2. **等训练词元预算，只保留前1/4、1/2、3/4，完整轨迹更好。** 更短且完整的初始学生解答，可能同时避免过深的坏前缀并覆盖所有推理阶段；不能简单解释成“后缀都没用”。
3. **换成 top-k 监督，Semi-OPD 优势仍存在。** 问题不只是单样本估计方差。
4. **低重叠配置在 Semi-OPD 后切回在线 OPD，可能重新下降。** 更好初始化不一定能改变在线数据反馈形成的后续动态；高重叠配置则可能从切回在线中获益。
5. **初始学生太弱时，固定缓存会失败。** Base 学生的缓存不够好，Semi-OPD 可不如在线 OPD。

该文表1部分 OPD 变体结果转引其他工作；附录还说明，非thinking对的图1／图2使用匹配的4K训练响应上限，但表1标准OPD改用16K。主结论更应结合17个师生对的同长度训练曲线与切换消融，不能把汇总表所有分差直接视为纯on/off-policy对照。[^semi]

**这条路线改变了优化分布。** 它在固定初始学生数据上使用当前优势，通常没有完整恢复当前学生状态／动作分布的重要性权重，因此不能宣称是当前 on-policy 梯度的无偏、等价快速实现。实际价值正可能来自冻结状态分布后的不同训练动态。

### 4.3 在线异步、有限滞后与复用修正：AsyncOPD、NPD、Blockwise Gating

**AsyncOPD 是最直接的估计器拆解。** Rollout 用旧学生产生前缀和候选，教师评分后缓存，learner 再用当前学生更新。它把前缀陈旧与固定前缀上的动作陈旧分开。[^async]

对同一旧前缀，若 $a\sim p_{\mathrm{old}}$，且旧策略覆盖当前策略支持，局部反向 KL 梯度可写成：

$$
\rho_\theta(a,s)=\frac{p_\theta(a\mid s)}{p_{\mathrm{old}}(a\mid s)},\qquad
\nabla D_{\mathrm{RKL}}(p_\theta\Vert q;s)
=-\mathbb E_{a\sim p_{\mathrm{old}}}
\left[\rho_\theta A_\theta\nabla\log p_\theta(a\mid s)\right].
$$

其受控消融比较旧／当前优势与裁剪／不裁剪，结果偏向**当前优势、不裁剪的动作级 IS**；不能机械照搬“冻结旧 advantage，再做 PPO clipping”。先进异步 RL surrogate 在其设定下也未稳定胜过这个简单方案。[^async]

该文还区分两种教师缓存：

- **旧 student top-k：** 当前学生可能偏好缓存之外的新词元；只在旧集合内重加权取不到缺失教师分数。
- **旧学生随机动作：** 在支持覆盖下可用 IS 校正局部动作期望，但方差可能很大。因此每个已访问前缀缓存多个独立局部动作，再平均修正梯度。它增加的是同一前缀的动作样本，不需要每个样本都续写一整条轨迹；$m=4$ 已有明显收益，更大 $m$ 不保证持续同比改善。

这一结果不反驳同步 LSM：同步时 teacher-top-K 的低方差可能很有用；异步时**旧学生 top-k**的支持失配是另一个条件。重要性修正能处理动作采样，不会把旧前缀变成当前学生会访问的前缀。[^async]

**NPD** 侧重生成、教师 packed-prefill 评分和学生训练的解耦，缓存教师 top-k，并用 CE 与前向 KD 的组合损失训练。它用教师／学生的 $\Delta$-IFD 差异过滤退化或跨度过大的样本，并以稀疏更新控制偏移。这是工程吞吐与启发式筛选路线，不是 sampled-token 反向 KL 的无偏 replay 修正；其后续 RL 实验也不作为本笔记核心蒸馏证据。[^npd]

**Blockwise Policy-Drift Gating** 保留基础 OPD 损失，用旧—当前学生在同一已采样词元上的 log-prob 差 $d_t$ 构造分块权重：

$$
d_t=\log p_\theta(y_t\mid s_t)-\log p_{\mathrm{old}}(y_t\mid s_t),\qquad
g_B=\exp\!\left(-\tau\left|\frac{1}{|B|}\sum_{t\in B}d_t\right|\right).
$$

权重停止梯度并做均值归一化。它是在有偏复用下抑制变化大的位置，不是 IS。原文还说明旧 log-prob 是 actor 更新前重算的 raw 概率，而非 top-p 重归一化后的真实采样概率。其单模型对、无重复种子的表1中，sampled-token 均值 pass@8 从49.8到51.6；不能据此宣布64词元块或此门控普遍有效。[^block]

## 5. 另外几类“On／Off”论文实际在做什么

以下覆盖原清单第四组的其余主要论文。它们并不都研究 replay。

| 论文 | 实际机制 | 与基本 OPD 的关系和能得出的结论 |
| --- | --- | --- |
| GKD | 以 $\lambda$ 概率选当前学生生成回答，否则选固定回答；独立选择局部散度 | 奠基性的前缀来源混合；没有因此建立通用历史 buffer 或要求反向 KL |
| States, Not Tokens | 在单GPU、Qwen3-0.6B-Base／GSM8K 上比较状态来源；成功版本从学生状态请求教师短续写并做 CE | 即使受损教师也可提供有用局部续写，但单模型、小任务和不完整的单步对照不足以证明普遍机制 |
| HPD | 主要算法在离线专家前缀上取专家词元，再让当前学生在同一前缀局部采一个非专家词元，按符号做不同权重更新 | “动作由当前学生采样”不等于“整条前缀来自当前学生”；真实在线轨迹实验另列 §5.4 |
| Simple-OPD | 教师 CoT 上的 LoRA 冷启动，再做普通 OPD；比较不同来源／正确性的预热回答 | 预热可用于对齐思考模式，错误教师轨迹也可能有用；全参数 SFT 与 LoRA 的遗忘代价不同 |
| SKD | 学生提出词元；不在教师 top-K 时由教师替换；在纠正后的轨迹做蒸馏 | 直接改变生成分布，保住学生可达性与教师熟悉度；不是纯学生 rollout 或 replay |
| AdaSwitch | 根据近期师生分歧的滑动平均设置接管阈值，动态切换教师与学生生成 | 同样是行为策略干预；强调何时接管，而非历史样本多久复用 |
| TRB | $\mu_\beta\propto p_S^{1-\beta}q^\beta$，选满足学生中心 KL 预算的最强教师混合，再把预算退火到0 | 局部损失不变，改早期行为策略；两个数学模型对平均收益约0.9／0.4个百分点，教师在线参与有成本 |
| BRTS | 学生前缀上反向 KL，加经过正确性与学生适配选择的教师前缀前向 KL，默认辅助权重10 | 同时改前缀来源和目标；提升不能全归于多采了教师回答或“更 on-policy” |
| TRD | 学生先生成，教师再据此重写轨迹，在改写后的前缀蒸馏 | 解决已失败的前缀；教师改写在学生支持集内，不等于改写仍服从当前学生分布 |
| Relay-OPD | 教师 top-1 倾向反思，但学生 top-K 中没有反思词元时接管若干段落，再交回学生；限制接管预算 | 师生交替的混合轨迹；教师段也进入训练。使用学生旧概率作比率，不应解释为对实际混合行为策略的完整无偏 IS |

这些机制分别依据 GKD §3、HPD §4与§5.4、Simple-OPD §3–5、SKD §3、AdaSwitch §2、TRB §4–5、BRTS §3、TRD §4–6、Relay §3。[^gkd][^hpd][^simple][^skd][^adaswitch][^trb][^brts][^trd][^relay]

States, Not Tokens 的实验与限制另见 §4–6。[^states]

其中 TRD／Relay 的共同动机是：当学生已走上错误路径，仅在这条路径每个位置要求局部分布匹配，可能无法生成完整、连贯的纠错链。一个事后改写整条轨迹，一个在线有限接力。两者都不是通过简单重加权保住原始采样分布。

## 6. 目前可以坚持的结论与还不能下的结论

### 6.1 比较稳固的结论

1. **先问相对谁 on-policy。** 数据可以对当前学生新鲜，却对教师极不熟悉；教师评分质量不能仅由教师本身的 benchmark 分数保证。
2. **on-policy 是状态分布选择，不是某个 KL 或优化器的同义词。** 前缀、动作采样、局部目标必须分别控制。
3. **固定学生回放值得作为强基线。** 它既不同于教师数据 SFT，也不同于自生成回答上的普通 CE；教师密集分数与当前学生优势仍是关键。
4. **冻结教师在同一旧前缀、同一词元上的分数可以一直有效。** 参数和输入不变时，旧的是学生访问状态、动作候选和旧学生优势，不是教师分数因时间经过而自然失真。
5. **重算当前优势有明确价值，但不能解决所有 replay 偏差。** 动作级 IS、支持集缺失与前缀分布变化是三个不同问题。
6. **loss 下降、KL 下降、高 overlap 都不足以单独证明推理改善。** 必须同时看准确率、长度／重复、推理阶段覆盖与教师续写能力。

### 6.2 仍然取决于设置的结论

- 前向还是反向 KL 最优：受任务、师生对、学习率和序列长度影响；文献没有一致的绝对排名。
- 是否越短越好：ESR／FastOPD 说明长后缀可能有害；Semi-OPD 等词元预算的完整轨迹消融说明后续推理阶段覆盖也有价值。
- 是否必须教师 SFT 冷启动：THUNLP 与 Simple-OPD 支持若干设置；Semi-OPD 从已有 instruct 学生开始时，额外 SFT 反而可降低其最终表现。
- 是否 replay 越旧越差：固定初始学生缓存可能最好；异步当前学生缓存也可能因支持集和优势不匹配而快速变差，不能只按年龄排序。
- 是否 teacher consistency 是必要条件：它在 Lightning 流程中重要，但理论边界和 Lightning 2.0 的补救都不支持推广为所有 OPD 的先决条件。
- “教师局部信号为什么不可优化”是否已完整解释：负相关、局部支持与梯度抵消等解释并未形成统一、经全面验证的机制。

### 6.3 若要设计后续实验，我会怎样拆开

这是根据文献整理的实验建议，尚未执行。

用同一冻结教师、同一学生初始化、同一提示与评估协议，控制三个主因子：

1. 前缀来源：当前学生、初始学生、定期刷新的学生缓冲、教师轨迹。
2. 局部目标／估计器：sampled-token RKL、当前优势加动作 IS、多局部 MC、teacher-top-K RKL、前向 KL。
3. 轨迹范围：短前缀、完整但有长度控制的轨迹、按可靠性停止的轨迹。

首先比较“相同更新／训练词元预算”的学习效果，再比较“相同端到端 GPU-hours”的效果；不能把生成更少、教师评分更少和更好的优化方向混为一个收益。

若完整网格成本过高，优先比较：fresh sampled-token、固定初始学生缓存、滚动 buffer 的当前优势、相同 buffer 的当前优势加动作 IS。保留 teacher-top-K 或 FKL 作机制对照，再增加短前缀对照。这个设计能先回答：问题主要来自一次采样的监督、旧动作估计，还是在线前缀反馈本身。

除 accuracy／avg@k／pass@k，至少记录：响应长度与重复率、按位置的 overlap及其概率质量、teacher/student熵、极端优势比例、教师从不同深度前缀续写的正确率、不同缓存年龄的 IS 比率尾部与有效样本量、后续推理阶段的覆盖。不要把初始 overlap 的一个经验百分比直接设成跨模型通用阈值。

### 参考文献

[^revisiting]: Revisiting On-Policy Distillation: Empirical Failure Modes and Simple Fixes. arXiv:2603.25562，重点 §2–4、表1与表3。[论文](https://arxiv.org/abs/2603.25562)
[^rethinking]: Rethinking On-Policy Distillation of Large Language Models: Phenomenology, Mechanism, and Recipe. arXiv:2604.13016，重点 §3–6、附录表2。[论文](https://arxiv.org/abs/2604.13016)
[^demystifying]: Demystifying On-Policy Distillation: Roles, Pathologies, and Regulations. arXiv:2607.13399，重点 §4–5。[论文](https://arxiv.org/abs/2607.13399)
[^semi]: When Do We Need On-Policy Distillation? Distilling on Offline Student Rollouts Is Often Better. arXiv:2610.11291，重点 §2–5、表1、表3与表4。[论文](https://arxiv.org/abs/2610.11291)
[^tide]: Mismatch Matters: On-Policy Distillation Beyond Token Agreement. arXiv:2608.09836，重点 §2–4。[论文](https://arxiv.org/abs/2608.09836)
[^esr]: Less is More: Early Stopping Rollout for On-Policy Distillation. arXiv:2605.27028，重点 §2–5。[论文](https://arxiv.org/abs/2605.27028)
[^kat]: Escaping the KL Agreement Trap in On-Policy Distillation. arXiv:2606.09471，重点 §3–5。[论文](https://arxiv.org/abs/2606.09471)
[^decoupling]: Decoupling KL and Trajectories: A Unified Perspective for SFT, DAgger, Offline RL, and OPD in LLM Distillation. arXiv:2605.16826，重点 §2–5。[论文](https://arxiv.org/abs/2605.16826)
[^systematic]: On-Policy or Off-Policy Learning? A Systematic Study of Distillation Dynamics. arXiv:2609.35259，重点 §4–6。[论文](https://arxiv.org/abs/2609.35259)
[^states]: Post-Training is About States, Not Tokens: A State Distribution View of SFT, RL, and On-Policy Distillation. arXiv:2605.22731，重点 §2.5、§4–6。[论文](https://arxiv.org/abs/2605.22731)
[^realizability]: When Does Online Imitation Learning Help in LLM Post-Training? The Role of (Non-)Realizability Beyond Horizon. arXiv:2606.30445，重点 §4–6。[论文](https://arxiv.org/abs/2606.30445)
[^nail]: Behavior Cloning is Not All You Need: The Optimality of On-Policy Distillation for Noisy Expert Feedback. arXiv:2606.30923，重点问题定义、§4与§6。[论文](https://arxiv.org/abs/2606.30923)
[^distillm]: DistiLLM: Towards Streamlined Distillation for Large Language Models. arXiv:2402.03898，重点 §3.2、算法1与§5.2。[论文](https://arxiv.org/abs/2402.03898)
[^lightning]: Lightning OPD: Efficient Post-Training for Large Reasoning Models with Offline On-Policy Distillation. arXiv:2604.13010，重点 §3–4。[论文](https://arxiv.org/abs/2604.13010)
[^lightning2]: Lightning OPD 2.0: Mitigating Style Bias in Cross-Teacher On-Policy Distillation for Large Reasoning Models. arXiv:2607.28449，重点 §3。[论文](https://arxiv.org/abs/2607.28449)
[^async]: AsyncOPD: How Stale Can On-Policy Distillation Be? arXiv:2606.24143，重点 §3–7。[论文](https://arxiv.org/abs/2606.24143)
[^npd]: Near-Policy: Accelerating On-Policy Distillation via Asynchronous Generation and Selective Packing. arXiv:2605.05940，重点 §3与§4。[论文](https://arxiv.org/abs/2605.05940)
[^block]: Blockwise Policy-Drift Gating for On-Policy Distillation. arXiv:2606.24084，重点 §3–7。[论文](https://arxiv.org/abs/2606.24084)
[^gkd]: On-Policy Distillation of Language Models: Learning from Self-Generated Mistakes. arXiv:2306.13649，重点 §3。[论文](https://arxiv.org/abs/2306.13649)
[^hpd]: Hybrid Policy Distillation for LLMs. arXiv:2604.20244，重点 §4与§5.4。[论文](https://arxiv.org/abs/2604.20244)
[^simple]: Simple-OPD: Demystifying Warm-up for On-policy Distillation. arXiv:2608.06802，重点 §3–5。[论文](https://arxiv.org/abs/2608.06802)
[^skd]: Speculative Knowledge Distillation: Bridging the Teacher-Student Gap Through Interleaved Sampling. arXiv:2410.11325，重点 §3。[论文](https://arxiv.org/abs/2410.11325)
[^adaswitch]: AdaSwitch: Balancing Exploration and Guidance in Knowledge Distillation via Adaptive Switching. arXiv:2510.07842，重点 §2。[论文](https://arxiv.org/abs/2510.07842)
[^trb]: Trust-Region Behavior Blending for On-Policy Distillation. arXiv:2605.31159，重点 §4–5。[论文](https://arxiv.org/abs/2605.31159)
[^brts]: On-Policy Distillation with Best-of-N Teacher Rollout Selection. arXiv:2605.09725，重点 §3。[论文](https://arxiv.org/abs/2605.09725)
[^trd]: Trajectory-Refined Distillation. arXiv:2606.08432，重点 §4–6。[论文](https://arxiv.org/abs/2606.08432)
[^relay]: Pass the Baton: Trajectory-Relayed On-Policy Distillation. arXiv:2607.26057，重点 §3。[论文](https://arxiv.org/abs/2607.26057)
