#pragma once

#include <cstdint>

namespace demo::imu
{

// Plain, debugger-friendly mirror of the latest DMIMU message and the most
// useful service/device diagnostics. It intentionally contains no RTOS or
// message-system objects.
struct dmimu_debug_state
{
    bool compiled_enabled = false;
    bool service_initialized = false;
    bool subscriber_created = false;
    bool message_received = false;
    bool online = false;
    bool quaternion_valid = false;
    std::uint32_t received_count = 0U;
    std::uint32_t offline_message_count = 0U;
    std::uint32_t read_error_count = 0U;
    std::uint32_t sequence = 0U;
    std::uint32_t received_tick = 0U;
    std::uint32_t last_debug_tick = 0U;
    std::uint32_t message_age_ticks = 0U;
    float quaternion_norm = 0.0f;
    float quaternion[4] = {};
    float yaw = 0.0f;
    float pitch = 0.0f;
    float roll = 0.0f;
    float gyro[3] = {};
    float accel[3] = {};

    std::uint32_t processed_frame_count = 0U;
    std::uint32_t complete_snapshot_count = 0U;
    std::uint32_t publish_count = 0U;
    std::uint32_t publish_error_count = 0U;
    std::uint32_t request_error_count = 0U;
    std::uint32_t rx_queue_drop_count = 0U;
    std::uint32_t rx_invalid_length_count = 0U;
    std::uint32_t rx_invalid_frame_count = 0U;
    std::uint32_t device_offline_event_count = 0U;
    std::uint32_t device_reconnect_count = 0U;
};

void run() noexcept;

} // namespace demo::imu

// Add `dmimu_demo_debug` to the IDE Live Watch / Expressions window.
extern "C" demo::imu::dmimu_debug_state dmimu_demo_debug;
