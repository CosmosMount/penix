#pragma once

#include "djimotors.hpp"
#include "motorhandler.hpp"

#include <cstdint>
#include <cstring>

namespace motors
{

constexpr uint32_t dji_control_id_low = 0x200;
constexpr uint32_t dji_control_id_high = 0x1FF;

class djimotorhandler : public motorhandler
{
public:
    using motorhandler::register_motor;

    static djimotorhandler& instance();

    bool register_motor(motor* motor) override;
    void send_control() override;

    void blocked_check();

private:
    djimotorhandler();

    static void rx_entry(bsp::can::bus bus, const bsp::can::rx_frame& frame, void* user_data);

    void dispatch_rx(bsp::can::bus bus, const bsp::can::rx_frame& frame) override;

    djimotor* motor_list_[bsp::can::bus_count][8]{};
    uint8_t send_data_low_[bsp::can::bus_count][8]{};
    uint8_t send_data_high_[bsp::can::bus_count][8]{};
    bool use_low_frame_[bsp::can::bus_count]{};
    bool use_high_frame_[bsp::can::bus_count]{};
};

} // namespace motors
