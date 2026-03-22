# 静态逆向工程分析：Docker优先版

> **定位**：本技能采用 **Docker优先** 方案。所有逆向工程工具都通过Docker容器执行。仅在Docker不可用时才会使用本地工具作为备用方案。

## Docker准备协议

在每次逆向工程会话开始时，执行此协议：

```bash
# 第1步：验证Docker守护进程是否运行
docker info > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "错误：Docker守护进程未运行。请启动Docker Desktop或运行：sudo systemctl start docker"
  exit 1
fi

# 第2步：预拉取所需镜像（从小到大）
echo "正在预拉取Docker镜像..."
docker pull zricethezav/gitleaks:latest
docker pull trufflesecurity/trufflehog:latest
docker pull cryptax/android-re:latest

# 第3步：验证镜像就绪
docker images --format '{{.Repository}}:{{.Tag}}' | grep -E "(gitleaks|trufflehog|android-re)"
echo "Docker准备状态：通过"
```

---

## Docker使用标准

### 卷挂载约定

```bash
# 格式：-u $(id -u):$(id -g) -v /主机绝对路径:/工作目录:ro
# 说明：
#   /主机绝对路径 = 主机上的目标绝对路径
#   /工作目录 = 容器内的固定挂载点
#   :ro = 仅读取数据时使用；写入操作时省略
#   -u $(id -u):$(id -g) = 避免创建文件的权限问题
```

### 容器清理规则

1. **始终使用 `--rm`** 自动清理容器执行后
2. **始终使用绝对路径** 进行卷挂载（`-v /完整路径:/工作目录`）
3. **使用只读挂载（`:ro`）** 仅读取数据时
4. **除非绝对必要，否则绝不构建自定义Dockerfile**

---

## 第1步：识别目标

运行 `file` 命令确认目标类型：

```bash
file /路径/到/目标
```

| 文件签名/扩展名 | 类型 | 分析流程 |
|---|---|---|
| `.apk` 或包含AndroidManifest.xml的Java归档/ZIP | Android APK | APK流程 |
| `.ipa` 或包含`Payload/*.app`的ZIP | iOS IPA | IPA流程 |
| `.js`、`.js.map`、`.bundle`、包含`index.html`的目录 | Web/JSBundle | Web流程 |
| `.aab` | Android App Bundle | 先转换为APK，再使用APK流程 |

---

## 第2步：设置工具环境

### 选项A：Docker（主要-始终优先使用）

#### APK分析 - `cryptax/android-re`

```bash
# 解码APK（资源、清单、smali）- 读取操作
docker run --rm \
  -u $(id -u):$(id -g) \
  -v /绝对路径/到/目标.apk:/work/target.apk:ro \
  cryptax/android-re \
  apktool d /work/target.apk -o /work/apktool-output

# 反编译为Java源代码 - 读取操作
docker run --rm \
  -u $(id -u):$(id -g) \
  -v /绝对路径/到/目标.apk:/work/target.apk:ro \
  cryptax/android-re \
  jadx -d /work/jadx-output /work/target.apk

# 生成调用图 - 读取操作
docker run --rm \
  -u $(id -u):$(id -g) \
  -v /绝对路径/到/目标.apk:/work/target.apk:ro \
  cryptax/android-re \
  androcg -o /work/callgraph.gml /work/target.apk
```

#### 敏感信息扫描 - `trufflesecurity/trufflehog`

```bash
# 扫描反编译源代码目录 - 读取操作，无需git
docker run --rm \
  -u $(id -u):$(id -g) \
  -v /绝对路径/到/反编译源码:/work/source:ro \
  trufflesecurity/trufflehog:latest \
  filesystem /work/source \
  --no-update > /路径/到/结果.txt
```

#### 敏感信息扫描 - `zricethezav/gitleaks`

```bash
# 扫描任何目录的敏感信息 - 读取操作，无需git
docker run --rm \
  -u $(id -u):$(id -g) \
  -v /绝对路径/到/反编译源码:/work/source:ro \
  zricethezav/gitleaks:latest \
  detect --source /work/source --no-git > /路径/到/结果.txt
```

#### Web分析 - `node:20-alpine` 美化

```bash
# 美化压缩的JS
docker run --rm \
  -u $(id -u):$(id -g) \
  -v /绝对路径/到/bundle.js:/work/bundle.js:ro \
  node:20-alpine \
  npx js-beautify -s /work/bundle.js -o /work/bundle-beautified.js

# 源映射重建
docker run --rm \
  -u $(id -u):$(id -g) \
  -v /绝对路径/到/源映射.map:/work/bundle.js.map:ro \
  node:20-alpine \
  sh -c "node -e \"const fs=require('fs'); const map=JSON.parse(fs.readFileSync('bundle.js.map','utf8')); console.log('SourceRoot:', map.sourceRoot);\""
```

#### IPA分析（macOS原生工具-无Docker）

