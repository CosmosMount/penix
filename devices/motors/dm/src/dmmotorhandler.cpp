#include "dmmotorhandler.hpp"

namespace motors
{

dmmotorhandler& dmmotorhandler::instance()
{
    static dmmotorhandler handler;
    return handler;
}

dmmotorhandler::dmmotorhandler()
{
    for (auto& row : motor_list_)
    {
        for (auto& slot : row)
        {
            slot = nullptr;
        }
    }
}

bool dmmotorhandler::register_motor(motor* motor)
{
    auto* dm = static_cast<dmmotor*>(motor);
    if (dm == nullptr || dm->can_id() < dm_id_base || dm->can_id() >= dm_id_base + dm_max_motors)
    {
        return false;
    }

    if (!ensure_bus(dm->can_bus(), dm->can_type(), rx_entry, this))
    {
        return false;
    }

    const uint8_t bus = bus_index(dm->can_bus());
    const uint8_t slot = static_cast<uint8_t>(dm->can_id() - dm_id_base);
    motor_list_[bus][slot] = dm;

    track(dm);
    return true;
}

uint32_t dmmotorhandler::control_id(const dmmotor* motor) const
{
    if (motor == nullptr)
    {
        return 0;
    }

    const uint32_t frame_id = motor->can_id();
    switch (motor->control_mode)
    {
        case mode::pos_speed:
            return frame_id + 0x100;
        case mode::speed:
            return frame_id + 0x200;
        case mode::multi:
            return 0x300;
        default:
            return frame_id;
    }
}

void dmmotorhandler::send_control()
{
    for (uint8_t bus = 0; bus < bsp::can::bus_count; ++bus)
    {
        for (uint8_t i = 0; i < dm_max_motors; ++i)
        {
            dmmotor* m = motor_list_[bus][i];
            if (m != nullptr)
            {
                m->set_output();
            }
        }
    }
}

void dmmotorhandler::dispatch_rx(bsp::can::bus bus, const bsp::can::rx_frame& frame)
{
    if (frame.id < dm_master_id_base || frame.id >= dm_master_id_base + dm_max_motors)
    {
        return;
    }

    const int slot = static_cast<int>(frame.id - dm_master_id_base);
    if (slot < 0 || slot >= dm_max_motors)
    {
        return;
    }

    dmmotor* m = motor_list_[bus_index(bus)][static_cast<uint8_t>(slot)];
    if (m != nullptr)
    {
        m->parse_feedback(frame.data, frame.len);
    }
}

void dmmotorhandler::rx_entry(bsp::can::bus bus, const bsp::can::rx_frame& frame, void* user_data)
{
    if (user_data == nullptr)
    {
        return;
    }
    static_cast<dmmotorhandler*>(user_data)->dispatch_rx(bus, frame);
}

void dmmotorhandler::enable_block(dmmotor* motor)
{
    if (motor == nullptr || motor->control_mode == mode::multi)
    {
        return;
    }

    uint16_t timeout = 0;
    do
    {
        timeout++;
        if (timeout > 1000)
        {
            motor->enablefailed = true;
            break;
        }
        motor->transmit_frame(control_id(motor), dmmotor::enable_frame, 8);
        tx_thread_sleep(1);
    } while (motor->raw.err != dmmotor::error::enable);
}

void dmmotorhandler::enable(dmmotor* motor)
{
    if (motor == nullptr || motor->control_mode == mode::multi)
    {
        return;
    }
    motor->transmit_frame(control_id(motor), dmmotor::enable_frame, 8);
}

void dmmotorhandler::disable(dmmotor* motor)
{
    if (motor == nullptr || motor->control_mode == mode::multi)
    {
        return;
    }
    motor->transmit_frame(control_id(motor), dmmotor::disable_frame, 8);
}

void dmmotorhandler::save_zero(dmmotor* motor)
{
    if (motor == nullptr)
    {
        return;
    }
    motor->transmit_frame(control_id(motor), dmmotor::save_zero_frame, 8);
}

void dmmotorhandler::clear_error(dmmotor* motor)
{
    if (motor == nullptr)
    {
        return;
    }
    motor->transmit_frame(control_id(motor), dmmotor::clear_error_frame, 8);
}

} // namespace motors
