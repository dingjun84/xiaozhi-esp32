# M5Stack AtomS3R 与 Echo Pyramid 开发与烧录手册

版本 V1.0　｜　整理日期 2026年11月13日

适用硬件为 AtomS3R 小主机与 Echo Pyramid 语音底座，适用工程为本机 xiaozhi-esp32。本文以 Intel Mac、zsh 和已有 Python 3.11 为操作主线，覆盖开发环境安装、源码开发、编译、烧录工具、备份恢复及首次运行。其他电脑需要替换用户名、Python 路径和设备端口。

本机已经完成工具安装和“你好小房”自定义固件的编译、烧录及写入校验，底座未连接提示也已由用户确认解决。语音识别准确率、远场距离和长时间稳定性仍应按第十章实际测试。

**使用已有环境时，可直接从第五章开始；仅重新烧录现成固件，可直接阅读第四章和第七章。当前设备使用“你好小房”版本，继续开发请走第六章的自定义版本流程。**

## 阅读导航

1. 硬件与工具关系
2. 本机环境和文件位置
3. 开发环境安装
4. 烧录工具安装与设备连接
5. 标准固件编译
6. 你好小房自定义固件开发
7. 固件烧录
8. 备份与恢复
9. 源码开发与版本管理
10. 首次启动与验收
11. 常见问题处理
12. 速查与参考资料

## 一 硬件与工具关系

### 1.1 硬件范围

AtomS3R 是主控制器，负责程序运行、联网、显示和语音算法。Echo Pyramid 是语音底座，提供麦克风、音频输出和相关外围器件。本文中的 Pyramid 指 Echo Pyramid，也称 Voice Pyramid，不是运行 Linux 的 AI Pyramid。

| 项目 | 本次设备信息 |
| --- | --- |
| 主机芯片 | ESP32-S3-PICO-1，双核，最高 240MHz |
| Flash | 8MB，用于存放程序、配置和语音资源 |
| PSRAM | 8MB，用于模型和运行数据；本项目配置为 Octal 模式 |
| 完整板型目录 | m5stack/atoms3r-echo-pyramid |
| 固件上报名称 | atoms3r-echo-pyramid |
| 项目芯片目标 | esp32s3 |

**两个 USB-C 口用途不同。** 烧录时，电脑数据线接 AtomS3R 小主机。正常使用时，从 Pyramid 底座 USB-C 口供电。只有小主机接电，不能据此判断底座已经获得正常供电。该要求见官方底座说明［1］［2］。

### 1.2 编译与烧录

编译是把 C/C++ 源码和资源生成二进制固件；烧录是把固件写入主机的 Flash。只有现成固件时，可以只安装烧录工具；需要修改这份小智源码时，需要完整 ESP-IDF 开发环境。

| 工具 | 作用 | 本项目是否需要 |
| --- | --- | --- |
| Python 3.11 | 运行构建脚本和设备工具 | 需要，复用已有安装 |
| Git | 获取源码、依赖和记录版本 | 开发需要 |
| ESP-IDF | ESP32 官方 SDK，提供芯片驱动和构建入口 | 从源码编译需要 |
| CMake 和 Ninja | 配置工程和执行构建 | 从源码编译需要 |
| Xtensa 编译器 | 将源码编译为 ESP32-S3 可执行程序 | 从源码编译需要 |
| esptool | 识别设备、读取备份和写入固件 | 烧录需要 |
| VS Code 或 Cursor | 编辑源码，可选装 ESP-IDF 扩展 | 可选，终端也能完成开发 |

Arduino IDE 也可以为 ESP32 上传程序，底层通常使用 esptool。但这份 xiaozhi-esp32 是 ESP-IDF 工程，不能直接当作普通 Arduino sketch 编译。为本项目安装 ESP-IDF，是为了生成固件；并非 ESP32 烧录只能使用 ESP-IDF。

## 二 本机环境和文件位置

### 2.1 已验证的软件组合

以下是本次安装、编译和烧录时实际使用的版本记录，不代表所有后续版本都必须使用相同组合。项目当前源码要求 ESP-IDF 不低于 6.0.1，推荐 release/v6.1 分支，不支持 IDF 5.x。

| 软件 | 已使用版本 |
| --- | --- |
| 系统与架构 | macOS 26.6.2，Intel x86_64 |
| 已有 Python | 3.11.9 |
| ESP-IDF | 6.1.0，来自 release/v6.1 分支 |
| CMake | 4.0.3，ESP-IDF 工具目录内安装 |
| Ninja | 1.12.1 |
| ESP32-S3 编译器 | xtensa-esp-elf-gcc 15.2.0 |
| esptool | 5.6.0 |
| 小智项目版本 | 2.5.3 |

