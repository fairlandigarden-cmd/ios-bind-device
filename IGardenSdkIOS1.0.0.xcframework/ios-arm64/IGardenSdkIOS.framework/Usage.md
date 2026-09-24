# iGarden SDK for iOS 使用指南
## IGardenSdkIOS 是基于 Swift 现代并发（Swift 6 / Concurrency）与 CoreBluetooth 构建的智能硬件 BLE 辅助 Wi-Fi 配网与云端设备绑定 SDK。支持通用模组与**新能源智能设备（Solar / 储能 / 逆变器）**的双重配网架构。

## 1. SDK 导入
① 本地导入：
将 SDK 导入到主 App 项目中：
1. 打开 iOS App 主工程（Xcode）。
2. 将 IGardenSdkIOS.xcframework 文件夹直接拖入 Xcode 左侧的项目导航栏（Project Navigator）中。
3. 勾选 Copy items if needed 并点击 Finish。
4. 点击左侧最上方的项目蓝标，进入 Target -> General 选项卡。
5. 滑动到 Frameworks, Libraries, and Embedded Content：
  - 确认 IGardenSdkIOS.xcframework 已存在；
  - 将右侧的 Embed 属性设置为 Embed & Sign（关键步骤）。

② 远程导入：
git地址：http://192.168.90.23/aiot/frontend/flutter-igarden-sdk/igarden-ios-repo.git 暂定
方式 1：顶部菜单栏
File → Add Package Dependencies…（部分旧 Xcode 版本在 File → Swift Packages → Add Package Dependency）
弹出窗口后：右上角就是搜索输入框，这里粘贴 Git 仓库地址
方式 2：项目面板
1. 左侧 Project Navigator 点击最顶部你的项目名称（蓝色项目图标）
2. 中间面板，上方选中 PROJECT（不是 Target）
3. 切换标签页到 Package Dependencies
4. 点下方 + 按钮，弹出同样添加 Package 窗口，右上角输入 Git 地址
✅ 重点：输入框在弹窗右上角。在右上角搜索框粘贴你的仓库 HTTPS 地址，回车，Xcode 拉取仓库信息。
完整流程
1. 粘贴仓库地址（https://xxx/xxx.git）按回车
2. 下方 Dependency Rule：选择版本规则（选 Up to Next Major Version，填你的 tag 版本例如 1.0.0）
3. Next → Add Package，选择要添加到的 Target，完成

## 2. 权限配置 (Info.plist)
在集成该 SDK 的 iOS 主工程 Info.plist 中添加蓝牙权限描述：
code
Xml
<!-- 蓝牙扫描与连接权限 (iOS 13+) -->
<key>NSBluetoothAlwaysUsageDescription</key>
<string>需要使用蓝牙以扫描并连接周围的智能设备进行配网</string>

<key>NSBluetoothPeripheralUsageDescription</key>
<string>需要使用蓝牙连接设备</string>

## 3. 初始化 SDK
建议在 App 启动时（例如 AppDelegate 或 SwiftUI App.init）进行全局初始化：
code
Swift
import IGardenSdkIOS

// 全局初始化 SDK
IGardenSDK.initialize(
    environment: .cn,                  // 环境选择：.cn (中国) / .eu (欧洲) / .us (美洲) / .test / .dev / .sit
    userToken: "YOUR_USER_AUTH_TOKEN",  // 当前登录用户的 Bearer Token
    enableLog: true                    // 是否开启控制台调试日志
)
动态更新用户 Token 与环境
当用户登录成功、刷新 Token 或退出登录时调用：
code
Swift
// 更新用户 Token
IGardenSDK.updateUserToken(newToken)

// 切换服务器环境
IGardenSDK.updateEnvironment(.eu)

## 4. 设备扫描与发现
使用 IGardenBLEManager 扫描周围符合前缀白名单（iGarden, fairland, Robot, pool, FL, Lawn, Solar, Inverter 等）的设备：
code
Swift
import UIKit
import CoreBluetooth
import IGardenSdkIOS

class ScanViewController: UIViewController, IGardenBLEManagerDelegate {
    
    var discoveredPeripherals: [CBPeripheral] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 设置代理
        IGardenBLEManager.shared.delegate = self
    }
    
    // 页面展示时开启扫描 (15 秒超时自动停止，节省电量)
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        IGardenBLEManager.shared.startScan(timeout: 15.0)
    }
    
    // 页面离开时停止扫描
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        IGardenBLEManager.shared.stopScan()
    }
    
    deinit {
        MainActor.assumeIsolated {
            IGardenBLEManager.shared.stopScan()
            IGardenBLEManager.shared.delegate = nil
        }
    }
    
    // MARK: - IGardenBLEManagerDelegate
    
    func bleManager(_ manager: IGardenBLEManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) {
        let deviceName = peripheral.name ?? "未知设备"
        print("发现目标设备: \(deviceName), RSSI: \(rssi)")
        
        if !discoveredPeripherals.contains(peripheral) {
            discoveredPeripherals.append(peripheral)
            // 刷新列表 UI
        }
    }
    
    func bleManager(_ manager: IGardenBLEManager, didUpdateState state: CBManagerState) {
        if state == .poweredOn {
            manager.startScan()
        } else {
            print("蓝牙不可用，当前状态: \(state.rawValue)")
        }
    }
}

