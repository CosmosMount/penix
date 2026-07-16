#include "dmmotors.hpp"

namespace motors
{

void dmmotor::parse_feedback(const uint8_t* data, uint8_t len)
{
    if (data == nullptr || len < 8)
    {
        return;
    }
    receive_data(data);
}

void dmmotor::transmit_frame(uint32_t frame_id, const uint8_t* data, uint16_t len)
{
    last_tx_id = frame_id;
    bsp::can::transmit(can_bus(), frame_id, data, len);
}

void dmmotor::receive_data(const uint8_t* buffer)
{
    const limits lim = motion_limits();

    mark_alive();
    raw.first_byte = buffer[0];
    raw.id = buffer[0] & 0x0F;
    raw.err = static_cast<error>(buffer[0] >> 4);
    fdb.error_code = static_cast<uint8_t>(raw.err);

    const uint16_t p_int = static_cast<uint16_t>((buffer[1] << 8) | buffer[2]);
    const uint16_t v_int = static_cast<uint16_t>((buffer[3] << 4) | (buffer[4] >> 4));
    const uint16_t t_int = static_cast<uint16_t>(((buffer[4] & 0x0F) << 8) | buffer[5]);

    fdb.position = math::clamp_loop(
        math::uint_to_float(static_cast<int>(p_int), lim.position_min, lim.position_max, 16),
        -math::pi, math::pi);
    fdb.velocity = math::uint_to_float(static_cast<int>(v_int), lim.velocity_min, lim.velocity_max, 12);
    fdb.torque = math::uint_to_float(static_cast<int>(t_int), lim.torque_min, lim.torque_max, 12);
    raw.temp_mos = static_cast<float>(buffer[6]);
    raw.temp_rotor = static_cast<float>(buffer[7]);
    fdb.temperature = raw.temp_rotor;
}

void dmmotor::emit_disable()
{
    transmit_frame(can_id(), disable_frame, 8);
}

void dmmotor::emit_mit(float position, float velocity, float kp, float kd, float torque)
{
    uint8_t output[8] = {0};
    const limits lim = motion_limits();
    const float position_set = math::clamp_loop(position, -math::pi, math::pi);
    const uint16_t pos_tmp = static_cast<uint16_t>(math::float_to_uint(
        position_set, lim.position_min, lim.position_max, 16));
    const uint16_t vel_tmp = static_cast<uint16_t>(math::float_to_uint(
        velocity, lim.velocity_min, lim.velocity_max, 12));
    const uint16_t kp_tmp = static_cast<uint16_t>(math::float_to_uint(kp, kp_min, kp_max, 12));
    const uint16_t kd_tmp = static_cast<uint16_t>(math::float_to_uint(kd, kd_min, kd_max, 12));
    const uint16_t tor_tmp = static_cast<uint16_t>(math::float_to_uint(
        torque, lim.torque_min, lim.torque_max, 12));

    output[0] = static_cast<uint8_t>(pos_tmp >> 8);
    output[1] = static_cast<uint8_t>(pos_tmp);
    output[2] = static_cast<uint8_t>(vel_tmp >> 4);
    output[3] = static_cast<uint8_t>(((vel_tmp & 0xF) << 4) | (kp_tmp >> 8));
    output[4] = static_cast<uint8_t>(kp_tmp);
    output[5] = static_cast<uint8_t>(kd_tmp >> 4);
    output[6] = static_cast<uint8_t>(((kd_tmp & 0xF) << 4) | (tor_tmp >> 8));
    output[7] = static_cast<uint8_t>(tor_tmp);

    transmit_frame(can_id(), output, 8);
}

void dmmotor::emit_pos_speed(float position, float velocity)
{
    uint8_t output[8] = {0};
    std::memcpy(output, &position, 4);
    std::memcpy(output + 4, &velocity, 4);
    transmit_frame(can_id() + 0x100, output, 8);
}

void dmmotor::emit_velocity(float velocity)
{
    uint8_t output[8] = {0};
    std::memcpy(output, &velocity, 4);
    transmit_frame(can_id() + 0x200, output, 8);
}

dm4310::dm4310(config cfg) : dmmotor(cfg, 1.0f)
{
    lower_pos_limit = p_min;
    upper_pos_limit = p_max;
}

dmmotor::limits dm4310::motion_limits() const
{
    return {p_min, p_max, v_min, v_max, t_min, t_max};
}

void dm4310::set_output()
{
    cmd.position = math::clamp(cmd.position, lower_pos_limit, upper_pos_limit);

    switch (control_mode)
    {
        case mode::relax:
            emit_disable();
            break;
        case mode::mit:
            emit_mit(cmd.position, cmd.velocity, cmd.kp, cmd.kd, cmd.torque);
            break;
        case mode::pos_speed:
            emit_pos_speed(cmd.position, cmd.velocity);
            break;
        case mode::speed:
            emit_velocity(cmd.velocity);
            break;
        default:
            emit_disable();
            break;
    }
}

dm8009p::dm8009p(config cfg) : dmmotor(cfg, 1.0f)
{
    lower_pos_limit = p_min;
    upper_pos_limit = p_max;
}

dmmotor::limits dm8009p::motion_limits() const
{
    return {p_min, p_max, v_min, v_max, t_min, t_max};
}

void dm8009p::set_output()
{
    switch (control_mode)
    {
        case mode::relax:
            emit_disable();
            break;
        case mode::mit:
            emit_mit(0.0f, 0.0f, 0.0f, 0.0f, cmd.torque);
            break;
        case mode::pos_speed:
            cmd.position = math::clamp(cmd.position, lower_pos_limit, upper_pos_limit);
            emit_pos_speed(cmd.position, cmd.velocity);
            break;
        case mode::speed:
            emit_velocity(cmd.velocity);
            break;
        default:
            emit_disable();
            break;
    }
}

} // namespace motors