本机原来的默认 python3 指向 3.7.4，同时已安装 Python 3.11.9 和 3.13.3。本次使用 3.11.9 创建 ESP-IDF 专用虚拟环境，没有替换系统默认 Python。开发时先加载专用环境，避免使用错误的解释器或把依赖装进其他项目。

### 2.2 关键路径

路径中的 admin 是本机用户名；其他电脑请替换。长路径可复制到终端使用。

```text
小智源码
/Users/admin/Desktop/workspace/xiaozhi-esp32

ESP-IDF SDK
/Users/admin/esp/esp-idf

工具与 Python 虚拟环境
/Users/admin/.espressif
/Users/admin/.espressif/python_env/idf6.1_py3.11_env

环境加载脚本
/Users/admin/esp/activate-xiaozhi.sh

你好小房配置与日志
/Users/admin/esp/xiaofang

原固件备份
/Users/admin/esp/backups
```

小智源码提交为 a73e9a7e266e3196d1368ba46c30bee0d81f0a64，SDK 提交为 f0114250e205e33a945e2f3e7ec40085c5a029a2。复现实验时同时记录源码、SDK、配置和资源；仅记录“6.1”不足以固定未来分支内容。

## 三 开发环境安装

### 3.1 安装前检查

已有本机环境不需要重复执行下载安装。新电脑或重装时，先检查基本工具和 Python 的实际位置。

```bash
uname -m
git --version
xcode-select -p
/usr/local/bin/python3.11 --version
/usr/local/bin/python3.11 -m pip --version
```

如果没有 Apple 命令行开发工具，执行下面的命令并完成系统弹窗中的安装。

```bash
xcode-select --install
```

本机可用的 Python 路径是 /usr/local/bin/python3.11。Apple Silicon 或其他安装方式可能不同，应先找到 Python 3.10 以上的解释器，再替换下文的路径；不要直接沿用一个不存在的路径。磁盘应留出足够空间容纳 SDK、工具链、组件和构建产物，本次工具链占用数 GB。

### 3.2 下载 ESP-IDF

以下仅用于尚未安装 SDK 的电脑。如果目标目录已经存在，先检查其版本，不要覆盖已有目录。

```bash
mkdir -p "$HOME/esp"
cd "$HOME/esp"
git clone --branch release/v6.1 --depth 1 \
  --recursive --shallow-submodules \
  https://github.com/espressif/esp-idf.git esp-idf
cd esp-idf
```

SDK 的子模块也是开发环境的一部分，不能只下载不含依赖的源码目录。分支会持续变化，正式交付前应固定并记录具体提交。安装方式采用本次验证过的脚本流程；官方也提供安装管理器，不需要把两套环境混装到同一目录［3］［4］。

### 3.3 使用已有 Python 安装工具

在 SDK 目录执行。工具安装器会按照 SDK 的版本清单下载兼容的编译器等工具；CMake 和 Ninja 也明确安装到用户工具目录。

```bash
cd "$HOME/esp/esp-idf"
export SSL_CERT_FILE=/etc/ssl/cert.pem
export REQUESTS_CA_BUNDLE=/etc/ssl/cert.pem
export IDF_GITHUB_ASSETS=dl.espressif.com/github_assets

/usr/local/bin/python3.11 tools/idf_tools.py \
  install --targets esp32s3
/usr/local/bin/python3.11 tools/idf_tools.py \
  install cmake ninja
/usr/local/bin/python3.11 tools/idf_tools.py \
  install-python-env --features core
```

本次曾遇到 Python 3.11 未配置默认 CA 证书而下载失败。上面的证书变量指向 macOS 现有可信证书文件，解决了本机问题，没有关闭证书校验。企业网络若使用专有 CA，应按本机网络要求配置可信证书，不应把所有证书错误都当成同一种问题。

IDF_GITHUB_ASSETS 使用乐鑫官方资源镜像，仅作用于工具安装器支持的 GitHub Release 资源，不会自动加速所有 Git 克隆或 PyPI 下载。网络失败时先检查实际失败的下载地址［4］。

### 3.4 加载环境

本机已经保存下面的入口。每次打开新终端，先执行一次。

```bash
source /Users/admin/esp/activate-xiaozhi.sh
```

脚本先激活 ESP-IDF 的 Python 3.11 环境，再加载 SDK。新电脑可按以下方式创建对应脚本；如果环境目录名不同，先核对实际目录。

