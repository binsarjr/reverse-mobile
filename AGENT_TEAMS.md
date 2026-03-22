# 代理团队配置：逆向工程小组

## 团队概述

**团队名称**：reverse-engineering-squad
**目的**：使用Docker优先方案对Android APK、iOS IPA和Web包进行多代理静态分析
**定位**：Docker优先 - 所有工具通过Docker容器执行，除非Docker不可用

## 支持的目标类型

| 类型 | 扩展名 | 流程 |
|------|------------|----------|
| Android APK | `.apk`、`.aab` | APK流程 |
| iOS IPA | `.ipa` | IPA流程 |
| Web/JS包 | `.js`、`.js.map`、`.bundle` | Web流程 |

## 团队成员

### 1. 编排器

**角色**：工作流协调员

**职责**：
- 识别目标类型（APK/IPA/Web）
- 根据流程阶段分配任务给团队成员
- 监控进度并汇总发现
- 处理错误恢复和继续
- 决定Docker与本地工具的回退方案

**使用的工具**：
- Task工具（生成子代理）
- Bash（文件操作、Docker状态检查）
- Read工具（审查输出）

**沟通**：
- 输入：来自用户的目标文件路径或URL
- 输出：分配任务给提取器、分析器、混淆器、报告器
- 来自所有代理的完成信号

---

### 2. 提取器

**角色**：Docker和文件提取

**职责**：
- 每个流程的第1阶段：文件提取和环境设置
- 管理分析的Docker容器生命周期
- 运行初始解码/反编译命令
- 计算文件哈希并验证目标类型
- 在会话开始时预拉取Docker镜像

**Docker命令**：

```bash
# APK提取
docker run --rm \
  -u $(id -u):$(id -g) \
  -v /绝对路径/到/目标.apk:/work/target.apk:ro \
  cryptax/android-re \
  apktool d /work/target.apk -o /work/apktool-output

docker run --rm \
  -u $(id -u):$(id -g) \
  -v /绝对路径/到/目标.apk:/work/target.apk:ro \
  cryptax/android-re \
  jadx -d /work/jadx-output /work/target.apk

# 调用图生成（APK）
docker run --rm \
  -u $(id -u):$(id -g) \
  -v /绝对路径/到/目标.apk:/work/target.apk:ro \
  cryptax/android-re \
  androcg -o /work/raw/callgraph.gml /work/target.apk

# Web包美化
docker run --rm \
  -u $(id -u):$(id -g) \
  -v /绝对路径/到/bundle.js:/work/bundle.js:ro \
  node:20-alpine \
  npx js-beautify -s /work/bundle.js -o /work/bundle-beautified.js
```

**输出**：
- 包含提取/反编译内容的 `raw/` 目录
- `raw/callgraph.gml`（APK流程）
- 报告元数据的哈希值

**沟通**：
- 接收：来自编排器的目标路径
- 发送：提取的文件位置给分析器和混淆器

---

### 3. 分析器

**角色**：静态分析专家

**职责**：
- 跨多个专业领域进行并行静态分析
- 使用Task工具并行运行多个分析任务
- 清单/plist解析、字符串提取、端点发现
- 使用trufflehog/gitleaks进行敏感信息扫描
- 证书和签名分析
- 网络安全审查
- 第三方SDK识别
- 使用Mermaid图进行代码流分析

**Docker命令**：

```bash
# TruffleHog敏感信息扫描
docker run --rm \
  -u $(id -u):$(id -g) \
  -v /绝对路径/到/反编译源码:/work/source:ro \
  trufflesecurity/trufflehog:latest \
  filesystem /work/source --no-update

# Gitleaks敏感信息扫描
docker run --rm \
  -u $(id -u):$(id -g) \
  -v /绝对路径/到/反编译源码:/work/source:ro \
  zricethezav/gitleaks:latest \
  detect --source /work/source --no-git
```

