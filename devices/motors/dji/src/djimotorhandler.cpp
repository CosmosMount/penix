#include "djimotorhandler.hpp"

namespace motors
{

djimotorhandler& djimotorhandler::instance()
{
    static djimotorhandler handler;
    return handler;
}

djimotorhandler::djimotorhandler()
{
    for (auto& row : motor_list_)
    {
        for (auto& slot : row)
        {
            slot = nullptr;
        }
    }
}

bool djimotorhandler::register_motor(motor* motor)
{
    auto* dji = static_cast<djimotor*>(motor);
    if (dji == nullptr || dji->can_id() < 0x201 || dji->can_id() > 0x208)
    {
        return false;
    }

    if (!ensure_bus(dji->can_bus(), dji->can_type(), rx_entry, this))
    {
        return false;
    }

    const uint8_t bus = bus_index(dji->can_bus());
    const uint8_t slot = static_cast<uint8_t>(dji->can_id() - 0x201);
    motor_list_[bus][slot] = dji;

    if (dji->can_id() <= 0x204)
    {
        use_low_frame_[bus] = true;
    }
    else
    {
        use_high_frame_[bus] = true;
    }

    track(dji);
    return true;
}

void djimotorhandler::send_control()
{
    for (uint8_t bus = 0; bus < bsp::can::bus_count; ++bus)
    {
        std::memset(send_data_low_[bus], 0, sizeof(send_data_low_[bus]));
        std::memset(send_data_high_[bus], 0, sizeof(send_data_high_[bus]));

        for (uint8_t i = 0; i < 8; ++i)
        {
            djimotor* m = motor_list_[bus][i];
            if (m == nullptr)
            {
                continue;
            }

            m->set_output();

            const int16_t current = m->cmd.current;
            if (m->can_id() >= 0x201 && m->can_id() <= 0x204)
            {
                const int index = static_cast<int>((m->can_id() - 0x200) * 2);
                send_data_low_[bus][index - 2] = static_cast<uint8_t>(current >> 8);
                send_data_low_[bus][index - 1] = static_cast<uint8_t>(current);
            }
            if (m->can_id() >= 0x205 && m->can_id() <= 0x208)
            {
                const int index = static_cast<int>((m->can_id() - 0x204) * 2);
                send_data_high_[bus][index - 2] = static_cast<uint8_t>(current >> 8);
                send_data_high_[bus][index - 1] = static_cast<uint8_t>(current);
            }
        }

        const auto can_bus = static_cast<bsp::can::bus>(bus);
        if (use_low_frame_[bus])
        {
            bsp::can::transmit(can_bus, dji_control_id_low, send_data_low_[bus], 8);
        }
        if (use_high_frame_[bus])
        {
            bsp::can::transmit(can_bus, dji_control_id_high, send_data_high_[bus], 8);
        }
    }
}

void djimotorhandler::blocked_check()
{
    for (auto& row : motor_list_)
    {
        for (djimotor* m : row)
        {
            if (m != nullptr)
            {
                (void)m;
            }
        }
    }
}

void djimotorhandler::dispatch_rx(bsp::can::bus bus, const bsp::can::rx_frame& frame)
{
    if (frame.id < 0x201 || frame.id > 0x208)
    {
        return;
    }

    const int slot = static_cast<int>(frame.id - 0x201);
    if (slot < 0 || slot >= 8)
    {
        return;
    }

    djimotor* m = motor_list_[bus_index(bus)][static_cast<uint8_t>(slot)];
    if (m != nullptr)
    {
        m->parse_feedback(frame.data, frame.len);
    }
}

void djimotorhandler::rx_entry(bsp::can::bus bus, const bsp::can::rx_frame& frame, void* user_data)
{
    if (user_data == nullptr)
    {
        return;
    }
    static_cast<djimotorhandler*>(user_data)->dispatch_rx(bus, frame);
}

} // namespace motors