## 5. 一键配网与设备绑定 (核心流程)
SDK 提供统一门面 IGardenSDK.configDevice.startConfig，支持通过 deviceType 自动分发双模组流程：
.common（通用模组）：FF04 写配置 
 FF04 读 SN/PID 
 退出配网 
 云端轮询上线。
.solar（新能源设备）：FF07 开启 Notify 监听 
 FF06 发送 Type 7 查询状态 
 FF06 发送 Type 0 获取设备信息 
 App 端主动调用云端 POST /devices/bind 
 FF06 发送 Type 4 下发 MQTT 与 Wi-Fi 
 以 iotid 在云端轮询结果。
code
Swift
import UIKit
import CoreBluetooth
import IGardenSdkIOS

class ProvisioningViewController: UIViewController {
    
    var selectedPeripheral: CBPeripheral!
    
    /// 发起配网
    /// - Parameters:
    ///   - deviceType: 模组类型 (.common 通用模组 / .solar 新能源设备)
    ///   - ssid: Wi-Fi 名称 (2.4GHz)
    ///   - password: Wi-Fi 密码
    func startProvisioning(deviceType: IGardenDeviceType = .common, ssid: String, password: String) {
       Task { [weak self] in
            do {
                // 调用 SDK 开始全流程配网与绑定
                let (sn, pid) = try await IGardenSDK.configDevice.startConfig(
                    deviceType: deviceType,
                    peripheral: selectedPeripheral,
                    ssid: ssid,
                    password: password
                ) { [weak self] step in
                    guard let self = self else { return }
                    // 实时监听配网各阶段进度，刷新 UI 进度条或文案switch step {
                    case .fetchingToken:
                        print("📡 进度: 正在向云端获取配网凭据...")
                    case .connectingBLE:
                        print("🔗 进度: 正在建立蓝牙连接...")
                    case .discoveringService:
                        print("🔍 进度: 正在发现配网特征值...")
                    case .enablingNotification:
                        print("🔔 进度 (新能源): 正在开启特征值通知 (Notify)...")
                    case .readingDeviceIdentity:
                        print("🆔 进度: 正在读取设备序列号/参数...")
                    case .bindingCloudDevice:
                        print("☁️ 进度 (新能源): 正在向云端主动绑定设备...")
                    case .sendingWiFiConfig:
                        print("📶 进度: 正在向设备写入 Wi-Fi 与鉴权配置...")
                    case .notifyingDeviceExit:
                        print("🚀 进度: 通知设备退出配网模式，设备正在连接 Wi-Fi...")
                    case .pollingCloudResult(let attempt, let max):
                        print("⏳ 进度: 等待设备在云端上线 (\(attempt)/\(max))...")
                    case .success(let sn, let pid):
                        print("🎉 配网与绑定完全成功! SN: \(sn), PID: \(pid)")
                    }
                }
                guard let self = self else { return }
                
                // 配网成功后续处理print("✅ 最终配网完成！设备 SN: \(sn), 产品码 PID: \(pid)")
                
            } catch let error as IGardenError {
                guard let self = self else { return }
                // 业务异常精准捕获print("❌ 配网失败 [错误码: \(error.code)]: \(error.localizedDescription)")
            } catch {
                guard let self = self else { return }
                print("❌ 发生未预期错误: \(error.localizedDescription)")
            }
        }
    }    
}

## 6. 取消配网
如果用户在配网过程中点击了“取消”或返回上一页，调用 stopConfig 即可即时中断网络轮询并断开蓝牙连接：
code
Swift
// 取消/终止当前正在进行的配网流程
IGardenSDK.configDevice.stopConfig()

## 7. 常见错误码与排查 (IGardenError)
错误类型    错误码 (code)    说明与排查建议
bluetoothUnauthorized    1001    蓝牙权限被拒绝，请引导用户在系统设置中允许 App 使用蓝牙。
bluetoothPoweredOff    1002    手机蓝牙未开启，请引导用户在“设置”或控制中心打开蓝牙。
bleConnectionFailed    2002    蓝牙连接设备超时或失败，请确保设备在有效距离内且未被其他手机连接。
characteristicNotFound    2005    未找到对应特征值（通用 0000FF04，新能源 0000FF06/0000FF07），确认设备固件是否正确。
writeCharacteristicFailed    2006    写入特征值失败。若伴随 Authentication is insufficient，SDK 会自动预留 3 秒等待用户在 iOS 系统弹窗上点击“配对”并自动重试。
readCharacteristicFailed    2007    读取特征值失败或固件未返回数据。
invalidDeviceResponse    2008    设备回包格式不符或固件返回 parameter invalid（请检查 Wi-Fi 名称/密码/Broker 是否含有非法字符）。
fetchBindTokenFailed    3003    获取云端 Token 或调用绑定接口失败，检查当前用户的 userToken 是否有效或网络是否通畅。
cloudBindTimeout    3004    100 秒内设备未在云端上线。请检查 Wi-Fi 密码是否正确、是否为 2.4GHz 频段 Wi-Fi。
cancelledByUser    4001    用户主动调用了 stopConfig() 取消了配网。


