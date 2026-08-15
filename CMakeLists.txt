cmake_minimum_required(VERSION 3.22)

set(PNX_CONFIG_FILE "${CMAKE_CURRENT_SOURCE_DIR}/configs/config.json")
if(NOT EXISTS "${PNX_CONFIG_FILE}")
    message(FATAL_ERROR "Missing unified board configuration: ${PNX_CONFIG_FILE}")
endif()
file(READ "${PNX_CONFIG_FILE}" PNX_CONFIG_JSON)
string(JSON PNX_BOARD ERROR_VARIABLE PNX_CONFIG_ERROR GET "${PNX_CONFIG_JSON}" board)
if(PNX_CONFIG_ERROR OR PNX_BOARD STREQUAL "")
    message(FATAL_ERROR "configs/config.json must contain a non-empty string key 'board'")
endif()

set(PNX_BOARD_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/boards/${PNX_BOARD}")
set(PNX_BSP_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/bsp/${PNX_BOARD}")
if(NOT IS_DIRECTORY "${PNX_BOARD_ROOT}" OR NOT IS_DIRECTORY "${PNX_BSP_ROOT}")
    message(FATAL_ERROR "Board '${PNX_BOARD}' must provide ${PNX_BOARD_ROOT} and ${PNX_BSP_ROOT}")
endif()

if(NOT CMAKE_TOOLCHAIN_FILE)
    set(PNX_EMBEDDED_COMPILER_HINT "${CMAKE_C_COMPILER};${CMAKE_CXX_COMPILER}")
    if(PNX_EMBEDDED_COMPILER_HINT MATCHES "arm-none-eabi")
        include("${CMAKE_CURRENT_SOURCE_DIR}/cmake/gcc-arm-none-eabi.cmake")
    endif()
    unset(PNX_EMBEDDED_COMPILER_HINT)
endif()

project(pnx_embedded LANGUAGES C CXX ASM)
if(PNX_BOARD STREQUAL "stm32h723")
    set(PNX_TARGET_FLAGS "-mcpu=cortex-m7 -mfpu=fpv5-d16 -mfloat-abi=hard")
    set(PNX_LINKER_SCRIPT "${PNX_BOARD_ROOT}/STM32H723XG_FLASH.ld")
elseif(PNX_BOARD STREQUAL "stm32f407")
    set(PNX_TARGET_FLAGS "-mcpu=cortex-m4 -mfpu=fpv4-sp-d16 -mfloat-abi=hard")
    set(PNX_LINKER_SCRIPT "${PNX_BOARD_ROOT}/STM32F407XX_FLASH.ld")
endif()
set(CMAKE_EXE_LINKER_FLAGS "" CACHE STRING
    "Global linker flags are intentionally empty; the selected board target owns them"
    FORCE)
set(CMAKE_EXE_LINKER_FLAGS "")
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS ON)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

set(PNX_EMBEDDED_GENERATED_DIR "${CMAKE_BINARY_DIR}/generated")
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
    "${PNX_CONFIG_FILE}"
    "${PNX_BOARD_ROOT}/board.ioc"
    "${CMAKE_CURRENT_SOURCE_DIR}/configs/cmake/generate_config.cmake"
    "${CMAKE_CURRENT_SOURCE_DIR}/configs/cmake/import_ioc.cmake"
    "${PNX_BOARD_ROOT}/CMakeLists.txt")

add_executable(${PROJECT_NAME})

