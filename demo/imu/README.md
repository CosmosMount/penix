# IMU Demo �?DMIMU 上层接口说明

本文说明当前工程�?DMIMU 的配置、启动、数据链路、上层订阅规则和调试方法。内容对应当前代码实现，不描述尚未实现的本地滤波或统一�?IMU 选择器�?

## 当前 IMU 架构

工程�?BMI088 �?DMIMU 是两条独立服务链路：

```text
BMI088                                  DMIMU
SPI + 数据就绪中断                       FDCAN 接收中断
  �?                                     �?
imu::bmi088                            imu::dmimu
  �?本地主控完成姿态融�?                 �?解析设备已经融合的数�?
ahrs::service                         ahrs::dmimu_service
  �?                                     �?
ahrs::message                         ahrs::dmimu_message
  �?                                     �?
msg::subscriber ahrs_sub              msg::subscriber dmimu_sub
```

- 原有 BMI088 服务继续使用 `ahrs::service`、`ahrs::message` 和内部成�?`imu_`，命名及启动方式未改变�?
- DMIMU 使用独立�?`ahrs::dmimu_service`、`ahrs::dmimu_message` 和消�?topic�?
- 两个服务可以同时运行，消息不会互相覆盖，因为消息系统�?C++ 载荷类型区分 topic�?
- 当前 demo 会先启动 BMI088；只�?BMI088 初始化成功后才继续启�?DMIMU。两条生产线程独立，但启动阶段仍有这个顺序关系�?

## 编译开关与配置来源

### `configs/robot.json`

`robot.json` 只描�?DMIMU 是否存在以及如何连接�?

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

字段含义�?

| 字段 | 说明 |
| --- | --- |
| `enabled` | 是否编译并允许启�?DMIMU。只有显式设�?`true` 才启用�?|
| `can_bus` | DMIMU 所�?CAN 总线，必须存在于 `board.ioc`�?|
| `can_type` | 当前 DMIMU 只支�?`classic`�?|
| `can_id` | 主控�?DMIMU 发送命令时使用的设�?ID�?|
| `master_id` | DMIMU 向主控发送数据时使用�?CAN ID�?|

以下任一情况都会默认禁用 DMIMU�?

- `devices.dmimu` 整个对象不存在；
- `enabled` 字段不存在；
- `enabled` �?`false`�?

禁用时生�?`HAS_DMIMU=0`，DMIMU 设备源码会被 CMake 排除，demo �?AHRS 中的 DMIMU 代码也由 `#if HAS_DMIMU` 裁剪�?

启用时生成的连接配置为：

```cpp
robot::imu::dmimu  // 类型�?::imu::dmimu::transport_config
```

### `configs/params.json`

`params.json` �?`dmimu` 分组描述运行策略和服务线程参数：

```json
{
  "dmimu": {
    "communication_mode": "active",
    "offline_timeout_ticks": 100,
    "thread_priority": 3,
    "receive_wait_ticks": 1,
    "request_period_ticks": 1
  }
}
```

对应生成接口�?

```cpp
params::dmimu::mode
params::dmimu::offline_timeout_ticks
params::dmimu::thread_priority
params::dmimu::receive_wait_ticks
params::dmimu::request_period_ticks
```

规则如下�?

| 参数 | 默认�?| 规则 |
| --- | --- | --- |
| `communication_mode` | `active` | 只能�?`active` �?`request`�?|
| `offline_timeout_ticks` | `100` | 必须大于 0；按完整快照的最近接收时间判断掉线�?|
| `thread_priority` | `3` | `ahrs_dmimu` ThreadX 线程优先级�?|
| `receive_wait_ticks` | `1` | 服务线程等待内部接收队列的时间，必须大于 0，且不能为永久等待�?|
| `request_period_ticks` | `1` | 只在 `request` 模式使用；请求模式下必须大于 0�?|

`params.dmimu` 整组或其中某一字段缺失时，生成器会逐项使用上述默认值。`params.json` 不决�?DMIMU 是否参与编译，编译开关只�?`robot.json` 决定�?

## 主动模式部署规则

当前默认使用 `active` 模式。DMIMU 必须在固件运行前通过外部工具完成以下配置�?

1. 设置为主动发送模式；
2. 开启加速度数据�?
3. 开启角速度数据�?
4. 开启欧拉角数据�?
5. 开启四元数数据�?

本工程不会在初始化阶段修�?DMIMU 的通信模式、输出选择或其他持久参数。主动模式下服务线程不会发送四类数据请求，只消费设备主动上报的 CAN 帧�?

请求模式下，服务线程才会按照 `request_period_ticks` 依次请求�?

```cpp
request_accel();
request_gyro();
request_euler();
request_quaternion();
```