**分析子任务**（通过Task工具，并行）：
1. **清单/Info.plist分析** - 权限、导出组件、ATS
2. **端点提取** - URL、API、WebSocket端点
3. **敏感信息和密钥检测** - API密钥、令牌、凭证
4. **证书和签名分析** - 签名证书
5. **网络安全** - 明文流量、绑定
6. **第三方分析** - SDK识别

**输出**：
- `endpoints.json` - 所有发现的端点
- `secrets.json` - 带分类的检测到的敏感信息
- `metadata.json` - 应用元数据、权限、SDK
- `flow-analysis.md` - Mermaid图
- `flow-analysis.json` - 结构化调用图

**沟通**：
- 接收：来自提取器的提取源码路径
- 发送：结构化发现（JSON）给混淆器和报告器

---

### 4. 混淆器

**角色**：解码和欺骗专家

**职责**：
- 分析编码/加密数据和运行时构造的端点
- 解码Base64、十六进制、XOR、简单密码
- 追踪加密/解密调用链
- 识别域名生成算法（DGA）
- 执行欺骗分析（真实与诱饵端点）
- 交叉引用发现以分类端点/敏感信息

**混淆子任务**：
1. **编码数据分析** - Base64、十六进制、XOR模式
2. **加密追踪分析** - `Cipher.doFinal`、`SecretKeySpec`
3. **反分析检测** - 模拟器、root、调试器、Frida检测
4. **DGA模式检测** - 基于时间、设备ID的主机名构造
5. **诱饵识别** - 比较明文与运行时构造的URL

**真实性表分类**：

| 分类 | 标准 |
|----------------|----------|
| `CONFIRMED_REAL` | 在活跃代码路径中使用 |
| `LIKELY_REAL` | 在代码中使用但路径未完全追踪 |
| `SUSPECTED_DECOY` | 在明文中但从未在实际网络调用中使用 |
| `HIDDEN_REAL` | 通过解码发现 |
| `UNKNOWN` | 证据不足 |

**输出**：
- `deception-analysis.md` - 蜜罐分析叙述
- `deception-analysis.json` - 带分类的真实性表
- 解码的URL、密钥、配置

**沟通**：
- 接收：来自分析器的发现，来自提取器的原始源码
- 发送：解码发现、欺骗分析给报告器

---

### 5. 报告器

**角色**：报告生成

**职责**：
- 将所有发现汇总为结构化报告
- 为代码流程生成Mermaid图
- 在 `findings/[应用名]-[日期]/` 创建最终交付物
- 向用户展示摘要，突出关键发现

**输出结构**：

```
findings/[应用名]-[YYYY-MM-DD]/
  report.md              # 主要可读报告
  endpoints.json         # 结构化端点数据
  secrets.json           # 检测到的敏感信息和密钥
  metadata.json          # 应用元数据和配置
  flow-analysis.md       # 代码流程图（Mermaid）
  flow-analysis.json     # 结构化调用图数据
  deception-analysis.md   # 蜜罐/欺骗分析
  deception-analysis.json # 查找真实性表
  raw/                   # 提取的工件
    callgraph.gml        # Androguard调用图（APK）
```

**沟通**：
- 接收：来自分析器、混淆器的汇总数据
- 发送：最终报告路径给编排器/用户

---

## 工作流阶段

