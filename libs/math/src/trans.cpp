#include "trans.hpp"

namespace math
{

int float_to_uint(float value, float min_value, float max_value, int bits)
{
    const float span = max_value - min_value;
    return static_cast<int>((value - min_value) * static_cast<float>((1 << bits) - 1) / span);
}

float uint_to_float(int value, float min_value, float max_value, int bits)
{
    const float span = max_value - min_value;
    return static_cast<float>(value) * span / static_cast<float>((1 << bits) - 1) + min_value;
}

} // namespace math
