#pragma once

#if defined(__GNUC__)
#define RAM_D1_BSS __attribute__((section(".ram_d1_bss")))
#define RAM_D2_BSS __attribute__((section(".ram_d2_bss")))
#define RAM_D3_BSS __attribute__((section(".ram_d3_bss")))
#else
#define RAM_D1_BSS
#define RAM_D2_BSS
#define RAM_D3_BSS
#endif
