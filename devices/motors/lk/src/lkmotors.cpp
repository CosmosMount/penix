#include "lkmotors.hpp"

#include "constants.hpp"
#include "constrain.hpp"

namespace motors
{

lkmotor::lkmotor(config cfg, float kt) : motor(cfg, kt)
{
    max_current = 2000;
}

void lkmotor::parse_feedback(const uint8_t* data, uint8_t len)
{
    if (data == nullptr || len < 8)
    {
        return;
    }
    mark_alive();
    update_sensor_data(data);
}

void lkmotor::set_output()
{
    if (control_mode == mode::relax)
    {
        cmd.current = 0;
        return;
    }

    if (control_mode == mode::torque)
    {
        cmd.current = static_cast<int16_t>(current_from_torque(cmd.torque));
    }
}

lk8016::lk8016(config cfg) : lkmotor(cfg, 0.0230399882f)
{
}

void lk8016::update_sensor_data(const uint8_t* buffer)
{
    raw.last_ecd = raw.ecd;
    raw.ecd = static_cast<uint16_t>((buffer[7] << 8) | buffer[6]);
    raw.speed_dps = static_cast<int16_t>((buffer[5] << 8) | buffer[4]);
    raw.current_raw = static_cast<int16_t>((buffer[3] << 8) | buffer[2]);
    fdb.temperature = static_cast<float>(buffer[1]);

    fdb.position = math::clamp_loop(
        static_cast<float>(raw.ecd - static_cast<uint16_t>(offset)) * raw_pos_to_rad, -math::pi,
        math::pi);
    fdb.velocity = static_cast<float>(raw.speed_dps) * raw_dps_to_rps * gear_ratio;
    fdb.current = static_cast<float>(raw.current_raw);
    fdb.torque = torque_from_current(fdb.current);
}

lk9025::lk9025(config cfg) : lkmotor(cfg, 0.00512f)
{
}

void lk9025::update_sensor_data(const uint8_t* buffer)
{
    raw.last_ecd = raw.ecd;
    raw.ecd = static_cast<uint16_t>((buffer[7] << 8) | buffer[6]);
    raw.speed_dps = static_cast<int16_t>((buffer[5] << 8) | buffer[4]);
    raw.current_raw = static_cast<int16_t>((buffer[3] << 8) | buffer[2]);
    fdb.temperature = static_cast<float>(buffer[1]);

    fdb.position = math::clamp_loop(
        static_cast<float>(raw.ecd - static_cast<uint16_t>(offset)) * raw_pos_to_rad, -math::pi,
        math::pi);
    fdb.velocity = static_cast<float>(raw.speed_dps) * raw_dps_to_rps;
    fdb.current = static_cast<float>(raw.current_raw);
    fdb.torque = torque_from_current(fdb.current);
}

} // namespace motors
