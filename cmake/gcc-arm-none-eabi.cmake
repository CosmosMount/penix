set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR arm)

set(CMAKE_C_COMPILER_ID GNU)
set(CMAKE_CXX_COMPILER_ID GNU)

set(TOOLCHAIN_PREFIX arm-none-eabi-)
set(CMAKE_C_COMPILER ${TOOLCHAIN_PREFIX}gcc)
set(CMAKE_ASM_COMPILER ${CMAKE_C_COMPILER})
set(CMAKE_CXX_COMPILER ${TOOLCHAIN_PREFIX}g++)
set(CMAKE_LINKER ${TOOLCHAIN_PREFIX}g++)
set(CMAKE_OBJCOPY ${TOOLCHAIN_PREFIX}objcopy)
set(CMAKE_OBJDUMP ${TOOLCHAIN_PREFIX}objdump)
set(CMAKE_READELF ${TOOLCHAIN_PREFIX}readelf)
set(CMAKE_SIZE ${TOOLCHAIN_PREFIX}size)

set(CMAKE_EXECUTABLE_SUFFIX_ASM ".elf")
set(CMAKE_EXECUTABLE_SUFFIX_C ".elf")
set(CMAKE_EXECUTABLE_SUFFIX_CXX ".elf")
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

set(PNX_CONFIG_FILE "${CMAKE_CURRENT_LIST_DIR}/../configs/config.json")
if(NOT EXISTS "${PNX_CONFIG_FILE}")
    message(FATAL_ERROR "Missing unified board configuration: ${PNX_CONFIG_FILE}")
endif()
file(READ "${PNX_CONFIG_FILE}" PNX_CONFIG_JSON)
string(JSON PNX_TOOLCHAIN_BOARD ERROR_VARIABLE PNX_CONFIG_ERROR
    GET "${PNX_CONFIG_JSON}" board)
if(PNX_CONFIG_ERROR OR PNX_TOOLCHAIN_BOARD STREQUAL "")
    message(FATAL_ERROR "configs/config.json must contain a non-empty string key 'board'")
endif()

if(PNX_TOOLCHAIN_BOARD STREQUAL "stm32h723")
    set(PNX_TARGET_FLAGS "-mcpu=cortex-m7 -mfpu=fpv5-d16 -mfloat-abi=hard")
    set(PNX_LINKER_SCRIPT
        "${CMAKE_CURRENT_LIST_DIR}/../boards/stm32h723/STM32H723XG_FLASH.ld")
elseif(PNX_TOOLCHAIN_BOARD STREQUAL "stm32f407")
    set(PNX_TARGET_FLAGS "-mcpu=cortex-m4 -mfpu=fpv4-sp-d16 -mfloat-abi=hard")
    set(PNX_LINKER_SCRIPT
        "${CMAKE_CURRENT_LIST_DIR}/../boards/stm32f407/STM32F407XX_FLASH.ld")
else()
    message(FATAL_ERROR "Unsupported board '${PNX_TOOLCHAIN_BOARD}' in configs/config.json")
endif()

set(CMAKE_C_FLAGS_INIT
    "${PNX_TARGET_FLAGS} -Wall -fdata-sections -ffunction-sections")
set(CMAKE_ASM_FLAGS_INIT
    "${PNX_TARGET_FLAGS} -x assembler-with-cpp -MMD -MP")
set(CMAKE_CXX_FLAGS_INIT
    "${PNX_TARGET_FLAGS} -Wall -fdata-sections -ffunction-sections -fno-rtti -fno-exceptions -fno-threadsafe-statics")
set(CMAKE_C_FLAGS_DEBUG_INIT "-O0 -g3")
set(CMAKE_C_FLAGS_RELEASE_INIT "-Os -g0")
set(CMAKE_CXX_FLAGS_DEBUG_INIT "-O0 -g3")
set(CMAKE_CXX_FLAGS_RELEASE_INIT "-Os -g0")
set(CMAKE_EXE_LINKER_FLAGS_INIT
    "${PNX_TARGET_FLAGS} -T\"${PNX_LINKER_SCRIPT}\" --specs=nano.specs -Wl,-Map=pnx_embedded.map -Wl,--gc-sections -Wl,--print-memory-usage")
set(CMAKE_EXE_LINKER_FLAGS
    "${PNX_TARGET_FLAGS} -T\"${PNX_LINKER_SCRIPT}\" --specs=nano.specs -Wl,-Map=pnx_embedded.map -Wl,--gc-sections -Wl,--print-memory-usage"
    CACHE STRING "Board-specific embedded linker flags" FORCE)
set(TOOLCHAIN_LINK_LIBRARIES m)
