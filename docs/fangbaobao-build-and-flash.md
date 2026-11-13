# “你好房保保”固件：编译与 USB 烧录

适用硬件：M5Stack AtomS3R + Echo Pyramid，8 MB Flash。
适用版本：`atoms3r-echo-pyramid-fangbaobao`。

## 1. 先确认电脑识别设备

烧录数据线接 **AtomS3R 本体的 USB-C 口**。Echo Pyramid 底座的 USB-C 口用于正常运行供电。
使用支持数据传输的 USB 线；不能只看设备亮灯来判断数据连接成功。

如果没有出现串口，长按 AtomS3R 复位键约 2 秒，等内部绿灯亮起后松开；
绿灯熄灭表示进入下载模式。然后执行：

```bash
ls /dev/cu.*
```

应出现类似 `/dev/cu.usbmodemXXXX` 的新设备。`XXXX` 每台电脑不同，也可能在重新插拔后变化。
`cu.BLTH`、`cu.Bluetooth-Incoming-Port` 和 `cu.sanagS6SPro2` 不是本板的烧录端口。

如果仍没有 USB 串口：换数据线、换电脑 USB 口，并尝试绕过扩展坞直连。
没有识别到串口前，不执行烧录命令。

官方进入下载模式说明：<https://docs.m5stack.com/en/core/AtomS3R>。

## 2. 编译自定义版本

打开 Mac 终端，执行：

```bash
cd /Users/admin/Desktop/workspace/xiaozhi-esp32
bash scripts/build_fangbaobao.sh
```

脚本自动加载 ESP-IDF，并完成编译、合并固件和 ZIP 打包。推荐 ESP-IDF `release/v6.1`，
最低 v6.0.1，不使用 IDF 5.x。若 SDK 装在其他位置：

```bash
IDF_PATH=/path/to/esp-idf bash scripts/build_fangbaobao.sh
```

**只有本次命令正常结束，且显示 `Build completed`，才能继续。**
遇到编译错误、模型资源超出分区或应用超过分区大小时，先停止，不烧录。
`build/` 和 `releases/` 可能保留旧文件，存在文件不代表本次编译成功。

本次输出应包括：

| 文件 | 用途 |
| --- | --- |
| `build/xiaozhi.bin` | 应用固件，首次切换不能只刷它 |
| `build/generated_assets.bin` | 自定义唤醒模型、字体和表情 |
| `build/merged-binary.bin` | 完整合并固件，从地址 `0x0` 烧录 |
| `releases/v<版本号>_m5stack-atoms3r-echo-pyramid-fangbaobao.zip` | 含完整合并固件的 ZIP |

检查文件时间是刚才构建的时间：

```bash
ls -lhT build/xiaozhi.bin build/generated_assets.bin build/merged-binary.bin
ls -lht releases/*fangbaobao.zip
```

## 3. 加载当前终端的烧录工具

构建脚本在子进程里加载 SDK，不会改变当前终端环境。因此烧录前还要执行：

```bash
source /Users/admin/esp/activate-xiaozhi.sh
idf.py --version
```

如果使用其他 SDK 路径，改为 `source /path/to/esp-idf/export.sh`。

检查生成配置，确认是本次版本：

```bash
rg '^CONFIG_(USE_CUSTOM_WAKE_WORD|CUSTOM_WAKE_WORD|CUSTOM_WAKE_WORD_DISPLAY|SR_MN_CN_MULTINET5_RECOGNITION_QUANT8|OTA_URL|PARTITION_TABLE_CUSTOM_FILENAME)=' sdkconfig
```

应包含以下内容（顺序可能不同）：

```text
CONFIG_USE_CUSTOM_WAKE_WORD=y
CONFIG_CUSTOM_WAKE_WORD="ni hao fang bao bao"
CONFIG_CUSTOM_WAKE_WORD_DISPLAY="你好房保保"
CONFIG_SR_MN_CN_MULTINET5_RECOGNITION_QUANT8=y
CONFIG_OTA_URL="https://agent.fangbaobaochina.com/xiaozhi/ota/"
CONFIG_PARTITION_TABLE_CUSTOM_FILENAME="partitions/v2/8m_multinet.csv"
```

