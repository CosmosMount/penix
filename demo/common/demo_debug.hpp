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

struct debug_instance_type
{
    link_state usart{};
    link_state usb{};
};

extern debug_instance_type& debug_instance;

void reset(link_state& state) noexcept;

} // namespace demo::debug

extern "C" demo::debug::debug_instance_type demo_debug_instance;
