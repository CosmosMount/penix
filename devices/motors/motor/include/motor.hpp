#pragma once

#include "bsp_can.hpp"

#include <cstdint>
#include <type_traits>

namespace motors
{

enum class state : uint8_t
{
    offline = 0,
    online,
    blocked,
};

enum class mode : uint8_t
{
    relax = 0,
    torque,
    mit,
    pos_speed,
    speed,
    multi,
};

struct config
{
    bsp::can::bus can_bus = bsp::can::bus::fdcan1;
    bsp::can::bus_type can_type = bsp::can::bus_type::classic;
    uint32_t can_id = 0;
    mode control_mode = mode::relax;
};

struct command
{
    int16_t current = 0;
    float torque = 0.0f;
    float position = 0.0f;
    float velocity = 0.0f;
    float kp = 0.0f;
    float kd = 0.0f;
};

struct feedback
{
    float position = 0.0f;
    float velocity = 0.0f;
    float torque = 0.0f;
    float current = 0.0f;
    float temperature = 0.0f;
    uint8_t error_code = 0;
};

struct capabilities
{
    bool current = false;
    bool torque = false;
    bool mit = false;
    bool pos_speed = false;
    bool velocity = false;
};

class api
{
public:
    virtual ~api() = default;

    virtual void set_command(const command& next_command, mode next_mode) = 0;
    virtual const feedback& get_feedback() const = 0;
    virtual state status() const = 0;
    virtual capabilities get_capabilities() const = 0;
    virtual bool supports(mode request_mode) const = 0;
    virtual void relax() = 0;
};

class motor : public api
{
public:
    explicit motor(config cfg, float kt = 0.0f) : torque_constant(kt), config_(cfg)
    {
        control_mode = cfg.control_mode;
    }

    virtual ~motor() = default;

    virtual void set_output() = 0;
    virtual void parse_feedback(const uint8_t* data, uint8_t len) = 0;

    state alive_check();

    void set_command(const command& next_command, mode next_mode) override;
    const feedback& get_feedback() const override { return fdb; }
    state status() const override { return motor_state; }
    capabilities get_capabilities() const override { return {}; }
    bool supports(mode request_mode) const override;
    void relax() override;

    void set_current(int16_t current);
    void set_torque(float torque);
    void set_mit(float position, float velocity, float kp, float kd, float torque);
    void set_pos_speed(float position, float velocity);
    void set_velocity(float velocity);

    float torque_from_current(float current) const { return current * torque_constant; }
    float current_from_torque(float torque) const
    {
        return torque_constant != 0.0f ? torque / torque_constant : 0.0f;
    }

    const config& cfg() const { return config_; }
    bsp::can::bus can_bus() const { return config_.can_bus; }
    bsp::can::bus_type can_type() const { return config_.can_type; }
    uint32_t can_id() const { return config_.can_id; }

    command cmd{};
    feedback fdb{};
    mode control_mode = mode::relax;
    state motor_state = state::offline;

    float torque_constant = 0.0f;

    uint16_t max_current = 0;
    float offset = 0.0f;

    uint32_t alive = 0;
    uint32_t prealive = 0;

protected:
    void mark_alive() { ++alive; }

    config config_;
};

template <typename T>
inline constexpr bool is_motor_v = std::is_base_of_v<motor, T>;

inline void motor::relax()
{
    control_mode = mode::relax;
    cmd = {};
}

inline void motor::set_command(const command& next_command, mode next_mode)
{
    cmd = next_command;
    control_mode = next_mode;
}

inline bool motor::supports(mode request_mode) const
{
    const capabilities caps = get_capabilities();
    switch (request_mode)
    {
        case mode::relax:
            return true;
        case mode::torque:
            return caps.torque || caps.current;
        case mode::mit:
            return caps.mit;
        case mode::pos_speed:
            return caps.pos_speed;
        case mode::speed:
            return caps.velocity;
        case mode::multi:
            return false;
        default:
            return false;
    }
}

inline void motor::set_current(int16_t current)
{
    command next{};
    next.current = current;
    set_command(next, mode::torque);
}

inline void motor::set_torque(float torque)
{
    command next{};
    next.torque = torque;
    next.current = static_cast<int16_t>(current_from_torque(torque));
    set_command(next, mode::torque);
}

inline void motor::set_mit(float position, float velocity, float kp, float kd, float torque)
{
    command next{};
    next.position = position;
    next.velocity = velocity;
    next.kp = kp;
    next.kd = kd;
    next.torque = torque;
    set_command(next, mode::mit);
}

inline void motor::set_pos_speed(float position, float velocity)
{
    command next{};
    next.position = position;
    next.velocity = velocity;
    set_command(next, mode::pos_speed);
}

inline void motor::set_velocity(float velocity)
{
    command next{};
    next.velocity = velocity;
    set_command(next, mode::speed);
}

inline state motor::alive_check()
{
    if (alive == prealive)
    {
        motor_state = state::offline;
    }
    else
    {
        prealive = alive;
        motor_state = state::online;
    }
    return motor_state;
}

} // namespace motors
