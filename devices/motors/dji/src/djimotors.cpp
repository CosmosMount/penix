#include "djimotors.hpp"

#include "constants.hpp"

namespace motors
{

djimotor::djimotor(config cfg, float kt, float pos_to_rad, float rpm_to_rad_s,
                   bool multi_turn_feedback)
    : motor(cfg, kt),
      pos_to_rad_(pos_to_rad),
      rpm_to_rad_s_(rpm_to_rad_s),
      multi_turn_feedback_(multi_turn_feedback)
{
}

float djimotor::rpm_to_rad_s(int16_t rpm) const
{
    return static_cast<float>(rpm) * rpm_to_rad_s_;
}

float djimotor::ecd_to_rad(const rawfeedback& raw_fb) const
{
    return static_cast<float>(raw_fb.ecd + raw_fb.ecd_cnt * 8192 - raw_fb.ecd_offset) * pos_to_rad_;
}

void djimotor::update_sensor_data(const uint8_t* can_data)
{
    mark_alive();

    raw.last_ecd = raw.ecd;
    raw.ecd = static_cast<uint16_t>((can_data[0] << 8) | can_data[1]);
    raw.speed_rpm = static_cast<int16_t>((can_data[2] << 8) | can_data[3]);
    fdb.current = static_cast<float>(static_cast<int16_t>((can_data[4] << 8) | can_data[5]));
    fdb.temperature = static_cast<float>(can_data[6]);

    if (!multi_turn_feedback_)
    {
        fdb.velocity = rpm_to_rad_s(raw.speed_rpm);
        fdb.position = static_cast<float>(raw.ecd) * pos_to_rad_ - math::pi;
        fdb.torque = 0.0f;
        return;
    }

    if (raw.ecd - raw.last_ecd > 4096)
    {
        raw.ecd_cnt--;
    }
    else if (raw.ecd - raw.last_ecd < -4096)
    {
        raw.ecd_cnt++;
    }

    fdb.velocity = rpm_to_rad_s(raw.speed_rpm);
    fdb.position = ecd_to_rad(raw);
    fdb.torque = 0.0f;
}

void djimotor::reset_position()
{
    raw.ecd_offset = raw.ecd;
    raw.ecd_cnt = 0;
    raw.total_cnt = 0;
    fdb.position = 0.0f;
}

void djimotor::parse_feedback(const uint8_t* data, uint8_t len)
{
    if (data == nullptr || len < 7)
    {
        return;
    }
    update_sensor_data(data);
}

void djimotor::set_output()
{
    if (control_mode == mode::relax)
    {
        cmd.current = 0;
    }
}

m2006::m2006(config cfg) : djimotor(cfg, 0.0f, 0.00002130788978f, 0.002908882087f, true)
{
}

m3508::m3508(config cfg)
    : djimotor(cfg, 1.0f / 1400.0f, 0.00003994074176f, 0.005453242609f, true)
{
}

gm6020::gm6020(config cfg)
    : djimotor(cfg, 0.02f, 0.0007669903939f, 0.1047197551196f, false)
{
}

xroll::xroll(config cfg)
    : djimotor(cfg, 0.0f, 0.000048658315f, 0.006642670920f, true)
{
}

} // namespace motors
