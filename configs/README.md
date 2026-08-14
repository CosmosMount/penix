# 配置参数传入说明

`embedded_framework` 的配置入口位于本目录，CMake 配置阶段会读�?`params.json`、`robot.json` �?`boards/stm32h723/board.ioc`，生�?`generated/config.hpp` �?`generated/robot_config.hpp`。修�?JSON 后重新运�?CMake configure �?build，即可刷新生成头文件�?

生成脚本由顶�?`CMakeLists.txt` 传入以下 CMake 变量：`IOC` 指向 `boards/stm32h723/board.ioc`，`PARAMS` 指向 `configs/params.json`，`ROBOT_CONFIG` 指向 `configs/robot.json`，`OUT_DIR` 指向 `configs/generated`。通常不需要手动传这些变量�?

## params.json

`params.json` 描述构建开关、外设绑定和任务参数�?

| 路径 | 类型 | 默认�?| 说明 |
| --- | --- | --- | --- |
| `build.usbx` | bool | `false` | 是否编译 USBX/USB CDC 相关 BSP 与功能�?|
| `build.motors.dji` | bool | `true` | 是否启用 DJI 电机相关构建开关�?|
| `build.motors.dm` | bool | `true` | 是否启用达妙电机相关构建开关�?|
| `build.motors.lk` | bool | `false` | 是否启用 LK 电机相关构建开关�?|
| `bindings.remoter_uart` | string | `uart5` | 遥控器串口，例如 `uart5` �?`usart10`；需要与 `board.ioc` 中存在且�?RX DMA �?UART 名称一致�?|
| `bindings.referee_uart` | string | `usart1` | 裁判系统串口，需要与 `board.ioc` 中存在的 UART 名称一致�?|
| `bindings.gpio_inputs.<name>` | object | �?| 可�?GPIO 输入绑定，填�?`pin` �?`active_level`�?|
| `bindings.gpio_outputs.<name>` | object | �?| 可�?GPIO 输出绑定，填�?`pin` �?`active_level`�?|
| `bindings.pwm_channels.<name>` | object | �?| 可�?PWM 语义绑定，填�?`timer` �?`channel`�?|
| `bindings.adc_channels.<name>` | object | �?| 可�?ADC 语义绑定，填�?`adc` �?`channel`�?|
| `can.<fdcan>.id_type` | string | IOC 推导 | 指定某路 CAN 接收过滤 ID 类型，可�?`standard` �?`extended`。例�?`can.fdcan1.id_type`。手动配置优先于 IOC 推导�?|
| `ahrs.imu_offset_x` | number | `0.0` | IMU X 轴安装偏置�?|
| `ahrs.imu_thread_priority` | number | `3` | AHRS/IMU 线程优先级�?|
| `ahrs.temp_thread_priority` | number | `4` | IMU 温控线程优先级�?|
| `ahrs.target_temp` | number | `45.0` | IMU 目标温度�?|
| `dmimu.communication_mode` | string | `active` | DMIMU 运行模式：`active` 只接收外部预配置的四类主动数据；`request` 周期请求四类数据�?|
| `dmimu.offline_timeout_ticks` | number | `100` | 超过该时间没有形成完整四帧快照时判定 DMIMU 掉线�?|
| `dmimu.thread_priority` | number | `3` | DMIMU 服务线程优先级�?|
| `dmimu.receive_wait_ticks` | number | `1` | DMIMU 服务线程等待接收队列�?tick 数，必须大于 0�?|
| `dmimu.request_period_ticks` | number | `1` | 请求模式的请求周期；仅在 `request` 模式下要求大�?0�?|
| `remoter.source` | string | �?| 遥控器来源，可�?`dr16`、`vt03` �?`ps2`�?|
| `remoter.thread_priority` | number | `2` | 遥控器线程优先级�?|
| `remoter.rx_timeout_ticks` | number | `100` | 遥控器接收超�?tick 数�?|
| `remoter.ps2_offline_timeout_ticks` | number | `600` | 超过该时间未收到 PS2 正常帧或 `0xAB` 时，判定接收器离线�?|
| `remoter.ps2_frame_timeout_ticks` | number | `20` | PS2 正常帧接收到一半时的重同步超时�?|
| `remoter.ps2_deadzone` | number | `0.08` | PS2 摇杆归一化后的中心死区，范围�?`[0, 1)`�?|
| `referee.thread_priority` | number | `8` | 裁判系统线程优先级�?|
| `test.thread_priority` | number | `10` | demo/test 线程优先级�?|
| `test.report_uart` | string | `uart7` | 测试报告串口，不能与当前遥控�?UART 冲突�?|
| `test.auto_run_on_boot` | bool | `true` | 是否上电自动运行测试/demo�?|
| `usb.read_thread_priority` | number | `5` | USB CDC 读线程优先级�?|
| `usb.write_thread_priority` | number | `5` | USB CDC 写线程优先级�?|
| `usb.period_ticks` | number | `2` | USB CDC 周期 tick 数�?|

