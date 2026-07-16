#pragma once

#include "bsp_can.hpp"
#include "motor.hpp"

#include <cstddef>
#include <cstdint>
#include <type_traits>

namespace motors
{

class motorhandler
{
public:
    virtual ~motorhandler() = default;

    virtual bool register_motor(motor* motor) = 0;
    virtual void send_control() = 0;

    template <typename Motor, typename = std::enable_if_t<is_motor_v<Motor>>>
    bool register_motor(Motor& motor)
    {
        return register_motor(static_cast<motors::motor*>(&motor));
    }

    bool alive_check();

protected:
    static uint8_t bus_index(bsp::can::bus bus);

    void track(motor* motor);

    bool ensure_bus(bsp::can::bus bus, bsp::can::bus_type type, bsp::can::rx_handler entry,
                    void* user_data);

    virtual void dispatch_rx(bsp::can::bus bus, const bsp::can::rx_frame& frame) = 0;

    bool rx_ready_[bsp::can::bus_count]{};

    static constexpr size_t max_tracked = bsp::can::bus_count * 8;
    motor* tracked_[max_tracked]{};
    size_t tracked_count_ = 0;
};

} // namespace motors