在macOS上，使用原生工具进行IPA分析：
- `otool` - 显示目标文件
- `codesign` - 代码签名检查
- `plutil` - 属性列表操作
- `class-dump` - Objective-C类头
- `strings` - 从二进制提取字符串

### 选项B：本地工具（仅备用）

如果Docker **不可用**，使用本地工具：

**APK工具**：`apktool`、`jadx`、`dex2jar`、`baksmali`、`strings`、`grep`、`find`、`unzip`
**Web工具**：`node`、`npx`、`js-beautify`、`prettier`
**敏感扫描**：`trufflehog`、`gitleaks`（如已安装）

### 选项C：基本备用（最后手段）

如果Docker和专用工具都不可用：
- 使用 `unzip` 解压APK/IPA
- 使用 `strings`、`grep`、`find`、`xxd` 分析

---

## 第3步：提取和分析

### APK流程

**阶段1 - 提取（顺序执行）**
1. 使用 `apktool d <文件>` 解码APK
2. 使用 `jadx` 反编译为Java源代码
3. 计算文件哈希：`sha256sum <文件>`
4. 使用 `androguard` 生成调用图（可选）

**阶段2 - 并行分析（使用Task工具）**

独立并行运行：
- **[并行] 清单分析**：权限、导出组件、意图过滤器
- **[并行] 端点提取**：URL、API端点、WebSocket地址
- **[并行] 敏感信息和密钥检测**：API密钥、令牌、凭证
- **[并行] 证书和签名分析**：签名证书、调试签名
- **[并行] 网络安全**：明文传输、证书绑定
- **[并行] 第三方分析**：SDK识别
- **[并行] 编码和加密数据**：Base64、十六进制、XOR模式
- **[并行] 欺骗和蜜罐分析**：诱饵与真实端点
- **[并行] 代码流分析**：入口点、关键流程、Mermaid图

### IPA流程

**阶段1 - 提取（顺序执行）**
1. 解压IPA访问 `Payload/*.app` 包
2. 定位主二进制文件（Mach-O可执行文件）
3. 计算文件哈希：`sha256sum <文件>`

**阶段2 - 并行分析（使用Task工具）**
- **[并行] Info.plist分析**：Bundle ID、ATS设置、URL方案
- **[并行] 端点提取**：二进制字符串、资源文件
- **[并行] 敏感信息和密钥检测**：trufflehog/gitleaks扫描
- **[并行] 权限和功能**：嵌入的权利
- **[并行] 框架分析**：嵌入框架、SDK识别
- **[并行] 二进制元数据**：加密标志、安全标志、架构
- **[并行] 欺骗和蜜罐分析**：诱饵与真实检测
- **[并行] 代码流分析**：入口点、关键流程

### Web/JS Bundle流程

**阶段1 - 准备（顺序执行）**
1. 识别打包工具（webpack、Vite、Rollup、Parcel、esbuild）
2. 使用 `js-beautify` 或 `prettier` 美化
3. 如有则重建源映射
4. 检测混淆器

**阶段2 - 并行分析（使用Task工具）**
- **[并行] 端点提取**：Fetch/XHR URL、API路径
- **[并行] 敏感信息和密钥检测**：API密钥、令牌、凭证
- **[并行] 认证和授权**：JWT、OAuth流程
- **[并行] 应用架构**：路由、状态管理
- **[并行] 敏感逻辑**：暴露的客户端验证
- **[并行] 欺骗和蜜罐分析**：诱饵与真实检测
- **[并行] 代码流分析**：入口点、关键流程

---

## 混淆分析手册

### 编码检测和解码

| 编码 | 检测模式 | 解码方法 |
|----------|------------------|-----------------|
| Base64 | `atob()`、`Buffer.from(,'base64')`、`base64Decode` | 使用 `base64 -d` 或Python |
| 十六进制 | `0x[0-9A-Fa-f]+`、`fromHex()` | 使用 `xxd -r -p` |
| XOR | 重复字节模式、可疑常量 | 追踪密钥，手动应用XOR |
| ROT13 | 正则：`[A-Za-z]{13}` 模式 | `tr 'A-Za-z' 'N-ZA-Mn-za-m'` |
| 反转字符串 | `.reverse()`、`strrev()` | `rev` 命令 |

### 加密追踪分析

**Android模式：**
- `Cipher.doFinal()` - 追踪输入明文、密钥来源、输出密文
- `SecretKeySpec` - 查找密钥字节派生
- `KeyGenerator`、`PBKDF2` - 追踪密钥派生
- `Android Keystore` - 检查系统密钥库使用

**iOS模式：**
- `CryptoKit` - 对称/非对称加密
- `SecKeyDecrypt()` - 非对称解密
- `Keychain` 操作 - `SecItemCopyMatching()`

### 反分析检测

