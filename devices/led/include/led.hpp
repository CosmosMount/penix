#pragma once

#include <cstdint>

namespace led
{

enum class color : uint8_t
{
    red = 0,
    green,
    blue,
    white,
};

void init();
void on(color c);
void off(color c);
void toggle(color c);
void blink(color c);
void all_off();
void all_on();

} // namespace led
