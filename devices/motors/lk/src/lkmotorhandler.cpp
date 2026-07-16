#include "lkmotorhandler.hpp"

namespace motors
{

lkmotorhandler& lkmotorhandler::instance()
{
    static lkmotorhandler handler;
    return handler;
}

lkmotorhandler::lkmotorhandler()
{
    for (auto& row : motor_list_)
    {
        for (auto& slot : row)
        {
            slot = nullptr;
        }
    }
}

bool lkmotorhandler::register_motor(motor* motor)
{
    auto* lk = static_cast<lkmotor*>(motor);
    if (lk == nullptr || lk->can_id() < 0x141 || lk->can_id() > 0x144)
    {
        return false;
    }

    if (!ensure_bus(lk->can_bus(), lk->can_type(), rx_entry, this))
    {
        return false;
    }

    const uint8_t bus = bus_index(lk->can_bus());
    const uint8_t slot = static_cast<uint8_t>(lk->can_id() - 0x141);
    motor_list_[bus][slot] = lk;

    track(lk);
    return true;
}

void lkmotorhandler::send_control()
{
    for (uint8_t bus = 0; bus < bsp::can::bus_count; ++bus)
    {
        std::memset(send_data_[bus], 0, sizeof(send_data_[bus]));

        bool has_motor = false;
        for (uint8_t i = 0; i < lk_max_motors; ++i)
        {
            lkmotor* m = motor_list_[bus][i];
            if (m == nullptr)
            {
                continue;
            }

            has_motor = true;
            m->set_output();

            if (m->can_id() >= 0x141 && m->can_id() <= 0x144)
            {
                const int index = static_cast<int>((m->can_id() - 0x140) * 2);
                const int16_t current = m->cmd.current;
                send_data_[bus][index - 2] = static_cast<uint8_t>(current);
                send_data_[bus][index - 1] = static_cast<uint8_t>(current >> 8);
            }
        }

        if (has_motor)
        {
            bsp::can::transmit(static_cast<bsp::can::bus>(bus), lk_control_id, send_data_[bus], 8);
        }
    }
}

void lkmotorhandler::dispatch_rx(bsp::can::bus bus, const bsp::can::rx_frame& frame)
{
    if (frame.id < 0x140 || frame.id > 0x160)
    {
        return;
    }

    const int slot = static_cast<int>(frame.id - 0x141);
    if (slot < 0 || slot >= lk_max_motors)
    {
        return;
    }

    lkmotor* m = motor_list_[bus_index(bus)][static_cast<uint8_t>(slot)];
    if (m != nullptr)
    {
        m->parse_feedback(frame.data, frame.len);
    }
}

void lkmotorhandler::rx_entry(bsp::can::bus bus, const bsp::can::rx_frame& frame, void* user_data)
{
    if (user_data == nullptr)
    {
        return;
    }
    static_cast<lkmotorhandler*>(user_data)->dispatch_rx(bus, frame);
}

} // namespace motors
