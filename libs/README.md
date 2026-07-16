# libs

`libs/` 保存与具体硬件层无关的通用能力。它可以被 BSP、devices、modules 和 demo 使用，但不应反向依赖这些上层目录。

## 子模块

| 模块 | 说明 |
| --- | --- |
| `common/` | 项目通用状态码、内存段宏和基础类型。 |
| `msg/` | 基于 ThreadX mutex 的 typed topic 消息系统。 |
| `crc/` | CRC8/CRC16 等校验函数。 |
| `control/` | PID 控制器。 |
| `filter/` | IIR、Kalman 1D 等滤波器。 |
| `math/` | 常量、限幅、坐标/角度变换等数学工具。 |
| `runtime/` | DWT 驱动上的运行时间监控和 scope 计时。 |
| `logger/` | 预留日志模块。 |

## 状态码

`libs/common/include/usertypes.hpp` 定义 `types::status`：

- `ok`
- `error`
- `not_configured`
- `invalid_arg`
- `busy`

BSP 和跨层公共函数应优先使用该状态码表达可恢复错误，避免直接向上透出 HAL/USBX/ThreadX 的细节状态。

## 消息系统

`msg` 提供按 payload 类型创建 topic 的轻量发布订阅机制：

- `msg::create<T>()` 为每种 trivially-copyable payload 建立一个静态 topic。
- `msg::subscribe<T>()` 为订阅者分配独立 pending 槽位。
- `msg::publish()` 保存最新值，并为每个订阅者设置 pending。
- `msg::read()` 读取最新值并清除当前订阅者的 pending。

该系统适合模块之间传递“最新状态”，例如遥控器、AHRS 和裁判系统数据。它不是队列，不保留历史消息。

## 运行时监控

`runtime::monitor` 与 `runtime::scope` 用于统计循环耗时、最大耗时、平均耗时和预算超限次数。需要微秒时间基准时，应先确保 `bsp::dwt::init()` 已经完成。

## 设计原则

- `libs/` 中的代码应尽量纯粹、可复用，不知道具体机器人实例。
- 不为单个调用点创建薄封装；工具函数应提供真实复用或边界隔离。
- 并发工具必须说明阻塞行为和 ISR 可用性。
- 数据结构若会经过 `msg` 传递，应保持 trivially-copyable。
