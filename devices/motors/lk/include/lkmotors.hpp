#pragma once

#include "motor.hpp"

#include <cstdint>

namespace motors
{

class lkmotor : public motor
{
public:
    struct rawfeedback
    {
        int16_t last_ecd = 0;
        uint16_t ecd = 0;
        int16_t speed_dps = 0;
        int16_t current_raw = 0;
    };

    explicit lkmotor(config cfg, float kt = 0.0f);

    void set_output() override;
    void parse_feedback(const uint8_t* data, uint8_t len) override;
    capabilities get_capabilities() const override { return {true, true, false, false, false}; }

    rawfeedback raw{};

protected:
    virtual void update_sensor_data(const uint8_t* buffer) = 0;
};

class lk8016 : public lkmotor
{
public:
    static constexpr float gear_ratio = 0.166667f;
    static constexpr float raw_pos_to_rad = 0.00009587379924285f;
    static constexpr float raw_dps_to_rps = 0.0174532925199433f;

    explicit lk8016(config cfg);

protected:
    void update_sensor_data(const uint8_t* buffer) override;
};

class lk8025 : public lkmotor
{
public:
    static constexpr float raw_pos_to_rad = 0.00009587379924285f;
    static constexpr float raw_dps_to_rps = 0.0174532925199433f;

    explicit lk8025(config cfg);

protected:
    void update_sensor_data(const uint8_t* buffer) override;
};

} // namespace motors