```bash
cat > "$HOME/esp/activate-xiaozhi.sh" <<'EOF'
export SSL_CERT_FILE="${SSL_CERT_FILE:-/etc/ssl/cert.pem}"
export REQUESTS_CA_BUNDLE="${REQUESTS_CA_BUNDLE:-/etc/ssl/cert.pem}"
export IDF_GITHUB_ASSETS="${IDF_GITHUB_ASSETS:-dl.espressif.com/github_assets}"
. "$HOME/.espressif/python_env/idf6.1_py3.11_env/bin/activate"
. "$HOME/esp/esp-idf/export.sh"
EOF

source "$HOME/esp/activate-xiaozhi.sh"
```

这是加载到当前终端的脚本，应使用 source，不要直接把脚本当作独立程序运行。无需为了这个项目修改系统的默认 Python 链接。

### 3.5 验证环境

```bash
python --version
idf.py --version
cmake --version
ninja --version
xtensa-esp-elf-gcc --version
python -m esptool version
python -m pip check
python "$IDF_PATH/tools/idf_tools.py" check
```

验收标准是能找到工具、Python 依赖检查通过，并能实际生成 ESP32-S3 固件。本机已通过官方 hello_world 示例编译。工具检查列表中可能出现未安装的可选 QEMU 等工具，这不等于基本编译环境失败；以目标工具和实际构建结果为准。

## 四 烧录工具安装与设备连接

### 4.1 使用完整开发环境中的 esptool

第三章完成后，esptool、pyserial 等已经在 ESP-IDF Python 环境中，无需再安装第二套。加载环境后检查：

```bash
source /Users/admin/esp/activate-xiaozhi.sh
python -m esptool version
python -m serial.tools.list_ports -v
```

本文使用 esptool 5 的命令形式，例如 write-flash、read-flash、flash-id。旧说明中的 write_flash、read_flash 和 esptool.py 属于旧式写法；不要混用不同版本文档中的命令格式。

### 4.2 只烧录现成固件时的独立安装

没有开发需求时，可以用已有 Python 创建独立烧录环境。该分支是可选方案，不是完整 ESP-IDF 环境之外的必装步骤。安装与隔离原则参见官方说明［5］。

```bash
/usr/local/bin/python3.11 -m venv "$HOME/esp/esptool-venv"
source "$HOME/esp/esptool-venv/bin/activate"
python -m pip install --upgrade pip
python -m pip install 'esptool==5.6.0'
python -m esptool version
```

若需要复用本机证书设置，可先设置第三章中的 SSL_CERT_FILE 和 REQUESTS_CA_BUNDLE。不要把烧录工具装进系统 Python 后再依赖一个不明确的 python3 命令。

### 4.3 连接设备与选择端口

1. 用支持数据传输的 USB-C 线连接电脑与 AtomS3R 小主机。
2. 插拔前后对比串口列表，确认新增设备属于本次主机。
3. 必要时长按复位键约两秒，内部绿灯亮后松开，进入下载模式。
4. 关闭 Arduino 串口监视器、其他终端和占用同一端口的软件。

```bash
ls /dev/cu.*
python -m serial.tools.list_ports -v
```

本次端口曾为 /dev/cu.usbmodem142101。端口会随重新连接发生变化，下面的变量必须改为当前实际端口，不能把示例当作固定设备地址。

```bash
export XIAOZHI_PORT=/dev/cu.usbmodem142101
python -m esptool --chip esp32s3 \
  --port "$XIAOZHI_PORT" flash-id
```

本机设备已读出 8MB Flash、8MB PSRAM，MAC 为 7c:e8:b1:e4:45:30。更换设备后应重新确认型号和容量。只有确认缺少对应 USB 设备驱动时才安装驱动，不要看到“无串口”就安装任意 CH340 或 CP210x 驱动。

## 五 标准固件编译

### 5.1 确认源码和板型

本机源码已存在，不需要重新克隆。新电脑仅在目标源码目录不存在时执行以下命令，再切换到经过验证的版本；已有工程请跳过，避免产生重复目录。

```bash
mkdir -p "$HOME/Desktop/workspace"
cd "$HOME/Desktop/workspace"
git clone https://github.com/78/xiaozhi-esp32.git xiaozhi-esp32
```

本机继续操作时：

```bash
source /Users/admin/esp/activate-xiaozhi.sh
export XIAOZHI_PROJECT=/Users/admin/Desktop/workspace/xiaozhi-esp32
cd "$XIAOZHI_PROJECT"
git status --short
python scripts/build.py --list-boards
```

