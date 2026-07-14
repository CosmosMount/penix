#pragma once

#include "usertypes.hpp"

namespace bsp::flash
{

inline constexpr uint16_t flash_word_size = 32;

types::status erase_sector(std::uint32_t addr);
types::status write_flash_word(std::uint32_t addr, const void* data);
uint32_t tick_ms();

} // namespace bsp::flash
