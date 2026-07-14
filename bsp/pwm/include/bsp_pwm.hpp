#pragma once

#include "usertypes.hpp"

namespace bsp::pwm
{

enum class channel : uint8_t
{
    tim3_ch4 = 0,
    tim12_ch2 = 1,
};

constexpr bool is_enabled(channel ch)
{
    switch (ch)
    {
#if HAS_PWM_TIM3_CH4
    case channel::tim3_ch4:
        return true;
#endif
#if HAS_PWM_TIM12_CH2
    case channel::tim12_ch2:
        return true;
#endif
    default:
        return false;
    }
}

types::status init(channel ch);
types::status start(channel ch);
types::status stop(channel ch);
void set_duty(channel ch, float duty_ratio);
void set_period(channel ch, float period_s);

template <channel Ch>
types::status init()
{
    static_assert(is_enabled(Ch), "PWM channel not enabled in board/board.ioc");
    return init(Ch);
}

} // namespace bsp::pwm
