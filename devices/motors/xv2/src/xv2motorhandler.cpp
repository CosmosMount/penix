#include "xv2motorhandler.hpp"

namespace motors
{

xv2motorhandler& xv2motorhandler::instance()
{
    static xv2motorhandler handler;
    return handler;
}

xv2motorhandler::xv2motorhandler()
{
    for (auto& row : motor_list_)
    {
        for (auto& slot : row)
        {
            slot = nullptr;
        }
    }
}

bool xv2motorhandler::register_motor(motor* motor)
{
    auto* xv2 = static_cast<xv2motor*>(motor);
    if (xv2 == nullptr)
    {
        return false;
    }

    if (!ensure_bus(xv2->can_bus(), xv2->can_type(), rx_entry, this))
    {
        return false;
    }

    const uint8_t bus = bus_index(xv2->can_bus());
    motor_list_[bus][xv2->address()] = xv2;

    track(xv2);
    return true;
}

void xv2motorhandler::send_control()
{
    for (uint8_t bus = 0; bus < bsp::can::bus_count; ++bus)
    {
        for (xv2motor* m : motor_list_[bus])
        {
            if (m != nullptr)
            {
                m->set_output();
            }
        }
    }
}

void xv2motorhandler::dispatch_rx(bsp::can::bus bus, const bsp::can::rx_frame& frame)
{
    if (frame.len < 1)
    {
        return;
    }

    xv2motor* m = motor_list_[bus_index(bus)][frame.data[0]];
    if (m != nullptr)
    {
        m->parse_feedback(frame.data, frame.len);
    }
}

void xv2motorhandler::rx_entry(bsp::can::bus bus, const bsp::can::rx_frame& frame, void* user_data)
{
    if (user_data == nullptr)
    {
        return;
    }
    static_cast<xv2motorhandler*>(user_data)->dispatch_rx(bus, frame);
}

} // namespace motors
