#pragma once

namespace math
{

int float_to_uint(float value, float min_value, float max_value, int bits);
float uint_to_float(int value, float min_value, float max_value, int bits);

} // namespace math
