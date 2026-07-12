#pragma once

namespace filter
{

class iir
{
public:
    explicit iir(float omega_n, float zeta, float dt);

    float update(float input) const;
    void reset();

private:
    float b0_ = 0.0f;
    float b1_ = 0.0f;
    float b2_ = 0.0f;
    float a1_ = 0.0f;
    float a2_ = 0.0f;
    mutable float x1_ = 0.0f;
    mutable float x2_ = 0.0f;
    mutable float y1_ = 0.0f;
    mutable float y2_ = 0.0f;
};

} // namespace filter