| 类型 | 检测方法 |
|------|-----------------|
| 模拟器 | `ro.product.model`、`ro.build.fingerprint`、`/qemud` |
| Root | `/system/app/Superuser.apk`、`su`二进制、`ro.debuggable` |
| 调试器 | `PT_DENY_ATTACH`、`sysctl KERN_PROC_PID`、`strace` |
| Frida | 端口27042扫描、`/proc/self/maps`中的`frida`、socket检查 |

### DGA（域名生成算法）

查找：
- 基于时间：时间戳、日期计数在主机名中
- 基于设备ID：IMEI、序列号在主机名构造中
- 与固定密钥的XOR

### 诱饵与真实分类

| 分类 | 标准 |
|-----------------|----------|
| `CONFIRMED_REAL` | 在活跃代码路径中使用，认证流程 |
| `LIKELY_REAL` | 在代码中使用但路径未完全追踪 |
| `SUSPECTED_DECOY` | 在明文中但从未在实际网络调用中使用 |
| `HIDDEN_REAL` | 通过解码发现，明文中不可见 |
| `UNKNOWN` | 证据不足 |

---

## 敏感信息检测模式

```
# === 云提供商密钥 ===
AWS访问密钥：          AKIA[0-9A-Z]{16}
AWS私钥：             (?i)aws_secret_access_key\s*[=:]\s*["']?([A-Za-z0-9/+=]{40})["']?
GCP API密钥：         AIza[0-9A-Za-z\-_]{35}
Firebase URL：         https?://[a-zA-Z0-9\-]+\.firebaseio\.com
Supabase URL：        https://[a-zA-Z0-9]+\.supabase\.co

# === 支付和SaaS ===
Stripe发布密钥：       pk_(test|live)_[0-9a-zA-Z]{24,}
Stripe私钥：          sk_(test|live)_[0-9a-zA-Z]{24,}
PayPal Braintree令牌：access_token\$production\$[0-9a-z]{16}\$[0-9a-f]{32}

# === 通信 ===
Slack令牌：           xox[bpors]-[0-9a-zA-Z\-]{10,}
Twilio账户SID：       AC[a-f0-9]{32}
SendGrid API密钥：    SG\.[a-zA-Z0-9_\-]{22}\.[a-zA-Z0-9_\-]{43}
Telegram机器人令牌：  \d{8,10}:[A-Za-z0-9_-]{35}

# === 认证 ===
JWT令牌：             eyJ[A-Za-z0-9-_]+\.eyJ[A-Za-z0-9-_]+\.[A-Za-z0-9-_]+
持有者令牌：          (?i)bearer\s+[a-zA-Z0-9\-_\.]+
通用API密钥：         (?i)(api[_-]?key|apikey)\s*[=:]\s*["']?([a-zA-Z0-9\-_]{20,})["']?

# === 网络 ===
HTTP URL：            https?://[^\s'"<>}{)(]+
WebSocket URL：       wss?://[^\s'"<>]+
```

---

## 第4步：生成报告

创建 `findings/[应用名]-[YYYY-MM-DD]/` 目录：

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

### 报告摘要表

包含在 `report.md` 中：

| 类别 | 发现数量 |
|---|---|
| 端点 | N |
| 敏感信息/密钥 | N |
| 权限（敏感） | N |
| 第三方服务 | N |
| 关键流程映射 | N |
|安全问题 | N |

**风险评估**：[严重/高/中/低/信息]

### Mermaid图约定

- `sequenceDiagram` — 多组件交互（认证流程、支付流程）
- `flowchart TD` — 导航图、初始化流程
- `flowchart LR` — 线性调用链（UI → ViewModel → Repository → API）
- 每个图最多约15个节点

---

## 工具注册表

| 工具 | Docker镜像 | 阶段 | 角色 |
|------|-------------|-------|------|
| apktool | cryptax/android-re | 提取 | 提取器 |
| jadx | cryptax/android-re | 提取 | 提取器 |
| androcg | cryptax/android-re | 提取 | 提取器 |
| trufflehog | trufflesecurity/trufflehog | 分析 | 分析器 |
| gitleaks | zricethezav/gitleaks | 分析 | 分析器 |
| js-beautify | node:20-alpine | 准备 | 提取器 |
| strings | 原生（macOS/Linux） | 分析 | 分析器 |
| plutil | 原生macOS | 分析 | 分析器 |
| otool | 原生macOS | 分析 | 分析器 |

---

## 代理团队角色

| 代理 | 职责 | Docker工具 |
|-------|---------------|--------------|
| 编排器 | 工作流协调 | 无（任务管理） |
| 提取器 | 文件提取、Docker设置 | cryptax/android-re、node |
| 分析器 | 静态分析、敏感信息 | trufflehog、gitleaks |
| 混淆器 | 解码、加密追踪 | 容器中的自定义脚本 |
| 报告器 | 报告生成 | 无（文件写入） |

**工作流**：顺序提取 → 并行分析 → 并行混淆 → 报告
