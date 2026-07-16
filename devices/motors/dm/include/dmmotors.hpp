#pragma once

#include "motor.hpp"

#include "constants.hpp"
#include "constrain.hpp"
#include "trans.hpp"

#include <cstdint>
#include <cstring>

namespace motors
{

class dmmotor : public motor
{
public:
    enum class error : uint8_t
    {
        disable = 0x0,
        enable = 0x1,
        over_voltage = 0x8,
        under_voltage = 0x9,
        over_current = 0xA,
        mos_over_temp = 0xB,
        coil_over_temp = 0xC,
        comm_lost = 0xD,
        overload = 0xE,
    };

    struct limits
    {
        float position_min = 0.0f;
        float position_max = 0.0f;
        float velocity_min = 0.0f;
        float velocity_max = 0.0f;
        float torque_min = 0.0f;
        float torque_max = 0.0f;
    };

    struct rawfeedback
    {
        uint8_t first_byte = 0;
        uint8_t id = 0;
        error err = error::disable;
        float temp_mos = 0.0f;
        float temp_rotor = 0.0f;
    };

    static constexpr float kp_min = 0.0f;
    static constexpr float kp_max = 500.0f;
    static constexpr float kd_min = 0.0f;
    static constexpr float kd_max = 5.0f;

    static inline const uint8_t enable_frame[8] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFC};
    static inline const uint8_t disable_frame[8] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFD};
    static inline const uint8_t save_zero_frame[8] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFE};
    static inline const uint8_t clear_error_frame[8] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFB};

    explicit dmmotor(config cfg, float kt = 1.0f) : motor(cfg, kt) {}

    void parse_feedback(const uint8_t* data, uint8_t len) override;
    capabilities get_capabilities() const override { return {false, false, true, true, true}; }

    void receive_data(const uint8_t* buffer);
    void transmit_frame(uint32_t frame_id, const uint8_t* data, uint16_t len);

    rawfeedback raw{};
    bool enablefailed = false;
    uint32_t last_tx_id = 0;

    float lower_pos_limit = 0.0f;
    float upper_pos_limit = 0.0f;

protected:
    virtual limits motion_limits() const = 0;
    void emit_disable();
    void emit_mit(float position, float velocity, float kp, float kd, float torque);
    void emit_pos_speed(float position, float velocity);
    void emit_velocity(float velocity);
};

class dm4310 : public dmmotor
{
public:
    explicit dm4310(config cfg);

    void set_output() override;

protected:
    limits motion_limits() const override;

private:
    static constexpr float p_min = -12.56637061f;
    static constexpr float p_max = 12.56637061f;
    static constexpr float v_min = -15.0f;
    static constexpr float v_max = 15.0f;
    static constexpr float t_min = -10.0f;
    static constexpr float t_max = 10.0f;
};

class dm8009p : public dmmotor
{
public:
    explicit dm8009p(config cfg);

    void set_output() override;

protected:
    limits motion_limits() const override;

private:
    static constexpr float p_min = -12.5f;
    static constexpr float p_max = 12.5f;
    static constexpr float v_min = -45.0f;
    static constexpr float v_max = 45.0f;
    static constexpr float t_min = -54.0f;
    static constexpr float t_max = 54.0f;
};

} // namespace motors
