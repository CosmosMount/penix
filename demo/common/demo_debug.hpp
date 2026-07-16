#pragma once

#include "demo_protocol.hpp"

#include <cstdint>

namespace demo::debug
{

struct link_state
{
    bool started = false;
    bool ready = false;
    bool connected = false;
    std::uint8_t last_status = protocol::status_code(types::status::not_configured);
    std::uint32_t rx_count = 0;
    std::uint32_t tx_count = 0;
    std::uint32_t error_count = 0;
    std::uint32_t last_seq = 0;
    std::uint32_t last_counter = 0;
    float last_value = 0.0f;
    bool last_flag = false;
    bool bsp_read_busy = false;
    bool bsp_write_busy = false;
    std::uint32_t bsp_last_read_status = 0;
    std::uint32_t bsp_last_write_status = 0;
    std::uint16_t bsp_last_read_len = 0;
    std::uint16_t bsp_last_write_requested = 0;
    std::uint16_t bsp_last_write_actual = 0;
    std::uint16_t bsp_pending_write_len = 0;
    std::uint32_t bsp_read_count = 0;
    std::uint32_t bsp_write_count = 0;
    std::uint32_t bsp_error_count = 0;
    std::uint32_t bsp_tx_wake_count = 0;
    std::uint32_t bsp_fill_count = 0;
    bool tx_pending = false;
    std::uint32_t tx_pending_seq = 0;
    std::uint32_t tx_fill_hit_count = 0;
    std::uint32_t tx_fill_miss_count = 0;
    protocol::host_packet last_rx{};
    protocol::device_packet last_tx{};
};

struct unit_test_state
{
    bool started = false;
    bool passed = false;
    std::uint32_t total_count = 0;
    std::uint32_t passed_count = 0;
    std::uint32_t failed_count = 0;
    std::uint32_t failure_mask = 0;
    std::uint32_t last_step = 0;
    std::uint32_t stage_mask = 0;
    std::uint32_t observed_count = 0;
    float value_a = 0.0f;
    float value_b = 0.0f;
    float value_c = 0.0f;
};

struct imu_unit_state : unit_test_state
{
    bool ahrs_solved = false;
    float ahrs_dt_s = 0.0f;
    float ahrs_dt_min_s = 0.0f;
    float ahrs_dt_max_s = 0.0f;
    std::uint32_t ahrs_loop_runtime_us = 0;
    std::uint32_t ahrs_loop_runtime_max_us = 0;
    std::uint32_t ahrs_loop_runtime_overruns = 0;
    float ahrs_loop_runtime_avg_us = 0.0f;
    std::uint32_t monitor_runtime_us = 0;
    std::uint32_t monitor_runtime_max_us = 0;
    float monitor_runtime_avg_us = 0.0f;
    float quaternion[4] = {1.0f, 0.0f, 0.0f, 0.0f};
    float yaw = 0.0f;
    float pitch = 0.0f;
    float roll = 0.0f;
    float total_yaw = 0.0f;
};

struct debug_instance_type
{
    link_state usart{};
    link_state usb{};
    imu_unit_state imu_unit{};
    unit_test_state motor_unit{};
};

extern debug_instance_type& debug_instance;

void reset(link_state& state) noexcept;

} // namespace demo::debug

extern "C" demo::debug::debug_instance_type demo_debug_instance;