### GPIO、PWM �?ADC 最小用�?

先在 `boards/stm32h723/board.ioc` 中配置对�?GPIO 模式、PWM 通道或单次常�?ADC 通道。只有应用需要语义名称时，才�?`bindings` 中添加相应条目；未使用的分组可以省略�?

```json
{
  "bindings": {
    "gpio_inputs": {
      "limit_switch": { "pin": "pe10", "active_level": "low" }
    },
    "gpio_outputs": {
      "status_output": { "pin": "pc13", "active_level": "high" }
    },
    "pwm_channels": {
      "heater": { "timer": "tim3", "channel": 4 }
    },
    "adc_channels": {
      "supply_voltage": { "adc": "adc1", "channel": 4 }
    }
  }
}
```

重新运行 CMake 配置后，可以使用 `app::gpio::limit_switch`、`app::gpio::status_output`、`app::pwm::heater` �?`app::adc::supply_voltage` 调用对应 BSP 接口。名称必须是合法�?C++ 标识符，硬件资源必须�?IOC 配置一致�?

DR16 的最小配置如下：

```json
{
  "bindings": {
    "remoter_uart": "uart5"
  },
  "remoter": {
    "source": "dr16"
  }
}
```

选择 PS2 时的最小配置如下：

```json
{
  "bindings": {
    "remoter_uart": "usart10"
  },
  "remoter": {
    "source": "ps2"
  }
}
```

`bindings.remoter_uart` 负责绑定实际 UART，生成配置会把它同时导出�?`app::uart::ps2`。该 UART 必须�?`board.ioc` 中启�?RX DMA 并完成对�?RX/TX 引脚配置；PS2 驱动初始化时会把绑定端口切换�?`9600 baud, 8 data bits, no parity, 1 stop bit (8N1)`�?

