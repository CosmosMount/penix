# board

`board/` 保存 STM32CubeMX 生成工程和与芯片强相关的构建材料。它是框架的硬件根层，负责提供 HAL 句柄、ThreadX/USBX 源码、启动文件、链接脚本和 ARM 工具链配置。

## 主要内容

| 路径 | 说明 |
| --- | --- |
| `board.ioc` | CubeMX 工程配置，也是 `configs/cmake/import_ioc.cmake` 解析硬件资源的输入。 |
| `Core/` | HAL 初始化、外设句柄、中断入口、ThreadX 启动入口等 CubeMX 生成代码。 |
| `AZURE_RTOS/` | ThreadX 应用配置与初始化胶水代码。 |
| `USBX/` | USBX 设备描述符、CDC ACM glue 和目标配置。 |
| `Drivers/` | STM32H7 HAL/LL 与 CMSIS 头文件和源码。 |
| `Middlewares/` | ThreadX、USBX 和 ST/CMSIS 中间件源码。 |
| `cmake/` | `gcc-arm-none-eabi`、`starm-clang` 工具链文件和 CubeMX 源码收集逻辑。 |
| `STM32H723XG_FLASH.ld` | 当前固件链接脚本。 |

## 与框架的关系

顶层 `embedded_framework/CMakeLists.txt` 会 `add_subdirectory(board/cmake/stm32cubemx)`，把 CubeMX 生成代码、中间件和 HAL 驱动接入最终固件目标。上层代码不应直接依赖 `board/Core/Src` 中的实现细节；需要使用硬件资源时，优先通过 `bsp/` 中的封装访问。

`board/Core/Src/app_threadx.c` 在 ThreadX 初始化阶段调用 `app_start()`。当前 `app_start()` 由 `demo/app.cpp` 提供，因此应用装配逻辑应放在框架侧，而不是改写 CubeMX 生成文件主体。

## 修改原则

- CubeMX 重新生成后，优先保留 USER CODE 区域内的必要桥接代码，例如 `extern void app_start(void);` 与调用点。
- 新增外设或调整管脚时先更新 `board.ioc`，再让 `configs/` 生成新的 BSP 绑定常量。
- 不在 `board/` 中加入业务逻辑；业务逻辑属于 `demo/` 或未来正式 app，外设封装属于 `bsp/`。
- 工具链、链接脚本和中间件源码变化会影响全工程，应配合一次完整 ARM 构建验证。
