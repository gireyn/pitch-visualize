# PitchVisual

使用 **Flutter / Dart** 重写的离线音高监测器，支持 **iOS 与 Android**。
同一套音高算法、微分音调律和界面运行于双端，无广告、无账号、无运行时联网服务。

## 功能

- 界面自动跟随系统语言：中文显示简体中文，英文显示英文，其他语言默认使用英文；支持运行期间的系统语言更新。

- 实时单声音高检测、音高历史曲线、频率与音分偏差、调音器。
- 默认 FFT 滚动频谱：黑底橙黄色强度图，纵轴为对数频率并按当前调律标注音高名；每个八度等高。
- 频谱覆盖 C1–C9（约 33 Hz–8.37 kHz），色标为 −90 至 0 dBFS；支持冻结、回放与缩放，可在「更多选项」切回音高曲线。
- 默认 **7ed2 on C**，内置 **天干音阶**；支持通过系统文件选择器导入 xen-tuner 文本配置。
- 在「设置 → 调律」调整 **0–72 EDO**，并在「选择调律」中选择「使用 EDO 刻度」启用；0 只显示八度刻度。音高曲线、FFT 频谱和调音器使用迁移自 XenSynth 的分级刻度，密集刻度随缩放渐隐。
- 选用内置或导入的调律配置后，优先按配置绘制刻度和音名；EDO 数值保留，重新选择「使用 EDO 刻度」即可恢复。设置与当前刻度模式会保存到本地。
- 图表左上角显示当前调律、右上角显示 BPM，均为小号文字水印；调律选择、导入和速度调整统一在「设置」中进行。
- 支持音分、频率比、等分律、任意周期、数学表达式、中文音名和逐音灰度颜色。
- 调律原文和解析结果保存到本地，源文件移动或失效后仍可使用；修改源文件后需重新导入。
- 录音、自动保存 WAV、录音库、导入、播放、暂停续播和删除；每段最长 5 分钟。
- PCM16 单/双声道 WAV 输入，8–192 kHz，导入后统一为单声道；设备采集保留原始采样率。
- 视觉节拍器、BPM、拍号、节拍线、缩放、噪声阈值、平滑、颜色和快捷按钮设置。
- 竖屏、横屏、平板及系统大字体布局；冻结图表和手动调整音域。
- 音高曲线与 FFT 频谱支持双指竖直拉开放大、捏合缩小，以及上下拖动音域；手动调整会暂停自动跟随，可点图表顶部居中的定位按钮恢复。
- 后台或系统音频中断时释放麦克风、结束并保存录音；回放保留暂停位置。

应用启动后会请求麦克风权限，授权后自动连续测量音高。点击屏幕底部 **录音**
才开始录制，再点击 **保存录音** 结束并保存，音高测量继续进行。
未点击录音时不保存音频；录音只存储于应用私有目录。
本应用用于人声或单音乐器，不做复音分离。视觉节拍器不发声。

## 运行

本次验证环境：Flutter **3.47.3** / Dart **3.13.3**，Xcode **27.0**。
最低目标：Android API **24**，iOS **15.0**。

```sh
flutter pub get
flutter gen-l10n
flutter devices
flutter run -d <device-id>
```

Android 需安装对应 Android SDK、构建工具与 JDK。iOS 构建需 macOS 与 Xcode；
真机运行请在 `ios/Runner.xcworkspace` 的 Signing & Capabilities 中选择开发团队。
麦克风权限声明已分别配置在 AndroidManifest.xml 和 Info.plist。

```sh
# Android APK（当前 release 使用开发调试签名；发布前配置自己的签名）
flutter build apk --release

# iOS 模拟器
flutter build ios --simulator --debug --no-codesign

# iOS 真机未签名构建
flutter build ios --release --no-codesign
```

Android 输出：`build/app/outputs/flutter-apk/app-release.apk`。
iOS 输出：`build/ios/iphonesimulator/Runner.app` 或 `build/ios/iphoneos/Runner.app`。
App Store / Play 发布所需的生产签名、商店资料和真机验收由发布者配置。

## 验证

```sh
flutter analyze
flutter test

# 在已启动的 iOS 或 Android 模拟器上验证真实原生通道、存储、回放和音高分析
flutter test integration_test/platform_smoke_test.dart -d <device-id>
```

测试覆盖调律表达式与缓存、标准 DFT/FFT 数值、已知频率与谐波、连续重采样、
WAV 数据校验、录音状态、权限拒绝、保存失败、后台中断，以及小屏/横屏/大字体布局。
集成测试需授予麦克风权限以验证启动后自动测量；测试生成并清理自己的测试 WAV，
不会保存麦克风音频。
真机还应验收：首次授权/拒绝、内置麦克风、蓝牙/有线耳机、电话中断和文件选择器。

## 目录

```text
lib/
  domain/audio/        FFT、自相关音高算法、重采样、常驻分析 isolate
  domain/tuning/       xen-tuner 调律与数学表达式解析
  domain/models/       设置和 WAV 数据
  data/services/       平台通道
  data/repositories/   调律设置、录音文件管理
  ui/                  Flutter 界面和监测状态
android/               Kotlin 麦克风、播放器、文件选择器
ios/                  Swift 麦克风、播放器、文件选择器、隐私清单
assets/tunings/         内置调律
test/                 单元与组件测试
integration_test/      双端原生通道冒烟测试
```

音频通过原生接口传入 PCM16；常驻 Dart isolate 将其连续重采样为 44.1 kHz，
运行 4096 点 FFT + 自相关检测，避免在界面线程执行重计算。
同一 FFT 经过 Hann 窗幅值校正生成频谱，以 576 个对数频率带传回界面；
频谱不受单声音高检测的门限影响，可显示泛音、噪声和无音高信号。
历史频谱按小图块缓存，音频丢帧处保留空隙，冻结期间仍继续采集。
算法保留原版的倍频修正与频谱插值，并修正了旧 FFT 的数值问题。
对比方法和结果见 [DSP 测试说明](test/domain/audio/README.md)。

原 Java 项目 `app/`、JVM 测试 `tests/`、`build.sh` 和原 APK 暂时保留作为迁移参考，
不参与 Flutter 构建。原说明见 [legacy-android.md](docs/legacy-android.md)，
实现决策见 [flutter-migration.md](docs/flutter-migration.md)。

Android 保留原应用 ID `com.tadaoyamaoka.vocalpitchmonitor`，兼容读取原设置和私有录音。
覆盖旧安装仍要求相同签名；默认 Flutter 调试签名通常与旧 APK 不同，请勿为覆盖安装而直接删除有数据的旧应用。
iOS bundle ID 为 `com.tadaoyamaoka.pitchVisual`。

## 来源与许可

原 VocalPitchMonitor：Apache-2.0，© tadaoyamaoka。
xen-tuner 调律语法来源：musescore-xen-tuner，GPL-3.0，© euwbah。
EDO 分级刻度模式与密度渐隐算法迁移自 XenSynth。
保留原项目的来源与许可声明，Flutter SDK 及其依赖许可可在应用「设置 → 开源许可」查看。