if(PNX_BOARD STREQUAL "stm32h723")
    set(IOC "${PNX_BOARD_ROOT}/board.ioc")
    set(CONFIG "${PNX_CONFIG_FILE}")
    set(OUT_DIR "${PNX_EMBEDDED_GENERATED_DIR}")
    include("${CMAKE_CURRENT_SOURCE_DIR}/configs/cmake/generate_config.cmake")
    unset(IOC)
    unset(CONFIG)
    unset(OUT_DIR)

    file(GLOB_RECURSE PNX_EMBEDDED_SOURCES CONFIGURE_DEPENDS
        "${PNX_BSP_ROOT}/*.c" "${PNX_BSP_ROOT}/*.cpp"
        "${CMAKE_CURRENT_SOURCE_DIR}/devices/*.cpp"
        "${CMAKE_CURRENT_SOURCE_DIR}/modules/*.cpp"
        "${CMAKE_CURRENT_SOURCE_DIR}/libs/*.cpp"
        "${CMAKE_CURRENT_SOURCE_DIR}/demo/*.cpp")
    list(FILTER PNX_EMBEDDED_SOURCES EXCLUDE REGEX "[/\\\\]demo[/\\\\]f4[/\\\\]")
    if(NOT ENABLE_USBX)
        list(FILTER PNX_EMBEDDED_SOURCES EXCLUDE REGEX "[/\\\\]bsp[/\\\\]usb[/\\\\]")
    endif()
    if(NOT HAS_DMIMU)
        list(FILTER PNX_EMBEDDED_SOURCES EXCLUDE REGEX "[/\\\\]devices[/\\\\]imu[/\\\\]dmimu[/\\\\]")
    endif()

    file(GLOB_RECURSE PNX_EMBEDDED_HEADERS CONFIGURE_DEPENDS
        "${PNX_BSP_ROOT}/*.h" "${PNX_BSP_ROOT}/*.hpp"
        "${CMAKE_CURRENT_SOURCE_DIR}/devices/*.h" "${CMAKE_CURRENT_SOURCE_DIR}/devices/*.hpp"
        "${CMAKE_CURRENT_SOURCE_DIR}/modules/*.h" "${CMAKE_CURRENT_SOURCE_DIR}/modules/*.hpp"
        "${CMAKE_CURRENT_SOURCE_DIR}/libs/*.h" "${CMAKE_CURRENT_SOURCE_DIR}/libs/*.hpp"
        "${CMAKE_CURRENT_SOURCE_DIR}/demo/*.hpp")
    if(NOT HAS_DMIMU)
        list(FILTER PNX_EMBEDDED_HEADERS EXCLUDE REGEX "[/\\\\]devices[/\\\\]imu[/\\\\]dmimu[/\\\\]")
    endif()
    set(PNX_EMBEDDED_INCLUDE_DIRS)
    foreach(header IN LISTS PNX_EMBEDDED_HEADERS)
        get_filename_component(header_dir "${header}" DIRECTORY)
        list(APPEND PNX_EMBEDDED_INCLUDE_DIRS "${header_dir}")
    endforeach()
    list(REMOVE_DUPLICATES PNX_EMBEDDED_INCLUDE_DIRS)

    set(CMSIS_DSP_SOURCES
        "${CMAKE_CURRENT_SOURCE_DIR}/cmsis-dsp/Source/BasicMathFunctions/arm_dot_prod_f32.c"
        "${CMAKE_CURRENT_SOURCE_DIR}/cmsis-dsp/Source/MatrixFunctions/arm_mat_add_f32.c"
        "${CMAKE_CURRENT_SOURCE_DIR}/cmsis-dsp/Source/MatrixFunctions/arm_mat_init_f32.c"
        "${CMAKE_CURRENT_SOURCE_DIR}/cmsis-dsp/Source/MatrixFunctions/arm_mat_inverse_f32.c"
        "${CMAKE_CURRENT_SOURCE_DIR}/cmsis-dsp/Source/MatrixFunctions/arm_mat_mult_f32.c"
        "${CMAKE_CURRENT_SOURCE_DIR}/cmsis-dsp/Source/MatrixFunctions/arm_mat_sub_f32.c"
        "${CMAKE_CURRENT_SOURCE_DIR}/cmsis-dsp/Source/MatrixFunctions/arm_mat_trans_f32.c")
    add_subdirectory("${PNX_BOARD_ROOT}/cmake/stm32cubemx" board_support)
    target_sources(${PROJECT_NAME} PRIVATE ${PNX_EMBEDDED_SOURCES} ${CMSIS_DSP_SOURCES}
        "${PNX_EMBEDDED_GENERATED_DIR}/bsp_bindings.cpp")
    target_include_directories(${PROJECT_NAME} PRIVATE ${PNX_EMBEDDED_INCLUDE_DIRS}
        "${CMAKE_CURRENT_SOURCE_DIR}/cmsis-dsp/Include" "${PNX_EMBEDDED_GENERATED_DIR}")
    target_link_libraries(${PROJECT_NAME} stm32cubemx)
elseif(PNX_BOARD STREQUAL "stm32f407")
    set(PNX_UNIFIED_ROOT ON)
    set(PNX_BOARD_CONFIG "${PNX_CONFIG_FILE}")
    include("${PNX_BOARD_ROOT}/CMakeLists.txt")
else()
    message(FATAL_ERROR "Unsupported board '${PNX_BOARD}'")
endif()

set_property(TARGET ${PROJECT_NAME} PROPERTY LINK_FLAGS
    "${PNX_TARGET_FLAGS} -T\"${PNX_LINKER_SCRIPT}\" --specs=nano.specs -Wl,-Map=pnx_embedded.map -Wl,--gc-sections -Wl,--print-memory-usage")
list(REMOVE_ITEM CMAKE_C_IMPLICIT_LINK_LIBRARIES ob)
message(STATUS "PnX selected board: ${PNX_BOARD}")
