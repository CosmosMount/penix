#include "kalman_1d.hpp"

namespace filter
{

void kalman_1d::reset()
{
    last_p_ = 0.02f;
    now_p_ = 0.0f;
    value_ = 0.0f;
    gain_ = 0.0f;
    q_ = 0.001f;
    r_ = 0.543f;
}

void kalman_1d::set_process_noise(float q)
{
    q_ = q;
}

void kalman_1d::set_measurement_noise(float r)
{
    r_ = r;
}

void kalman_1d::set_gain(float gain)
{
    gain_ = gain;
}

float kalman_1d::update(float input)
{
    now_p_ = last_p_ + q_;
    gain_ = now_p_ / (now_p_ + r_);
    value_ += gain_ * (input - value_);
    last_p_ = (1.0f - gain_) * now_p_;
    return value_;
}

} // namespace filter