正确的构建板型是 m5stack/atoms3r-echo-pyramid，变体名称是 atoms3r-echo-pyramid。板型 README 中省略 m5stack/ 的旧示例与当前目录结构不一致，不能直接照抄。当前版本号也应读取根目录 CMakeLists.txt，不能沿用板型 README 中的 2.2.6。

### 5.2 编译标准中文版本

以下生成“你好小智”标准版本。**当前“你好小房”设备继续开发时，应使用第六章，而不是重新运行这条命令。构建脚本会重建配置并切换构建目录的状态。**

```bash
cd "$XIAOZHI_PROJECT"
python scripts/build.py m5stack/atoms3r-echo-pyramid \
  --name atoms3r-echo-pyramid \
  --language zh-CN \
  --wake-word nihaoxiaozhi \
  --zip
```

脚本负责选择 ESP32-S3、8MB Flash、对应分区和 PSRAM，调用 ESP-IDF 编译，并合并资源。首次构建会下载托管组件、字体和模型，需要联网；后续在依赖不变时可复用缓存。

成功标志是退出码为零、出现 Project build complete，并成功生成合并固件和压缩包。仅看到 .bin 文件存在不够：失败的构建可能留下旧文件，应核对构建日志、时间和配置。

```text
build/xiaozhi.bin                 程序区镜像，不是整机完整固件
build/generated_assets.bin       字体、表情和语音模型等资源
build/merged-binary.bin           可从 0x0 写入的合并固件
build/flasher_args.json           本次构建的烧录文件与地址
releases/v2.5.3_m5stack-atoms3r-echo-pyramid.zip
```

### 5.3 标准版本配置要点

| 配置项 | 标准版本取值 |
| --- | --- |
| 芯片目标 | esp32s3 |
| 板型 | M5Stack AtomS3R + Echo Pyramid |
| Flash | 8MB |
| PSRAM | Octal，80MHz |
| 中文语言 | zh-CN |
| 分区文件 | partitions/v2/8m.csv |
| 语音资源起始地址 | 0x600000，资源区 2MB |

如采用手动配置，可使用 idf.py menuconfig 查看 Xiaozhi Assistant、Serial flasher config、Partition Table 和 ESP PSRAM 菜单。板型、模型和分区是关联配置，不应只改其中一个值就假定整套配置正确。

## 六 你好小房自定义固件开发

### 6.1 本次实现方式

“你好小房”不是本次现成 WakeNet 模型列表中的词。本项目支持 MultiNet 中文自定义命令识别，因此本次使用 mn7_cn 模型，把识别文本配置为 ni hao xiao fang，显示文本配置为“你好小房”，动作配置为 wake。无需为这次配置另行训练一个专用 WakeNet 模型。

这与替换屏幕上的名字不同：只有显示名称发生变化，不会让设备识别一个新的声音短语。本次已检查打包资源中的命令配置，确认包含实际识别词和 wake 动作。

已经解析项目依赖后，可在工程根目录查询当前可用的现成唤醒模型，先确认已有模型是否能满足需求。

```bash
python scripts/build.py --list-wake-words
```

### 6.2 存储分配与更新方式

标准分区的资源区只有 2MB，无法放入本次完整的 MultiNet7、中文字体和界面资源。自定义版资源约 3.5MB，因此本次经用户确认，改为单程序分区与 4MB 资源区。**本次自定义版通过 USB 更新固件，不使用标准双程序分区的在线更新流程。**

| 分区 | 起始地址 | 大小 |
| --- | --- | --- |
| nvs | 0x9000 | 0x4000 |
| otadata | 0xd000 | 0x2000 |
| phy_init | 0xf000 | 0x1000 |
| ota_0 | 0x20000 | 0x3e0000 |
| assets | 0x400000 | 0x400000 |

不能把标准版 0x600000 的资源地址套用到此版本，也不能只烧录一个标准版程序区镜像来切换版本。切换存储布局时，应使用该版本生成的完整烧录参数或合并固件。

### 6.3 已保存的配置

```text
/Users/admin/esp/xiaofang/sdkconfig
/Users/admin/esp/xiaofang/wake.defaults
/Users/admin/esp/xiaofang/partitions.csv
```

关键配置如下。它们用于理解和核对，不应直接复制进一个未知状态的生成文件里。

```text
CONFIG_USE_CUSTOM_WAKE_WORD=y
CONFIG_CUSTOM_WAKE_WORD="ni hao xiao fang"
CONFIG_CUSTOM_WAKE_WORD_DISPLAY="你好小房"
CONFIG_CUSTOM_WAKE_WORD_THRESHOLD=20
CONFIG_SR_MN_CN_MULTINET7_QUANT=y
CONFIG_PARTITION_TABLE_CUSTOM_FILENAME="/Users/admin/esp/xiaofang/partitions.csv"
```