## 配置组装与服务启�?

连接配置、运行配置和服务配置�?`demo::imu::run()` 中组装：

```cpp
#if HAS_DMIMU
::imu::dmimu::config dmimu_cfg{};
dmimu_cfg.transport = robot::imu::dmimu;
dmimu_cfg.runtime.communication_mode =
    params::dmimu::mode == params::dmimu::communication_mode::active
        ? ::imu::dmimu::mode::active
        : ::imu::dmimu::mode::request;
dmimu_cfg.runtime.offline_timeout_ticks =
    params::dmimu::offline_timeout_ticks;

ahrs::dmimu_service_config service_cfg{};
service_cfg.thread_priority = params::dmimu::thread_priority;
service_cfg.receive_wait_ticks = params::dmimu::receive_wait_ticks;
service_cfg.request_period_ticks = params::dmimu::request_period_ticks;

const bool ok = ahrs::dmimu_service::instance().init(
    dmimu_cfg,
    service_cfg);
#endif
```

职责边界�?

| 配置类型 | 所属层 | 内容 |
| --- | --- | --- |
| `imu::dmimu::transport_config` | 设备�?| CAN 总线、类型和设备身份�?|
| `imu::dmimu::runtime_config` | 设备�?| 主动/请求模式和掉线阈值�?|
| `ahrs::dmimu_service_config` | 服务�?| 线程优先级、队列等待和请求周期�?|

设备层和 AHRS 服务层都不会直接读取 JSON 或包�?`robot_config.hpp`；启�?demo 层负责组装生成配置�?

## 数据接收链路

完整链路如下�?

```text
HAL FDCAN 收到�?
  �?
bsp::can::receive()
  �?向该总线所有回调分�?
imu::dmimu::rx_entry()
  �?检�?CAN、master_id �?8 字节长度
DMIMU 内部 ThreadX 队列
  �?�?ahrs_dmimu 服务线程取出
imu::dmimu::process_next()/process_pending()
  �?设备层完成浮点解�?
加速度 + 角速度 + 欧拉�?+ 四元�?
  �?四类 valid bit 全部齐全
imu::dmimu::snapshot
  �?
ahrs::dmimu_service::publish_snapshot()
  �?
ahrs::dmimu_message topic
  �?
上层 subscriber
```

中断上下文只负责过滤和复制原�?8 字节帧，不进行浮点解析或消息发布。协议解析由设备类实现，但实际运行在 `ahrs_dmimu` 服务线程上下文中�?

## 上层消息接口

上层只需要订�?`ahrs::dmimu_message`，不应直接处�?CAN 帧或调用设备�?`process_*()` 接口�?

```cpp
#if HAS_DMIMU
msg::subscriber dmimu_sub = msg::subscribe<ahrs::dmimu_message>();

ahrs::dmimu_message data{};
if (dmimu_sub.valid() && msg::available(dmimu_sub))
{
    if (msg::read(dmimu_sub, data) == types::status::ok)
    {
        if (data.online)
        {
            // 使用本次 DMIMU 姿态和惯性数据�?
        }
        else
        {
            // 收到掉线清零消息�?
        }
    }
}
#endif
```

消息定义包含�?

| 字段 | 单位/语义 |
| --- | --- |
| `quaternion[4]` | 顺序�?W、X、Y、Z。在线正常消息应接近单位四元数�?|
| `yaw` | rad；服务层将设备的 `yaw_deg` 转换为弧度后发布�?|
| `pitch` | rad；服务层将设备的 `pitch_deg` 转换为弧度后发布�?|
| `roll` | rad；服务层将设备的 `roll_deg` 转换为弧度后发布�?|
| `total_yaw` | rad；当前恒�?0，DMIMU 未提供多�?yaw�?|
| `gyro_r/p/y` | rad/s�?|
| `accel[3]` | m/s²�?|
| `sequence` | 每形成一个完整四帧快照加 1。掉线清零消息为 0�?|
| `received_tick` | 完整快照形成时的 ThreadX tick。掉线清零消息为 0�?|
| `online` | `true` 表示正常完整快照；`false` 表示掉线清零消息�?|

重要规则：DMIMU 设备协议�?`imu::dmimu::snapshot` 内部仍使用度制字�?`*_deg`；`dmimu_service` 在消息发布边界转换为弧度。因此上层收到的 `ahrs::dmimu_message` �?BMI088 `ahrs::message` 的欧拉角单位一致，均为弧度�?

## Topic 与读取规�?

消息系统按消息类型保存独�?topic�?

```cpp
ahrs::message        // BMI088 本地融合结果
ahrs::dmimu_message  // DMIMU 设备直出结果
```

