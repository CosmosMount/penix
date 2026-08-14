# demo

`demo/` 保存板端联调入口、具�?demo 和主机侧验证脚本。它既是当前应用入口，也是验�?BSP、devices �?modules 的最小装配层�?

## 入口

`demo/app.cpp` 提供 `extern "C" void app_start()`，由 `boards/stm32h723/Core/Src/app_threadx.c` �?ThreadX 初始化阶段调用。当前通过手动打开对应行选择运行�?demo�?

```cpp
extern "C" void app_start()
{
    // demo::imu::run();
    // demo::motor::run();
    demo::remoter::run();
    // demo::referee_ui::run();
    // demo::usart::start();
    // demo::usb::start();
}
```

同一时间建议只启用一个需要占用外设或主机脚本�?demo，避免串口、CAN �?USB 资源冲突�?

## 子模�?

| 模块 | 说明 |
| --- | --- |
| `common/` | demo 通用 packet、checksum、debug state 和辅助函数�?|
| `imu/` | BMI088/AHRS 板端联调�?|
| `motor/` | 根据 `robot.json` 实例化电机并进行真实电机控制验证�?|
| `remoter/` | DR16/VT03 遥控器服务验证�?|
| `referee_ui/` | 裁判系统 UI 绘制验证�?|
| `usart/` | USART1 DMA 收发链路验证�?|
| `usb/` | USBX CDC ACM 虚拟串口收发链路验证�?|
| `tools/` | 主机�?Python 验证脚本�?|

## 调试方式

demo 不依赖固件侧 `printf`。板端状态通过 `demo_debug_instance` 或模�?telemetry 展开观察，主机侧脚本负责发送固�?packet、校验响应和制造坏 checksum 等场景�?

## 运行流程

1. 修改 `demo/app.cpp`，只启用目标 demo�?
2. 检�?`configs/params.json` �?UART、USBX、测试串口等配置�?
3. 重新构建并烧录固件�?
4. �?demo 需要主机脚本，进入 `demo/tools` 运行对应 Python 脚本�?
5. 在调试器中观�?debug state、计数和错误状态�?

## 编写�?demo

新增 demo 应保持范围小、目标明确：

- 只验证一个链路或模块组合�?
- 使用固定长度 packet 或明确的状态计数，便于主机侧复现�?
- 不把 demo helper 上移成框架抽象，除非已经有多�?demo 复用且职责稳定�?
- README 需要写明占用的外设、配置前提、运行命令和可观察状态�?
