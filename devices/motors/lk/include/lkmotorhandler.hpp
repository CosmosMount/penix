#pragma once

#include "lkmotors.hpp"
#include "motorhandler.hpp"

#include <cstdint>
#include <cstring>

namespace motors
{

constexpr int lk_max_motors = 4;
constexpr uint32_t lk_control_id = 0x280;

class lkmotorhandler : public motorhandler
{
public:
    using motorhandler::register_motor;

    static lkmotorhandler& instance();

    bool register_motor(motor* motor) override;
    void send_control() override;

private:
    lkmotorhandler();

    static void rx_entry(bsp::can::bus bus, const bsp::can::rx_frame& frame, void* user_data);

    void dispatch_rx(bsp::can::bus bus, const bsp::can::rx_frame& frame) override;

    lkmotor* motor_list_[bsp::can::bus_count][lk_max_motors]{};
    uint8_t send_data_[bsp::can::bus_count][8]{};
};

} // namespace motors