```
┌─────────────────────────────────────────────────────────────────┐
│ 阶段1：初始化                                                  │
│ 用户输入：目标文件路径或URL                                     │
│      │                                                          │
│      ▼                                                          │
│ 编排器识别目标类型（APK/IPA/Web）                               │
│      │                                                          │
│      ▼                                                          │
│ 提取器：预拉取Docker镜像（gitleaks→trufflehog→android）         │
│      │                                                          │
│      ▼                                                          │
├─────────────────────────────────────────────────────────────────┤
│ 阶段2：提取（顺序执行）                                        │
│      │                                                          │
│      ▼                                                          │
│ 提取器：                                                         │
│   1. 计算SHA256哈希                                            │
│   2. file命令确认类型                                          │
│   3. 根据类型：                                                │
│      - APK：通过cryptax/android-re的apktool + jadx + androcg    │
│      - IPA：解压，定位Mach-O二进制                              │
│      - Web：美化，检测打包器/混淆器                              │
│   4. 存储raw/和output/目录                                    │
│   5. 通知编排器："提取完成"                                    │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│ 阶段3：分析（并行 - 通过Task工具）                            │
│      │                                                          │
│      ▼                                                          │
│ 编排器生成并行任务：                                            │
│   - 任务1：清单/Info.plist分析                                  │
│   - 任务2：端点提取                                             │
│   - 任务3：敏感信息和密钥检测                                   │
│   - 任务4：证书和签名分析                                       │
│   - 任务5：网络安全                                             │
│   - 任务6：第三方SDK分析                                        │
│                                                                 │
│ 所有任务在提取的源码上并发运行                                  │
│      │                                                          │
│      ▼                                                          │
│ 编排器收集所有结果                                               │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│ 阶段4：混淆（与阶段3并行）                                    │
│      │                                                          │
│      ▼                                                          │
│ 混淆器（在分析器阶段3开始后）：                                 │
│   1. 运行编码数据分析                                          │
│   2. 追踪加密调用链                                             │
│   3. 检测反分析技术                                             │
│   4. 构建真实性表                                               │
│   5. 写入deception-analysis.md和deception-analysis.json         │
│   6. 通知编排器："混淆完成"                                    │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│ 阶段5：代码流分析                                              │
│      │                                                          │
│      ▼                                                          │
│ 分析器（在阶段3+4完成后）：                                     │
│   1. 从清单/plist识别入口点                                    │
│   2. 追踪调用图（最大深度4-5）                                 │
│   3. 映射关键流程：认证、支付、加密、深链接                     │
│   4. 生成Mermaid图                                             │
│   5. 写入flow-analysis.md和flow-analysis.json                  │
│   6. 通知编排器："流程分析完成"                                │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│ 阶段6：报告生成                                                 │
│      │                                                          │
│      ▼                                                          │
│ 报告器（在所有分析完成后）：                                     │
│   1. 汇总所有JSON发现                                          │
│   2. 生成带摘要表的report.md                                   │
│   3. 突出显示严重/高严重程度发现                               │
│   4. 展示Mermaid图                                             │
│   5. 通知编排器："报告完成"                                   │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│ 阶段7：最终组装                                                 │
│      │                                                          │
│      ▼                                                          │
│ 编排器：                                                         │
│   1. 验证所有必需文件存在                                       │
│   2. 向用户显示摘要                                             │
│   3. 显示生成文件的路径                                         │
│   4. 提供深入了解特定发现的选项                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 代理沟通

| 从 | 到 | 消息类型 |
|------|----|--------------|
| 用户 | 编排器 | 目标文件路径或URL |
| 编排器 | 所有 | 任务分配 |
| 提取器 | 编排器 | 提取完成 |
| 分析器 | 编排器 | 分析完成 |
| 混淆器 | 编排器 | 混淆完成 |
| 报告器 | 编排器 | 报告完成 |
| 编排器 | 用户 | 最终摘要和文件路径 |

---

## Docker镜像

| 镜像 | 用途 | 预拉取顺序 |
|-------|---------|----------------|
| `zricethezav/gitleaks:latest` | 敏感信息扫描 | 1（最小） |
| `trufflesecurity/trufflehog:latest` | 敏感信息扫描 | 2 |
| `cryptax/android-re:latest` | APK分析（jadx、apktool、androguard） | 3（最大） |
| `node:20-alpine` | Web包美化 | 按需 |

---

## 置信度级别

| 级别 | 标准 |
|-------|----------|
| **高** | 可获得反编译源码（使用jadx的APK） |
| **中** | 类转储头（使用class-dump的IPA） |
| **低** | 加密二进制（App Store IPA） |

---

## 关键文件

- `/Users/user/.claude/skills/reverse-engineer/SKILL.md` - 主技能文件
- `SKILLS.md` - 本团队Docker优先技能说明
- `docker-setup.sh` - Docker准备脚本
- `findings/[应用名]-[YYYY-MM-DD]/` - 输出目录
