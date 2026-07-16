#pragma once

#include "motor.hpp"

#include <cstdint>

namespace motors
{

class djimotor : public motor
{
public:
    struct rawfeedback
    {
        int16_t last_ecd = 0;
        uint16_t ecd = 0;
        uint16_t ecd_offset = 0;
        int16_t speed_rpm = 0;
        int8_t ecd_cnt = 0;
        int16_t total_cnt = 0;
    };

    explicit djimotor(config cfg, float kt = 0.0f, float pos_to_rad = 0.0007669903939f,
                      float rpm_to_rad_s = 0.1047197551196f,
                      bool multi_turn_feedback = false);

    void set_output() override;
    void parse_feedback(const uint8_t* data, uint8_t len) override;
    capabilities get_capabilities() const override { return {true, true, false, false, false}; }

    void reset_position();
    void update_sensor_data(const uint8_t* data);

    rawfeedback raw{};
    bool blocked = false;

private:
    float rpm_to_rad_s(int16_t rpm) const;
    float ecd_to_rad(const rawfeedback& raw_fb) const;

    float pos_to_rad_ = 0.0007669903939f;
    float rpm_to_rad_s_ = 0.1047197551196f;
    bool multi_turn_feedback_ = false;
};

class m2006 : public djimotor
{
public:
    explicit m2006(config cfg);
};

class m3508 : public djimotor
{
public:
    explicit m3508(config cfg);
};

class gm6020 : public djimotor
{
public:
    explicit gm6020(config cfg);
};

class xroll : public djimotor
{
public:
    explicit xroll(config cfg);
};

} // namespace motors