若配置不符或 `sdkconfig` 不存在，返回第 2 步，不能使用旧固件继续。

## 4. 设置实际串口并确认芯片

先列出端口：

```bash
python -m serial.tools.list_ports
```

把下面示例替换成刚才实际出现的端口：

```bash
export ESPPORT=/dev/cu.usbmodemXXXX
python -m esptool --chip esp32s3 --port "$ESPPORT" chip-id
```

应识别到 ESP32-S3。`chip-id` 不写入 Flash，但连接时可能复位设备。
如连接超时，再按第 1 步进入下载模式，重新确认端口。
关闭其他占用串口的监视器、串口工具或浏览器烧录页面。

## 5. 首次刷入：推荐使用 IDF 完整烧录

本版本改变了分区布局，首次不能仅升级应用固件，也不能直接通过 OTA 切换。
完成上述编译和配置核对后，在项目目录执行：

```bash
idf.py -p "$ESPPORT" -b 460800 flash
```

此命令按本次构建生成的烧录参数写入 bootloader、分区表、OTA 初始数据、应用和资源。
正常成功时可看到校验成功的信息；命令须以成功状态结束。
如果连接不稳定，将波特率改为 `115200` 后重试。
不需要预先执行 `erase-flash`；整片擦除会清除配网等保存设置。

### 备选：烧录完整合并固件

与上面的 IDF 烧录方式二选一，不必重复执行。

```bash
python -m esptool --chip esp32s3 --port "$ESPPORT" --baud 460800 \
  write-flash 0x0 build/merged-binary.bin
```

若使用 ZIP，先解压本次生成的 `*fangbaobao.zip`，再把命令中的路径改为解压后的
`merged-binary.bin`。不要直接写入 ZIP 文件。
合并镜像可能包含覆盖 NVS 区域的填充数据，应准备重新配网。
不要把 `xiaozhi.bin` 当成完整镜像写到 `0x0`。

## 6. 重启、配网和验证

烧录完成后，如果仍停在下载模式，短按复位键重启。正常使用按板卡要求从 Echo Pyramid 底座供电。
观察日志时，AtomS3R 的 USB 数据线仍需接在电脑上。

串口号可能改变，必要时重新运行 `python -m serial.tools.list_ports` 并更新 `ESPPORT`。

```bash
idf.py -p "$ESPPORT" monitor
```

退出串口监视器：按 `Ctrl+]`。

依次检查：

1. 屏幕和日志显示正常启动，没有循环重启或模型加载失败。
2. 如需重新配网，按照设备屏幕提示操作。
3. OTA 默认地址应为 `https://agent.fangbaobaochina.com/xiaozhi/ota/`。
   如果设备之前在 NVS 的 `wifi/ota_url` 保存过其他地址，它会覆盖固件默认值，需在配网页面改正。
4. 待机时说“你好房保保”，确认能够唤醒并开始对话。
5. 设备播报时再次说“你好房保保”，检查能否打断；再验证录音、播放和断网重连。

MultiNet 按发音识别，同音词“你好方宝宝”也可能触发。
识别率、误唤醒和播报中唤醒效果需要实机确认。

## 当前检查记录（2026-11-13）

- 电脑 USB 列表未见 AtomS3R/ESP32，串口列表未见 USB 烧录端口，尚未建立设备通信。
- 当时 `build/merged-binary.bin` 和 `build/xiaozhi.bin` 时间为 11 月 10 日，属于旧产物，不可用于本次刷机。
- 自定义资源打包为 2,559,361 字节，已验证小于新资源分区的 2,752,512 字节。
- 完整编译此前受执行环境的进程查询权限限制而中断，尚未生成此次可用固件。
  请在 Mac 本机终端执行上述构建命令，以本次成功构建的结果为准。
- 本次仅检查连接与整理步骤，没有执行芯片连接复位、擦除或烧录操作。