每种 topic 只保留最新一次发布的数据，每个订阅者拥有独立的 `pending` 标记。因此：

- 多个订阅者互不影响；
- `msg::read()` 成功后只清除当前订阅者的 pending 状态；
- 上层读取速度低于发布速度时，中间消息会被新消息覆盖；
- 它是“最新状态”接口，不是无损采样队列�?
- 推荐先调�?`msg::available()`，再调用 `msg::read()`�?

## 在线、掉线与清零规则

DMIMU 只有在加速度、角速度、欧拉角和四元数四类帧全部齐全并提交完整快照后才进入在线状态�?

在线判断使用最近完整快照时间，而不是最近任�?CAN 帧时间：

```text
当前 tick - last_snapshot_tick <= offline_timeout_ticks
```

当状态从在线变为离线时：

1. 设备层清空工作快照、完成快照和 pending valid mask�?
2. 服务层发布一次值初始化�?`ahrs::dmimu_message`�?
3. 四元数、欧拉角、角速度、加速度、序号和时间戳全部为 0�?
4. `online=false`�?
5. 离线持续期间不会反复发布清零消息�?

上层必须优先检�?`online`，不能把全零四元数当作有效姿态�?

## Demo 调试方法

当前 demo 复用 `imu_unit_mon` 线程订阅 BMI088 �?DMIMU 两个 topic，不�?DMIMU 新增监视线程�?

可在调试�?Live Watch/Expressions 中添加：

```text
dmimu_demo_debug
dmimu_yaw_debug
dmimu_debug_telemetry
```

其中 `dmimu_demo_debug` 是面�?demo 的主要调试镜像，包含�?

- `compiled_enabled`、`service_initialized`、`subscriber_created`�?
- `message_received`、`online`、`quaternion_valid`�?
- `yaw`、`pitch`、`roll`、`quaternion`�?
- `gyro`、`accel`�?
- `sequence`、`received_tick`、`message_age_ticks`�?
- 收帧、完整快照、发布、队列丢弃、非法帧、掉线和重连计数�?

`dmimu_yaw_debug` 是便于快速观察的单独 yaw 全局变量，直接复制上层消息字段，单位为弧度�?

`dmimu_debug_telemetry` 是服务层诊断对象，适合排查服务是否创建、线程是否启动、是否收到完整快照以及设备队列状态�?

## 上层使用约束

1. 业务层只订阅 `ahrs::dmimu_message`，不要注册第二套 CAN 回调�?
2. 不要在业务线程调�?`process_next()`、`process_pending()`、`take_snapshot()` �?`audit_online()`；这些接口由 `dmimu_service` 线程拥有�?
3. 正常控制逻辑必须先检�?`message.online`�?
4. �?rad 解释 DMIMU 欧拉角，�?rad/s 解释角速度，按 m/s² 解释加速度�?
5. 不要使用 DMIMU �?`total_yaw`，当前它固定�?0�?
6. 不要假设每个设备发送周期都能被上层读到；topic 只保留最新值�?
7. 发送标定、改 ID、保存参数等设备命令会改变外部设备状态，不应由普通上层数据消费者随意调用�?
8. 主动模式运行前必须确认外部配置已开启四类数据发送�?

## 当前已知限制

- 四类帧目前通过 valid bit 组合，没有设备周期序号。CAN 丢失某一类帧时，存在相邻发送周期数据被组合成一个快照的风险�?
- 设备层只保存一个完成快照；服务一次排空多周期积压帧时，只能取到最后完成的快照�?
- BMI088 初始化失败会使当�?`demo::imu::run()` 提前返回，从而不启动 DMIMU；生产线程本身独立，但启动流程尚未完全解耦�?
- BMI088 �?DMIMU 的欧拉角单位已经统一为弧度，但消息类型和有效性字段仍不统一，目前不支持业务代码无感切换数据源�?
- `dmimu_service::dmimu()` 当前返回可修改的设备引用；普通上层不应借此绕过服务线程操作接收状态�?
- 当前不对 DMIMU 数据执行本地主控滤波或二次姿态融合�?

## 相关代码入口

| 内容 | 文件 |
| --- | --- |
| DMIMU 设备接口和数据结�?| `devices/imu/dmimu/include/dmimu.hpp` |
| DMIMU 协议解析和在线审�?| `devices/imu/dmimu/src/dmimu.cpp` |
| DMIMU 服务、消息和诊断类型 | `modules/ahrs/include/ahrs.hpp` |
| DMIMU 服务线程与消息发�?| `modules/ahrs/src/ahrs.cpp` |
| 配置生成规则 | `configs/cmake/generate_config.cmake` |
| Demo 启动、订阅和调试镜像 | `demo/imu/imu_demo.cpp`、`imu_demo.hpp` |
