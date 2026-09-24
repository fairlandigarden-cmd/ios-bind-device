# IGardenSDK-iOS 架构目录结构

```text
IGardenSDK/
├── IGardenSDK.swift                   // SDK 全局入口与初始化配置（环境、Token 等全局上下文，对应 Android IGardenSDKApplication）
├── IGardenConfigDevice.swift          // 配网统一调度门面（对外入口，支持按 deviceType 分发通用与新能源流程，支持全局超时与取消）
│
├── Process/                           // 配网业务流程层 (采用模板模式实现通用与新能源模组解耦)
│   ├── BaseConfigProcess.swift        // 流程抽象基类 (封装 Step 1~3 获取Token/蓝牙连接/服务发现、云端上线轮询及取消模板)
│   ├── CommonConfigProcess.swift      // 通用模组配网流程 (FF04写入Wi-Fi配置 → 读取SN/PID → 延时发送退出指令 → 云端轮询)
│   └── SolarConfigProcess.swift       // 新能源设备配网流程 (FF07 Notify → Type 7状态查询 → Type 0请求参数 → 主动云端绑定 → Type 4配网下发 → 轮询)
│
├── Models/                            // 数据模型层 (全面支持 Codable & Sendable，无 Actor 隔离)
│   ├── DeviceConfigInfoEntity.swift   // 通用模组：写入蓝牙的 Wi-Fi 与 Broker/Token 配置实体
│   ├── DeviceConfigInfoBean.swift     // 通用模组：读取到的 SN 与 PID 返回实体
│   ├── DeviceConfigResultBean.swift   // 通用模组：退出配网指令模型 {"code": 0}
│   ├── SolarDeviceModels.swift        // 新能源模组：Type 7 / Type 0 / Type 4 请求与应答全套协议模型 (含 SolarBleResponse / ReqPacket)
│   ├── BindInfoBean.swift             // 云端下发的 BindToken 与 GroupId 响应模型 (对应 Android DeviceBindInfoBean)
│   ├── BindResultBean.swift           // 云端轮询的绑定状态响应模型 (对应 Android DeviceBindResultBean)
│   └── IGardenError.swift             // 统一错误码与枚举 (整合蓝牙连接失败、鉴权不足、超时、云端绑定异常等错误码)
│
├── Bluetooth/                         // 蓝牙核心层 (基于 CoreBluetooth，兼容 Swift 6 并发安全)
│   ├── IGardenBLEManager.swift        // CoreBluetooth 管理器 (扫描、连接、发现 FF04/FF06/FF07 特征值、Notify 监听与有/无响应安全写入)
│   ├── IGardenBLEConstants.swift      // 蓝牙 UUID (通用 FF04, 新能源FF06/FF07 FF06/FF07)、超时时间及设备名称扫描过滤前缀
│   └── IGardenBLEDelegate.swift       // 蓝牙事件与状态回调协议 (BLE 状态、扫描发现、连接/断开事件通知)
│
├── Network/                           // 网络请求层 (基于 URLSession，100% 对齐 Android OkHttp 拦截器 Headers)
│   ├── IGardenNetworkManager.swift    // 网络请求客户端 (实现 fetchBindToken、bindSolarDevice 主动绑定、pollBindResult 轮询)
│   ├── IGardenEnvironment.swift      // 多环境配置与域名映射 (CN, EU, US, DEV, TEST, SIT 等)
│   └── IGardenAPIEndpoint.swift       // REST API 统一路由定义 (bindToken, bindDevice, bindResult)
│
└── Utils/                             // 辅助工具层
    ├── IGardenHeaderUtil.swift        // 请求头系统参数生成器 (自动注入 tst.BundleID、language、+08:00 时区、terminal=1)
    ├── IGardenLog.swift               // 统一日志格式化工具 (支持 DEBUG 模式与等级过滤)
    └── IGardenStorage.swift           // 本地轻量存储封装 (UserDefaults 封装 Token 与偏好)