wake.defaults 是初次生成配置时的输入片段，已有 sdkconfig 才是后续构建使用的实际配置。修改 defaults 并不一定覆盖已有 sdkconfig。

### 6.4 继续编译自定义版本

沿用当前目录与配置时，使用下面的流程。它显式选择外部 sdkconfig，避免误用根目录中的标准版配置。

```bash
source /Users/admin/esp/activate-xiaozhi.sh
export XIAOZHI_PROJECT=/Users/admin/Desktop/workspace/xiaozhi-esp32
cd "$XIAOZHI_PROJECT"

idf.py -D SDKCONFIG=/Users/admin/esp/xiaofang/sdkconfig \
  -D BOARD_NAME=atoms3r-echo-pyramid reconfigure
idf.py build merge-bin
```

构建结束后检查 build/flasher_args.json，确认 assets 地址为 0x400000；确认程序小于 0x3e0000、资源小于 0x400000，且输出没有容量错误。不要看到项目名称正确就跳过资源地址检查。

```bash
rg 'CONFIG_CUSTOM_WAKE_WORD|CONFIG_USE_CUSTOM_WAKE_WORD' \
  /Users/admin/esp/xiaofang/sdkconfig
cat build/flasher_args.json
```

### 6.5 修改唤醒词和灵敏度

先选择自定义配置，再打开菜单：

```bash
idf.py -D SDKCONFIG=/Users/admin/esp/xiaofang/sdkconfig menuconfig
```

在 Xiaozhi Assistant 中保留 Multinet model 自定义唤醒实现，修改 Custom Wake Word 为以空格分隔的拼音，修改 Custom Wake Word Display 为中文显示词，再保存。模型选择保持与中文模型相符。随后重新编译和烧录。

本次阈值为 20%，数值越小越敏感，也可能增加误唤醒。阈值要根据实际环境测试，不能只凭编译成功判断效果。应对“你好小房”、相近读音、背景电视和多人说话分别测试，再决定是否调整。

### 6.6 在新目录恢复自定义开发

现成固件包中包含 sdkconfig、wake.defaults 和 partitions.csv，可用于保留配置记录。但其中的分区文件路径是本机绝对路径，复制到其他电脑后，需要用 menuconfig 把 Custom partition CSV file 改为新位置。

从标准构建首次生成自定义配置时，实际使用的方式是：先准备新的配置片段和分区 CSV，再以标准 sdkconfig 作为初始默认值、以自定义片段追加覆盖，生成一个独立的自定义 sdkconfig。

```bash
idf.py \
  -D SDKCONFIG=/Users/admin/esp/xiaofang/sdkconfig \
  -D "SDKCONFIG_DEFAULTS=$XIAOZHI_PROJECT/sdkconfig;/Users/admin/esp/xiaofang/wake.defaults" \
  -D BOARD_NAME=atoms3r-echo-pyramid reconfigure
```

这条初次生成命令要求目标自定义 sdkconfig 尚不存在，且默认输入文件和分区文件已经准备好。已有自定义配置请直接使用 6.4 和 6.5，不要为了改一个词删除现有配置。此存储方案是本次 8MB 设备的已选实现，不代表所有自定义唤醒词或其他硬件都必须取消在线更新。

## 七 固件烧录

### 7.1 烧录前确认

1. 确认是 AtomS3R + Echo Pyramid 对应固件，容量与主机一致。
2. 核对本次实际端口，关闭占用端口的软件。
3. 确认烧录文件是本次构建产物，区分标准版与“你好小房”版。
4. 需要保留原程序时，先按第八章备份。
5. 电脑数据线接小主机，写入过程中不拔线、不切换供电。

### 7.2 写入当前构建结果

已按第五章或第六章完成构建，且没有切换构建配置时，在工程根目录执行：

```bash
export XIAOZHI_PORT=/dev/cu.usbmodem142101
idf.py -p "$XIAOZHI_PORT" -b 460800 flash
```

idf.py 会按照当前构建记录使用正确的文件和地址。也可以在 build 目录用 esptool 执行本次生成的参数文件；不要拿其他构建目录的 flash_args 混用。

```bash
cd "$XIAOZHI_PROJECT/build"
python -m esptool --chip esp32s3 \
  --port "$XIAOZHI_PORT" --baud 460800 \
  write-flash @flash_args
```

### 7.3 写入现成的完整固件

本次自定义固件包位于：

```text
/Users/admin/Desktop/workspace/xiaozhi-esp32/releases/
v2.5.3_m5stack-atoms3r-echo-pyramid_xiaofang_usb.zip
```