PS2 UART 协议和按键位序以 [YFROBOT PS2 UART 说明书](https://pjfcckenlt.feishu.cn/wiki/Xnl8wHa3liFP9zkmWaXcXsWsnqc) 为准。统一遥控器状态通过 `ps2_link` 区分 `connected`、`remote_disconnected`（收到接收器�?200 ms 发送的 `0xAB`）和 `receiver_offline`（正常帧�?`0xAB` 均超时）三种状态；`ps2_buttons` 保留手柄自己�?16 位按键位图，不映射为键盘按键�?

| �?| `ps2_button` | �?| `ps2_button` |
| --- | --- | --- | --- |
| 15 | `square` | 7 | `left` |
| 14 | `cross` | 6 | `down` |
| 13 | `circle` | 5 | `right` |
| 12 | `triangle` | 4 | `up` |
| 11 | `r1` | 3 | `start` |
| 10 | `l1` | 2 | `r3` |
| 9 | `r2` | 1 | `l3` |
| 8 | `l2` | 0 | `select` |

可使�?`remoter::is_held(state.ps2_buttons, remoter::ps2_button::cross)` 判断指定按键是否按下�?

上层处理 `ps2_pressed` / `ps2_released` 时应同时记录 `ps2_event_count`�?
仅在计数变化时处理一次，避免同一帧的边缘被重复执行�?

### PS2 Live Watch 调试字段

配置生成器会根据 `remoter.source` 生成 `ENABLE_PS2`。只有当
`remoter.source` �?`ps2`、即 `ENABLE_PS2=1` 时，
`demo_debug_instance.remoter_unit` 才会包含 `ps2_` 前缀的调试字段，
选择 `dr16` �?`vt03` 时，这些字段不会进入调试结构体，也不会占�?
`demo_debug_instance` 的内存。该条件开关只裁剪 Demo Debug 字段�?
不改变统一 remoter demo 的初始化和监视流程�?

切换 `remoter.source` 后需要重新运�?CMake configure/build，并�?Cortex-Debug
重新加载最�?ELF。非 PS2 固件�?Live Watch 找不�?`ps2_` 字段属于正常现象�?

注意：`ahrs`、`referee`、`test`、`usb` 这些分组在生成脚本中按“整组缺省”补默认值。如果某个分组里只填写一部分字段，未填写的字段不会生成，使用时应保持同组字段完整。`dmimu` �?`remoter` 分组的字段支持逐项缺省�?

CAN �?`id_type` 只表示标准帧 ID 或扩展帧 ID，不表示 CAN Classic �?CAN FD。CAN Classic/FD 仍由 `board.ioc` �?`FDCANx.FrameFormat` 推导；`can.<fdcan>.id_type` 只控制生成到 `config::can::filter_id_types` 的标�?扩展过滤类型�?

## robot.json

`robot.json` 描述机器人设备树，包含可�?IMU 与电机配置�?

### `devices.dmimu`

`devices.dmimu` 整个对象缺失时，�?`enabled` 缺失/�?`false` 时，生成器默认不使用 DMIMU：生�?`HAS_DMIMU=0`，并�?CMake 源文件和头文件列表中排除 `devices/imu/dmimu`。只有显式配�?`enabled: true` 才会生成并启�?DMIMU 服务�?

| 字段 | 类型 | 必填 | 默认�?| 说明 |
| --- | --- | --- | --- | --- |
| `enabled` | bool | �?| `false` | 是否编译并启�?DMIMU�?|
| `can_bus` | string | 启用时是 | �?| CAN 外设，例�?`fdcan3`，必须存在于 `board.ioc`�?|
| `can_type` | string | 启用时是 | �?| DMIMU 当前只接�?`classic`，并会校�?IOC 中该总线同样�?Classic CAN�?|
| `can_id` | string/number | 启用时是 | �?| �?DMIMU 发送命令使用的 ID，范�?`0x00..0xFF`�?|
| `master_id` | string/number | 启用时是 | �?| DMIMU 返回数据使用�?ID，范�?`0x00..0xFF`�?|

示例�?

```json
{
  "devices": {
    "dmimu": {
      "enabled": true,
      "can_bus": "fdcan3",
      "can_type": "classic",
      "can_id": "0x04",
      "master_id": "0x04"
    }
  }
}
```

生成结果�?`config::feature::has_dmimu`、`HAS_DMIMU` 和纯连接配置 `robot::imu::dmimu`。运行模式及线程参数�?`params::dmimu` 提供，`demo::imu::run()` 只在 `HAS_DMIMU=1` 时组装两类配置并调用 `ahrs::dmimu_service::init()`；没有该字段的旧配置不会引用 DMIMU 代码�?

主动模式是部署前置条件：DMIMU 必须通过外部工具预先设置为主动发送加速度、角速度、欧拉角和四元数。固件不会修改其通信模式、输出选择或持久参数�?

### `devices.motors.dm`

| 路径 | 类型 | 默认�?| 说明 |
| --- | --- | --- | --- |
| `id_base` | string/number | `0x01` | 达妙电机反馈表的电机 ID 起始值�?|
| `master_id_base` | string/number | `0x05` | 达妙反馈�?master ID 起始值�?|
| `max_motors` | number | `4` | 单个 CAN 总线登记的达妙电机最大数量�?|

### `devices.motors.list[]`

每个电机对象支持以下字段�?

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `name` | string | �?| 生成�?`robot::motors` 命名空间中的 C++ 标识符�?|
| `model` | string | �?| 电机型号。配置生成器支持 `dji_m2006`、`dji_m3508`、`dji_gm6020`、`dji_xroll`、`dm_dm4310`、`dm_dm8009p`、`lk_lk8016`、`lk_lk9025`�?|
| `can_bus` | string | �?| CAN 外设名称，例�?`fdcan1`、`fdcan2`，必须存在于 `board.ioc`�?|
| `can_type` | string | �?| CAN 帧类型：`classic` �?`fd`�?|
| `can_id` | string/number | �?| 电机基础 CAN ID，建议十六进制字符串，如 `0x01`�?|
| `control_mode` | string | �?| 电机初始控制模式，默�?`relax`；可�?`relax`、`torque`、`mit`、`pos_speed`、`speed`、`multi`。`velocity` 可作�?`speed` 的别名，`position_speed` 可作�?`pos_speed` 的别名�?|

示例�?

```json
{
  "name": "motor2",
  "model": "dm_dm4310",
  "can_bus": "fdcan1",
  "can_type": "fd",
  "can_id": "0x01",
  "control_mode": "mit"
}
```

`control_mode` 会写入生成的 `motors::config`，电机对象构造时即设置到 `control_mode`。对于达妙电机，enable/disable/save-zero/clear-error 的控制帧 ID 会根据该模式选择基础 ID、`+0x100`、`+0x200` �?`0x300`，因此需要在 enable 前通过配置确定�?

`model` 会生�?`<name>_model` 常量。例�?`name` �?`motor2` 时会生成 `robot::motors::motor2_model`。demo 可以用这个常量在编译期选择具体 C++ 电机类�?
