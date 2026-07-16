# devices

`devices/` 放置基于 BSP 的具体硬件设备和统一设备接口。它的职责是把“某种硬件协议或芯片差异”收敛成上层可使用的能力，而不是创建业务线程。

## 子模块

| 模块 | 说明 |
| --- | --- |
| `motors/` | 电机统一接口、基础 `motorhandler`、DJI/LK/达妙/XV2 电机和协议处理。 |
| `imu/` | IMU 基础接口与 BMI088 设备实现。 |
| `led/` | 板载/外设 LED 控制。 |
| `ui/` | 裁判系统 UI 画布对象、帧组包和串口发送。 |

## 设计边界

- 设备可以依赖 `bsp/`、`libs/` 和生成配置，但不应直接绕过 BSP 操作 HAL 句柄。
- 设备层负责协议解析、输出组包、状态缓存和能力声明；持续运行的线程属于 `modules/`。
- 相似设备应共享接口。例如电机统一使用 `motors::api`、`motors::motor`、`motors::command`、`motors::feedback` 和 `motors::capabilities`。
- 设备实现应显式暴露自身能力，调用方通过 `supports()` 或 capability 判断控制模式，而不是猜测具体型号。

## 电机结构

`motors/motor/include/motor.hpp` 定义统一接口：

- `motors::config`：CAN 总线、帧类型、CAN ID 和初始控制模式。
- `motors::command`：电流、力矩、位置、速度、MIT 参数。
- `motors::feedback`：位置、速度、力矩、电流、温度、错误码。
- `motors::api`：上层依赖的最小能力面。
- `motors::motor`：真实电机基类，提供 alive check、命令缓存和模式切换。

`motors/motorhandler` 负责总线注册、接收分发和周期发送。具体厂商 handler 只处理本协议相关的登记表、反馈解析和控制帧打包。

## IMU 结构

`imu/imu/include/imu.hpp` 定义通用 IMU 接口和缓存数据结构。BMI088 实现负责 SPI 配置、芯片自检、数据读取、校准和温控。AHRS 服务通过该接口读取 `imu::reading`，不直接处理 BMI088 寄存器细节。

## UI 结构

`ui::canvas` 是裁判系统 UI 的对象池和发送器。调用方创建或修改对象后调用 `update()`，由 canvas 扫描 dirty 对象并按裁判系统协议组包。UI 使用 `app::uart::referee` 作为默认串口绑定。

## 新增设备的要求

新增设备前先判断它是否属于已有类别：

- 新电机型号：优先扩展 `motors/` 的具体厂商实现和 handler。
- 新 IMU：实现 `imu::imu` 接口，避免让 AHRS 直接依赖芯片类。
- 新业务服务：不要放在 `devices/`，应放在 `modules/`。

设备代码应保持协议细节在本模块内，向上只暴露必要状态、命令和诊断信息。