解压到一个独立文件夹，确认其中有 merged-binary.bin、分区和配置说明。进入解压目录后执行：

```bash
python -m esptool --chip esp32s3 \
  --port "$XIAOZHI_PORT" --baud 460800 \
  write-flash 0x0 merged-binary.bin
```

**0x0 仅适用于这里的完整合并固件，不能把单独的 xiaozhi.bin 也写到 0x0。** 程序区、引导程序、分区表和资源需要按照同一套布局匹配；地址原则参见官方 esptool 文档［6］。

### 7.4 写入校验与正常启动

烧录成功时，工具应完成全部写入，并出现 Hash of data verified 等校验成功信息。本次分段烧录的五个区段均通过校验。若需要单独比对完整文件，可在已连接设备上执行：

```bash
python -m esptool --chip esp32s3 \
  --port "$XIAOZHI_PORT" verify-flash 0x0 merged-binary.bin
```

校验完成后，把运行供电接到底座。若屏幕没有正常启动，短按复位键或断电重新上电；不要长按复位键再次进入下载模式。电脑失去串口连接有时只是拔线或设备重新枚举，应重新检查端口，不能据此判定固件损坏。

## 八 备份与恢复

### 8.1 读取整片 Flash

在明确设备是 8MB Flash 后，可以读取整片备份。下面的文件名是示例，新备份应使用独立文件名，避免覆盖唯一的旧备份。

```bash
mkdir -p "$HOME/esp/backups"
python -m esptool --chip esp32s3 \
  --port "$XIAOZHI_PORT" --baud 460800 \
  read-flash 0x0 0x800000 \
  "$HOME/esp/backups/atoms3r-before-change.bin"
```

备份成功应显示读取了 8388608 字节，文件大小为 8MB。本次烧录前已经完整读取并保留原固件：

```text
/Users/admin/esp/backups/
atoms3r-7ce8b1e44530-before-xiaozhi-20261110.bin
```

完整 Flash 备份可能包含 Wi-Fi、设备绑定等原有配置，宜作为本机恢复文件保管，不应直接当作公开分发固件。启用加密或读保护的设备，备份及跨设备恢复存在额外限制；不要强行绕过工具的安全检查。

### 8.2 恢复原固件

确认恢复目标就是这台设备，且备份文件完好。下面的示例恢复本次保存的原始 8MB 内容，会覆盖当前“你好小房”固件和当前配置。

```bash
python -m esptool --chip esp32s3 \
  --port "$XIAOZHI_PORT" --baud 460800 \
  write-flash 0x0 \
  /Users/admin/esp/backups/atoms3r-7ce8b1e44530-before-xiaozhi-20261110.bin
```

恢复后仍需等待写入校验通过，并从底座供电重新启动。正常烧录会自动擦除涉及的扇区，通常不需要先执行整片 erase-flash。整片擦除会额外清除持久配置，不应作为每次烧录的默认操作。

## 九 源码开发与版本管理

### 9.1 常用源码入口

下面的路径均相对于小智项目根目录。先理解现有实现，再做小范围修改。

| 路径 | 主要用途 |
| --- | --- |
| main/boards/m5stack/atoms3r-echo-pyramid | 本板型驱动、引脚和配置 |
| main/application.cc | 应用流程、激活和设备状态 |
| main/audio | 音频输入输出、AFE 与唤醒处理 |
| main/protocols | WebSocket、MQTT 等通信 |
| main/Kconfig.projbuild | 可配置项和菜单 |
| scripts/build.py | 标准板型构建入口 |
| scripts/build_default_assets.py | 模型、字体和表情资源打包 |
| partitions/v2/8m.csv | 标准 8MB 双程序分区表 |

不要直接修改 managed_components、build 等自动下载或生成内容来“临时修好”工程，否则下次解析依赖或重新构建可能覆盖变更。也不要把另一块硬件的引脚直接套入本板型。

### 9.2 日常开发循环

1. 保存当前源码与配置，查看 git status，明确本次修改范围。
2. 加载正确 SDK 和 Python 环境，选择标准版或自定义版配置。
3. 修改一个可验证的功能，重新编译并检查输出容量。
4. 备份或保留上一份可用固件，写入设备并查看日志。
5. 在真实硬件上检查受影响的功能，再保存版本和测试结论。

```bash
git status --short
git rev-parse HEAD
git -C "$IDF_PATH" rev-parse HEAD
idf.py size
```

