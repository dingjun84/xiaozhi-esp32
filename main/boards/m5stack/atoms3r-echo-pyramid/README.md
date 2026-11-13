# M5Stack AtomS3R + Echo Pyramid

> [!NOTE]
> Echo Pyramid 正常运行时请从 Pyramid 底座的 USB-C 口供电；AtomS3R 的 USB-C 口主要用于烧录。

## 快速构建

推荐使用 build 脚本生成完整固件包：

```bash
python scripts/build.py m5stack/atoms3r-echo-pyramid --name atoms3r-echo-pyramid --zip
```

生成的固件压缩包位于：

```text
releases/v<版本号>_m5stack-atoms3r-echo-pyramid.zip
```

## “你好房保保”自定义版本

完整操作步骤见 [编译与 USB 烧录指南](../../../../docs/fangbaobao-build-and-flash.md)。

```bash
bash scripts/build_fangbaobao.sh
```

脚本与源码放在一起，会自动加载 ESP-IDF 环境、选择此版本并打包完整固件。
支持从任意工作目录调用脚本，不会自动烧录设备。
默认查找 `~/esp/activate-xiaozhi.sh`、`~/esp/esp-idf/export.sh` 或
`~/esp-idf/export.sh`；也可以指定 SDK 路径：

```bash
IDF_PATH=/path/to/esp-idf bash scripts/build_fangbaobao.sh
bash scripts/build_fangbaobao.sh --help
```

此版本使用 ESP-SR MultiNet5 Q8 在设备本地识别 `ni hao fang bao bao`，
显示及上报文字为“你好房保保”，初始检测阈值为 20%。
版本默认唤醒词来自 `config.json` 的 `wake_word` 字段，可用 `--wake-word` 显式覆盖，
例如 `--wake-word 'custom:ni hao fang bao bao:你好房保保'`。

默认 OTA 地址为 `https://agent.fangbaobaochina.com/xiaozhi/ota/`。
设备 NVS 的 `wifi/ota_url` 若已保存其他地址，会覆盖此默认值，需通过配网页面修改。

8 MB Flash 使用 `partitions/v2/8m_multinet.csv`：两个 0x2a0000 字节的应用分区、
一个 0x2a0000 字节的资源分区。MultiNet5 需要约 2.2 MB 模型空间，
因此自定义唤醒词模式下本板改用 14 像素、1 bpp 字体以容纳中文字体和表情；
原版 WakeNet 模式仍使用 16 像素、4 bpp 字体。

**首次切换必须通过 USB 烧录完整固件包，包括新分区表和资源；不能仅 OTA 应用固件。**
打包文件名为 `releases/v<版本号>_m5stack-atoms3r-echo-pyramid-fangbaobao.zip`。
后续 OTA 应匹配此版本身份及资源格式，避免被普通版本覆盖。

需在实机验证唤醒率、误唤醒、播放中唤醒、内存余量及 OTA 连接。
MultiNet 按发音识别，无法区分“房保保”和同音的“方宝宝”。

## 手动配置

配置编译目标：

```bash
idf.py set-target esp32s3
```

打开配置菜单：

```bash
idf.py menuconfig
```

选择板卡：

```text
Xiaozhi Assistant -> Board Type -> M5Stack AtomS3R + Echo Pyramid
```

配置 Flash 大小：

```text
Serial flasher config -> Flash size -> 8 MB
```

配置分区表：

```text
Partition Table -> Custom partition CSV file -> partitions/v2/8m.csv
```

配置 PSRAM：

```text
Component config -> ESP PSRAM -> SPI RAM config -> Mode (QUAD/OCT) -> Octal Mode PSRAM
```

编译：

```bash
idf.py build
```

## 合并固件

成功构建后，可使用以下命令按当前构建的真实分区布局合并固件：

```bash
idf.py merge-bin
```

烧录合并后的固件：

```bash
python -m esptool --chip esp32s3 --port /dev/cu.usbmodemXXXX --baud 460800 \
    write-flash 0x0 build/merged-binary.bin
```

## 参考资料

- https://github.com/m5stack/M5Echo-Pyramid
