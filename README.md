# WageJump

一个简单的「摸鱼算薪」工具：实时显示今天已经赚了多少钱，并支持桌面 / 主屏幕小组件。

支持 **macOS** 与 **iPhone**。本仓库开源，可自行用 Xcode 编译安装（无需购买 Apple 开发者会员也可装到自己的设备上）。

## 功能

- 今日入账实时计算（按月薪、工作日、上下班与午休时间）
- 下班倒计时、今日进度条、发薪倒计时
- 中国法定节假日倒计时列表
- WidgetKit 小组件（小 / 中尺寸）

## 环境要求

- macOS（建议 15.5+）
- [Xcode](https://developer.apple.com/xcode/)（建议 16+ / 与系统匹配的最新版）
- 免费 **Apple ID**（用于签名到自己的 Mac / iPhone）

最低系统版本（以工程配置为准）：

- iOS **18.5+**
- macOS **15.5+**

## 自行编译（推荐按这个做）

### 1. 获取代码

```bash
git clone <你的仓库地址>
cd WageJump
open WageJump.xcodeproj
```

### 2. 换成你自己的签名信息（必做）

仓库里默认写的是原作者的 Team / Bundle ID / App Group，直接编译多半会签名失败。请改成你自己的：

#### 2.1 Signing Team

1. 用 Xcode 打开工程后，顶部选中 **WageJump** 工程
2. 分别选中 Target：**WageJump**、**WageJumpWidgetExtension**
3. **Signing & Capabilities**
4. 勾选 **Automatically manage signing**
5. **Team** 选你的个人 Apple ID（Personal Team 即可，不必付费）

#### 2.2 Bundle Identifier

两个 Target 都要改成**全球唯一**的 ID，例如：

| Target | 示例 |
|--------|------|
| WageJump | `com.你的名字.WageJump` |
| WageJumpWidgetExtension | `com.你的名字.WageJump.Widget` |

小组件的 Bundle ID 一般是主 App ID 加后缀。

#### 2.3 App Group（小组件同步用，必改）

主 App 和小组件要共用同一个 App Group。

1. 在两个 Target 的 **Signing & Capabilities** 里添加 / 确认 **App Groups**
2. 新建并勾选你自己的 Group，例如：`group.com.你的名字.WageJump`
3. 同步修改这些文件里的 Group ID（全部改成同一个）：

- `Shared/AppConstants.swift` 里的 `appGroupID`
- `WageJump/WageJump.entitlements`
- `WageJump/WageJump-iOS.entitlements`
- `WageJumpWidget/WageJumpWidget.entitlements`
- `WageJumpWidget/WageJumpWidget-iOS.entitlements`

Mac 版 entitlements 里若有类似下面的路径例外，也要把目录名改成你的 Group ID：

```text
/Library/Group Containers/group.xxx.WageJump/
/Library/Application Scripts/group.xxx.WageJump/
```

### 3. 编译运行 — Mac

1. Xcode 顶部运行目标选 **My Mac**
2. 菜单 **Product → Run**（或 `⌘R`）
3. 首次若提示沙盒 / 权限，按提示允许

添加 Mac 小组件：

1. 先成功运行并打开一次 App
2. 桌面空白处右键 → **编辑小组件**（或通知中心底部「编辑小组件」）
3. 搜索 **WageJump** 添加  
   （不要只看「来自 iPhone」分类，选 Mac 本地那一项）

可选：把生成的 App 拷到 `~/Applications`，小组件图库会更稳定。

### 4. 编译运行 — iPhone

1. 用数据线连接 iPhone，解锁并信任电脑
2. 手机打开 **设置 → 隐私与安全性 → 开发者模式**（若有）
3. Xcode 顶部运行目标选你的 **真机**
4. `⌘R` 运行
5. 若提示「未受信任的开发者」：  
   **设置 → 通用 → VPN 与设备管理** → 信任你的 Apple ID

添加 iPhone 小组件：长按桌面 → **编辑主屏幕** → 点左上角 **+** → 搜索 WageJump。

> 免费个人账号装到 iPhone 上，开发证书大约 **7 天**过期，过期后重新用 Xcode Run 一次即可。

### 5. 命令行编译（可选）

```bash
# Mac
xcodebuild \
  -scheme WageJump \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath ./build \
  build

# 产物大致在：
# ./build/Build/Products/Debug/WageJump.app
```

iPhone 真机命令行编译还需要有效的签名与描述文件，更建议直接用 Xcode GUI。

## 项目结构

```text
WageJump/
├── WageJump/           # 主 App（SwiftUI）
├── WageJumpWidget/     # 小组件扩展
├── Shared/             # 主 App 与小组件共用的计算与存储
├── scripts/            # macOS 安装包脚本
├── WageJumpTests/
└── WageJumpUITests/
```

## 常见问题

**签名报错 / App Group 无效**  
多半是 Team、Bundle ID、App Group 没改全，或主 App 与小组件的 Group 不一致。

**Mac 小组件图库里找不到**  
先用 Mac 目标成功 Run 并打开 App；再编辑小组件搜索；必要时把 `.app` 放到 `~/Applications` 后重新打开 App。

**iPhone 上几天后打不开**  
免费证书过期，连上电脑用 Xcode 再 Run 一次。

**不想改 Bundle ID，只想自己玩**  
仍建议至少改 Team；若 Team 与工程里写死的 Bundle ID / Group 不匹配，仍会失败。

## 打包 macOS 安装包

日常用 Xcode 运行时，免费 Apple ID 的开发描述文件大约 **7 天**过期。要给别人一个不用重新编译、也不会 7 天后失效的 Mac 安装包，用 ad-hoc 签名打 DMG。这种方式没有开发者证书，对方第一次打开需要手动放行。

在项目根目录执行（需要完整 Xcode，不能只有 Command Line Tools）：

```bash
./scripts/package-dmg.sh
```

脚本会编译 Release、去掉描述文件后做 ad-hoc 签名，并生成：

```text
dist/WageJump-<版本号>.dmg
```

`dist/` 和 `build/` 已在 `.gitignore` 里，安装包不会进仓库。这条打包路径不会改工程里的 Team 和日常签名。

磁盘镜像里有 `WageJump.app`、指向「应用程序」的快捷方式，以及 `请先读我.txt`。对方安装：

1. 把 WageJump 拖进「应用程序」
2. 在「应用程序」里对 WageJump 点右键，选择「打开」
3. 若仍被拦截，到「系统设置 → 隐私与安全性」里点「仍要打开」

这个包是通用二进制，Apple 芯片和 Intel Mac 都可以用，系统要求仍是 macOS 15.5+。

签名里不会带上 App Group。那是受限制的权限，没有 Apple 描述文件时系统会直接结束进程。主应用和小组件在 Mac 上仍通过沙盒允许的共享目录交换数据。目录名与 entitlements 里的 Group ID 一致，当前仓库是：

```text
~/Library/Group Containers/group.tenenzzzz.WageJump/
~/Library/Application Scripts/group.tenenzzzz.WageJump/
```

iPhone 不能用这个 DMG。装到手机上仍然用 Xcode 运行，免费账号还是大约 7 天需要重签。

## 分发说明

本项目以开源方式分享，**不提供** App Store / TestFlight / 已公证安装包。

- 自己用：按上文用 Xcode 编译
- 给别人一个 Mac 安装包：用上一节打出 DMG。对方需要右键打开，不是双击即用
- 若要双击就能打开、或上架商店，需要加入 [Apple Developer Program](https://developer.apple.com/programs/)，用 Developer ID 签名并公证

## License

本项目采用 [MIT License](LICENSE)。