VS Code 或 Cursor 可直接打开源码目录。ESP-IDF 扩展是便利工具，不是终端编译的前置条件；若安装扩展，应指向现有 SDK 和现有工具环境，不要另装一个不一致的 SDK 后混用。

### 9.3 查看日志

完成构建和连接后，可使用：

```bash
idf.py -p "$XIAOZHI_PORT" monitor
```

退出快捷键为 Ctrl + ]。查看日志的软件可能控制复位信号；日志中若出现 waiting for download，说明当前在下载模式，应恢复正常启动再判断应用状态。屏幕能够显示底座错误提示，也说明应用至少已经运行到板型初始化流程。

### 9.4 固定交付版本

交付时一并保留完整固件、源码提交、SDK 提交、实际 sdkconfig、分区 CSV、资源配置、校验摘要和验收结果。自定义版尤其要注明“你好小房”“单程序分区”“USB 更新”，避免后续误刷标准在线升级包。

切换 SDK 后按项目要求更新 SDK 子模块，并使用新 SDK 重新配置和完整构建。操作前先保存配置；不要通过删除整个工作目录来处理普通构建错误。

## 十 首次启动与验收

### 10.1 启动与联网

1. 从 Pyramid 底座供电，确认 AtomS3R 与底座接触牢固。
2. 等待屏幕进入配网或正常启动界面。
3. 按屏幕或语音提示配置可用的 2.4GHz Wi-Fi。
4. 使用默认官方服务时，按设备提示在小智控制台完成激活或绑定。
5. 对设备说“你好小房”，检查是否进入对话，并测试收音和播放。

联网激活与固件烧录是两项独立检查。写入成功不等于网络和服务已经配置好；设备能显示界面，也不等于麦克风、模型和扬声器都已通过实测。

### 10.2 建议验收记录

| 检查项 | 操作与通过条件 |
| --- | --- |
| 启动 | 从底座供电能进入正常界面，无反复重启 |
| 底座 | 不出现 Echo Pyramid not connected，灯光和音频器件能初始化 |
| 联网 | 配网成功，断电后能恢复连接 |
| 激活 | 能完成服务绑定并进入可用状态 |
| 唤醒 | 近距离连续说“你好小房”10次，记录成功次数 |
| 误唤醒 | 播放日常背景声音，记录误触发情况和时长 |
| 收音 | 实际说话内容能被正确识别，记录距离与环境 |
| 播放 | 回复能清楚播放，无明显破音或异常中断 |
| 恢复 | 断网后重连、短按复位和断电重启后仍可使用 |

成功次数、距离、时长和网络环境应如实记录，不预设一个未经验证的识别率。本次已验证编译、烧录与写入校验，用户确认了底座提示消失；未据此宣称远场识别或长时间稳定性通过。

## 十一 常见问题处理

### 11.1 提示找不到 idf.py 或 Python 版本不对

先运行 source /Users/admin/esp/activate-xiaozhi.sh，再检查 which python、python --version 和 idf.py --version。当前终端应使用 ESP-IDF 专用环境中的 Python 3.11，而不是原先的 3.7。新开一个终端不会自动继承前一个终端加载的环境。

### 11.2 下载时报证书错误或网络错误

若报 CERTIFICATE_VERIFY_FAILED，先核对当前解释器和可信证书文件。对本机可使用第三章的 /etc/ssl/cert.pem 配置。Git 下载、工具压缩包下载和 Python 包下载使用的渠道不同，应找出实际失败的地址。不要通过关闭 HTTPS 校验解决一般安装问题。

### 11.3 找不到端口或一直 Connecting

检查 USB 线是否支持数据，数据线是否接在 AtomS3R 小主机上，当前端口是否已变化，以及是否有其他程序占用端口。重新进入下载模式后再连接；传输不稳定时把波特率从 460800 降到 115200。不要在端口未确认时尝试任意其他串口。

### 11.4 烧录成功后停在下载模式

waiting for download 是 ROM 下载模式提示，不是小智应用已正常运行。退出串口监视器，短按复位键或断电后从底座重新供电。长按复位键可能再次进入下载模式。若电脑重新枚举设备，应更新端口名称后再查看日志。

### 11.5 显示 Echo Pyramid not connected

先拔掉主机 USB 线，仅从底座 USB-C 口供电；断电后重新插紧 AtomS3R 与底座，再上电。本次出现过此提示，用户按供电和连接检查后确认已恢复。这个现象不能仅凭提示就判为固件写入失败。

本地驱动需要探测到底座的五个 I2C 器件，任何一个缺失都会进入错误界面。继续排查时，应读取 I2C 扫描结果，明确哪个器件缺失，而不是删掉检测条件强行进入对话。

