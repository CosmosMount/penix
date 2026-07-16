# modules

`modules/` 保存可复用的服务模块。模块通常拥有 ThreadX 线程、信号量、内部状态和 telemetry，并通过 `msg` topic 向外发布最新状态。

## 子模块

| 模块 | 说明 |
| --- | --- |
| `ahrs/` | BMI088 读取、温控、Quaternion EKF 姿态解算和 AHRS 消息发布。 |
| `remoter/` | DR16/VT03 遥控器接收解析、来源合并和遥控状态发布。 |
| `referee/` | 裁判系统串口接收、协议解析和裁判数据发布。 |

## 模块边界

- 模块可以依赖 `devices/`、`bsp/`、`libs/` 和 generated 配置。
- 模块负责持续运行的服务流程，不负责机器人具体行为编排。
- 模块对外优先提供 `service::instance().init(config)`、`diagnostics()`、`heartbeat_sem()` 或 topic 消息。
- 模块内部线程优先级、超时和开关应来自 `params.json` 或模块 `config`。

## AHRS

`ahrs::service` 管理 BMI088、温控线程相关资源、gyro ready 信号量和姿态解算循环。解算结果写入 `ahrs::message`，诊断数据保存在 `ahrs::telemetry`。

典型职责：

- 初始化 IMU 和内部 ThreadX 资源。
- 等待陀螺仪数据就绪。
- 更新 EKF、欧拉角、total yaw 和运行时间统计。
- 发布最新姿态消息。

## Remoter

`remoter` 支持 DR16 和 VT03。具体接收类负责串口 DMA 接收和原始帧解析，`remoter::service` 负责合并来源并发布统一 `remoter::state`。

遥控器数据属于状态流，调用方应通过 `msg::subscribe<remoter::state>()` 获取，而不是直接读取串口缓冲区。

## Referee

`referee::service` 通过裁判串口接收帧，解析机器人状态、功率热量、增益、受伤等数据，并发布 `referee::data`。UI 发送属于 `devices/ui`，裁判接收服务属于 `modules/referee`。

## 新增模块的要求

新增模块时先回答三个问题：

- 它是否需要独立线程或周期性执行。
- 它向其他模块发布什么消息，payload 是否 trivially-copyable。
- 它的配置来自 `params.json`、`robot.json`，还是运行时传入 `config`。

如果只是设备协议实现，应放入 `devices/`；如果只是算法工具，应放入 `libs/`。
