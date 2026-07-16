# bsp

`bsp/` 是框架对 STM32 HAL、ThreadX 和底层外设句柄的隔离层。它向上暴露稳定的 C++ 接口，向下管理 HAL 句柄、DMA、中断回调、信号量和外设初始化细节。

## 子模块

| 模块 | 说明 |
| --- | --- |
| `can/` | FDCAN classic/FD 初始化、发送、接收回调注册和错误信号量。 |
| `usart/` | UART/USART DMA/IT/block 模式发送，RX-to-IDLE 接收和回调分发。 |
| `spi/` | SPI 总线访问封装，供 IMU/LED 等设备使用。 |
| `pwm/` | 定时器 PWM 通道配置和占空比输出。 |
| `dwt/` | DWT CYCCNT 时间基准、延时、时间线和 delta 计算。 |
| `exti/` | 外部中断回调注册和分发。 |
| `flash/` | Flash 擦写与 HAL 状态转换。 |
| `usb/` | USBX CDC ACM 读写线程、typed packet binding 和运行状态。 |
| `bsp/` | 预留的 BSP 聚合入口。 |

## 设计边界

- BSP 可以包含 HAL 头文件和 `tx_api.h`，上层设备/模块应尽量只依赖 BSP 暴露的类型。
- 公共操作优先返回 `types::status`，把 HAL 返回值转换成项目状态码。
- 通信类 BSP 通过回调、用户指针、信号量或状态对象与上层交互，不在 BSP 内部绑定具体业务。
- 由 `configs/generated/config.hpp` 生成的 `bsp::can`、`bsp::usart`、`bsp::spi`、`bsp::pwm` 配置是外设枚举和启用状态的来源。

## 使用示例

CAN 设备通常先确保总线初始化，再登记接收分发：

```cpp
bsp::can::init(bsp::can::bus::fdcan1, bsp::can::bus_type::classic);
bsp::can::register_rx_handler(bsp::can::bus::fdcan1, handler, user);
bsp::can::transmit(bsp::can::bus::fdcan1, id, data, len);
```

USART DMA 接收通常使用 RX-to-IDLE：

```cpp
bsp::usart::init(app::uart::dr16, bsp::usart::mode::dma);
bsp::usart::start_rx_to_idle(app::uart::dr16, buffer, len, rx_callback, user, notify_sem);
```

## 新增 BSP 的要求

新增外设封装时，应先确认它是否真的是跨设备复用的硬件资源。如果只是某个设备协议的一部分，应放在 `devices/`。BSP 新接口需要明确：

- 使用哪个 generated 配置或 HAL 句柄。
- 是否可重复初始化。
- 中断/线程上下文下哪些接口可调用。
- 错误如何通过 `types::status`、信号量或 telemetry 暴露。