| 器件 | 本地驱动预期 I2C 地址 |
| --- | --- |
| ES8311 音频编解码器 | 0x18 |
| ES7210 麦克风输入 | 0x40 |
| SI5351 时钟器件 | 0x60 |
| STM32 底座控制器 | 0x1A |
| AW87559 功放 | 0x5B |

若供电和接触已确认仍不恢复，再核对底座型号、硬件版本和驱动实现。更换底座型号需要重新确认适配，不能仅修改名称。

### 11.6 你好小房无法唤醒

先确认运行的是带 xiaofang_usb 标识的自定义固件，而不是标准“你好小智”包。检查实际 sdkconfig 中的自定义识别词、MultiNet7 选项和资源地址。再检查麦克风、底座供电及模型是否初始化成功。只有这些条件成立后，才通过实际测试调整阈值。

### 11.7 模型资源超过分区容量

同时检查语音模型、字体和表情资源的总大小，不能只看单个模型。标准 2MB 资源区与本次自定义 4MB 资源区不同。本次方案通过用户确认后调整了存储布局；不要通过忽略容量错误继续烧录，也不要把更大的资源镜像写到旧地址。

### 11.8 修改配置后没有生效

检查 SDKCONFIG 实际路径和当前构建缓存。已有 sdkconfig 可能优先于 defaults；标准 build.py 也会重建配置。自定义版请使用第六章的显式配置路径，通过 menuconfig 修改实际配置，再重新生成资源与合并固件。

## 十二 速查与参考资料

### 12.1 本机自定义版最短操作流程

以下命令使用已经安装好的环境和已经保存的“你好小房”配置。先重新确认端口，再执行最后一步写入。

```bash
source /Users/admin/esp/activate-xiaozhi.sh
cd /Users/admin/Desktop/workspace/xiaozhi-esp32

idf.py -D SDKCONFIG=/Users/admin/esp/xiaofang/sdkconfig \
  -D BOARD_NAME=atoms3r-echo-pyramid reconfigure
idf.py build merge-bin

python -m serial.tools.list_ports -v
export XIAOZHI_PORT=/dev/cu.usbmodem142101
idf.py -p "$XIAOZHI_PORT" -b 460800 flash
```

烧录后从底座供电，短按复位键正常启动，完成配网或激活后说“你好小房”。若只是烧录已保存的完整固件包，不需要重新编译，按 7.3 操作即可。

### 12.2 已保存的交付文件

```text
自定义完整固件包
/Users/admin/Desktop/workspace/xiaozhi-esp32/releases/
v2.5.3_m5stack-atoms3r-echo-pyramid_xiaofang_usb.zip

标准版本固件包
/Users/admin/Desktop/workspace/xiaozhi-esp32/releases/
v2.5.3_m5stack-atoms3r-echo-pyramid.zip

自定义编译与烧录日志
/Users/admin/esp/xiaofang/build.log
/Users/admin/esp/xiaofang/flash.log
```

自定义压缩包包含合并固件、分区表、配置、说明和 SHA256 摘要。烧录日志记录了五个区段的写入校验结果。不要用名字相近的标准包替代自定义包。

### 12.3 参考资料

［1］M5Stack AtomS3R 官方硬件及下载模式说明
https://docs.m5stack.com/en/core/AtomS3R

［2］M5Stack Echo Pyramid 官方示例与供电说明
https://docs.m5stack.com/en/arduino/projects/atomic/echo_pyramid

［3］ESP-IDF Linux 和 macOS 脚本安装说明
https://docs.espressif.com/projects/esp-idf/en/stable/esp32s3/get-started/linux-macos-setup-legacy.html

［4］ESP-IDF 工具安装器和用户工具目录说明
https://docs.espressif.com/projects/esp-idf/en/stable/esp32s3/api-guides/tools/idf-tools.html

［5］esptool 安装与虚拟环境说明
https://docs.espressif.com/projects/esptool/en/latest/esp32s3/installation.html

［6］esptool Flash 读取 写入与校验命令
https://docs.espressif.com/projects/esptool/en/latest/esp32s3/esptool/basic-commands.html

［7］小智项目仓库及本机板型实现
https://github.com/78/xiaozhi-esp32
本机路径为 main/boards/m5stack/atoms3r-echo-pyramid；项目根 README 与实际代码优先于旧板型说明中的版本号和命令示例。

［8］本次设备的安装与烧录记录
2026年11月10日本聊天中的安装、编译、备份、写入校验和用户反馈；2026年11月13日复核了本地配置、固件包及日志。该记录支持本机已完成事项，不能代替其他电脑或其他批次硬件的验收。
