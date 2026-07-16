#pragma once

#include "motor.hpp"
#include "xv2protocol.hpp"

#include <cstdint>

namespace motors
{

class xv2motor : public motor
{
public:
    struct options
    {
        options() = default;

        uint8_t address = 1;
        uint32_t tx_id = xv2::default_can_id;
        uint16_t acceleration_rpm_s = 1000;
        uint16_t current_ramp_ma_s = 1000;
        bool sync = false;
        xv2::position_reference position_reference = xv2::position_reference::absolute;
    };

    explicit xv2motor(config cfg);
    xv2motor(config cfg, options opts);

    void set_output() override;
    void parse_feedback(const uint8_t* data, uint8_t len) override;
    capabilities get_capabilities() const override { return {true, true, false, true, true}; }

    void enable(bool sync = false);
    void disable(bool sync = false);
    void stop_now(bool sync = false);
    void reset_position();
    void trigger_encoder_calibration();
    void reset_clog_protection();
    void request_feedback(xv2::sys_param param);

    uint8_t address() const { return options_.address; }
    uint32_t tx_id() const { return options_.tx_id; }

private:
    void transmit(const xv2::frame& frame);
    static float rad_to_deg(float rad);
    static float rad_s_to_rpm(float rad_s);

    options options_{};
};

class x42 : public xv2motor
{
public:
    explicit x42(config cfg);
    x42(config cfg, options opts);
};

class y42 : public xv2motor
{
public:
    explicit y42(config cfg);
    y42(config cfg, options opts);
};

} // namespace motors