# 关于 iOS 平台不支持通用经典蓝牙（Classic Bluetooth）配网的技术说明
本文档用于向产品、硬件、测试及研发团队说明 iOS 平台对于经典蓝牙（Classic Bluetooth / SPP）通信的系统级限制，以及为什么在 iOS 端采用 BLE（低功耗蓝牙） 架构进行 Wi-Fi 配网与数据交互。

##1. 核心结论
Android 端：系统底层开放了经典蓝牙的通用扫描（BluetoothAdapter.startDiscovery）和通用串口协议（SPP / RFCOMM），无需硬件认证即可直接收发自定义字节。
iOS 端：苹果对经典蓝牙有严格的硬件安全芯片 + 协议许可 + App Store 审核三重限制。在未搭载苹果 MFi 专用鉴权芯片 的情况下，iOS App 无法通过代码扫描、连接经典蓝牙设备并收发自定义数据。
行业标准：当前所有 IoT 智能设备（智能泳池机器人、庭院割草机、ESP32/Realtek 模组等）在 iOS 端的辅助配网方案 100% 基于 BLE（低功耗蓝牙，GATT 协议） 实现。

##2. iOS 蓝牙框架体系对比
| 维度                | 经典蓝牙 (Classic Bluetooth / SPP)       | 低功耗蓝牙 (BLE / GATT) |
| ----               | ----                                    | ----                  |
| iOS 依赖框架         | ExternalAccessory.framework            | CoreBluetooth.framework |
| 硬件要求             | 必须内嵌 Apple MFi 硬件鉴权芯片            | 无限制（任何标准 BLE 4.0+ 芯片均可） |
| 认证与成本           | 需加入苹果 MFi 会员、缴纳年费并采购专用芯片    | 完全免费、无需认证 |
| 设备扫描 API         | ❌ 无通用扫描 API（仅能调起系统级配件弹窗）   | ✅ CBCentralManager.scanForPeripherals |
| 自定义数据传输        | ❌ 仅限已获批的 MFi 专属协议               | ✅ 读写自定义 GATT 服务与特征值（如 0000FF04） |
| App Store 上架      | 必须提供 MFi PPID 编号，无证书必被拒审       | 声明标准蓝牙隐私权限即可过审 |
| 本 SDK 支持状态      | 不支持（受限于 iOS 系统机制）               | 完全支持（推荐与标准方案） |

##3. 为什么经典蓝牙无法用于普通 IoT 配网？
###3.1 苹果系统的硬件级“白名单”机制
在 iOS 系统中，经典蓝牙的数据通信必须走 ExternalAccessory 协议。当经典蓝牙设备尝试与 iPhone 通信时，iOS 底层会发起双向加密握手：
如果设备主板上没有苹果 MFi 协处理器芯片提供数字签名，iOS 系统会立即阻断数据链路。
App 端即使调用 EASession 也无法打开输入输出流（InputStream / OutputStream）。
###3.2 无法实现静默扫描与自定义 UI
经典蓝牙在 iOS 上不存在后台静默扫描周围设备列表的 API。
必须强制弹出 iOS 系统原生的配件选择器（showBluetoothAccessoryPicker），用户体验生硬且无法在 App 内自由定制扫描列表与信号强度（RSSI）过滤。
###3.3 审核被拒风险（Guideline 2.5.2）
如果在 iOS 工程的 Info.plist 中声明了经典蓝牙协议（UISupportedExternalAccessoryProtocols），在提审 App Store 时，苹果审核团队会要求提交对应硬件的 MFi PPID (Product Plan ID)。若无法提供，App 将被直接下架或拒绝上架。

##4. 解决方案与建议
###4.1固件端配置：
确保设备端模组在进入配网状态时，开启 BLE 广播（广播名包含 iGarden / fairland 等白名单前缀）。
开放标准 GATT 基础服务，并挂载配网特征值 0000FF04-0000-1000-8000-00805F9B34FB（支持 Write 与 Read/Notify）。
###4.2App 端配置：
使用 iOS SDK 提供的 IGardenBLEManager 开展 BLE 扫描、连接与数据下发，免除任何 MFi 认证成本与审核风险。
