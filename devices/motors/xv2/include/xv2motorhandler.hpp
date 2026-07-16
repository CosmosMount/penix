#pragma once

#include "motorhandler.hpp"
#include "xv2motors.hpp"

#include <cstdint>

namespace motors
{

class xv2motorhandler : public motorhandler
{
public:
    using motorhandler::register_motor;

    static xv2motorhandler& instance();

    bool register_motor(motor* motor) override;
    void send_control() override;

private:
    xv2motorhandler();

    static void rx_entry(bsp::can::bus bus, const bsp::can::rx_frame& frame, void* user_data);

    void dispatch_rx(bsp::can::bus bus, const bsp::can::rx_frame& frame) override;

    xv2motor* motor_list_[bsp::can::bus_count][256]{};
};

} // namespace motors
