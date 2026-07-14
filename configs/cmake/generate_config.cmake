cmake_minimum_required(VERSION 3.22)

include(${CMAKE_CURRENT_LIST_DIR}/import_ioc.cmake)

if(NOT DEFINED IOC OR NOT DEFINED PARAMS OR NOT DEFINED OUT_DIR)
    message(FATAL_ERROR "generate_config.cmake requires -DIOC=... -DPARAMS=... -DOUT_DIR=...")
endif()

pnx_ioc_parse("${IOC}")

file(READ "${PARAMS}" params_json)

# --- params.json: build ---
string(JSON build_usbx ERROR_VARIABLE json_err GET "${params_json}" build usbx)
if(json_err)
    set(build_usbx "false")
endif()
pnx_to_json_bool("${build_usbx}" _usbx_json_unused)
if(build_usbx STREQUAL "true" OR build_usbx STREQUAL "1" OR build_usbx STREQUAL "ON")
    set(params_usbx TRUE)
else()
    set(params_usbx FALSE)
endif()

string(JSON motor_dji ERROR_VARIABLE json_err GET "${params_json}" build motors dji)
if(json_err)
    set(motor_dji "true")
endif()
string(JSON motor_dm ERROR_VARIABLE json_err GET "${params_json}" build motors dm)
if(json_err)
    set(motor_dm "true")
endif()
string(JSON motor_lk ERROR_VARIABLE json_err GET "${params_json}" build motors lk)
if(json_err)
    set(motor_lk "false")
endif()

function(_pnx_json_bool_to_cmake val out_var)
    if(val STREQUAL "true" OR val STREQUAL "1" OR val STREQUAL "ON")
        set(${out_var} ON PARENT_SCOPE)
    else()
        set(${out_var} OFF PARENT_SCOPE)
    endif()
endfunction()

_pnx_json_bool_to_cmake("${motor_dji}" MOTOR_DJI)
_pnx_json_bool_to_cmake("${motor_dm}" MOTOR_DM)
_pnx_json_bool_to_cmake("${motor_lk}" MOTOR_LK)

# --- params.json: bindings ---
string(JSON remoter_uart ERROR_VARIABLE json_err GET "${params_json}" bindings remoter_uart)
if(json_err)
    set(remoter_uart "uart5")
endif()
string(JSON referee_uart ERROR_VARIABLE json_err GET "${params_json}" bindings referee_uart)
if(json_err)
    set(referee_uart "usart1")
endif()
string(JSON remoter_source ERROR_VARIABLE json_err GET "${params_json}" remoter source)
if(json_err)
    set(remoter_source "")
endif()
string(TOLOWER "${remoter_uart}" remoter_uart)
string(TOLOWER "${referee_uart}" referee_uart)
string(TOLOWER "${remoter_source}" remoter_source)

# --- HAS_* from IOC + bindings ---
if(PNX_IOC_HAS_SPI2)
    set(HAS_AHRS 1)
else()
    set(HAS_AHRS 0)
endif()

if(PNX_IOC_HAS_SPI6)
    set(HAS_LED 1)
else()
    set(HAS_LED 0)
endif()

if(PNX_IOC_HAS_TIM3)
    set(HAS_PWM_TIM3_CH4 1)
else()
    set(HAS_PWM_TIM3_CH4 0)
endif()

if(PNX_IOC_HAS_TIM12)
    set(HAS_PWM_TIM12_CH2 1)
else()
    set(HAS_PWM_TIM12_CH2 0)
endif()

pnx_ioc_hw_in_list("${PNX_IOC_UART_HW}" "${remoter_uart}" remoter_uart_present)
pnx_ioc_uart_has_dma("${PNX_IOC_LINES}" "${remoter_uart}" "RX" remoter_has_rx_dma)
if(remoter_uart_present AND remoter_has_rx_dma)
    set(HAS_REMOTER 1)
else()
    set(HAS_REMOTER 0)
endif()

pnx_ioc_hw_in_list("${PNX_IOC_UART_HW}" "uart7" vt03_uart_present)
pnx_ioc_uart_has_dma("${PNX_IOC_LINES}" "uart7" "RX" vt03_has_rx_dma)
if(vt03_uart_present AND vt03_has_rx_dma)
    set(HAS_VT03 1)
else()
    set(HAS_VT03 0)
endif()

pnx_ioc_hw_in_list("${PNX_IOC_UART_HW}" "${referee_uart}" referee_uart_present)
if(referee_uart_present)
    set(HAS_REFEREE 1)
else()
    set(HAS_REFEREE 0)
endif()

if(HAS_REFEREE)
    set(HAS_UI 1)
else()
    set(HAS_UI 0)
endif()

if(remoter_source STREQUAL "")
    if(HAS_REMOTER)
        set(ENABLE_DR16 1)
        set(ENABLE_VT03 0)
    elseif(HAS_VT03)
        set(ENABLE_DR16 0)
        set(ENABLE_VT03 1)
    else()
        set(ENABLE_DR16 0)
        set(ENABLE_VT03 0)
    endif()
elseif(remoter_source STREQUAL "dr16")
    if(NOT HAS_REMOTER)
        message(FATAL_ERROR "params.remoter.source=dr16 requires remoter UART RX DMA support in board/board.ioc")
    endif()
    set(ENABLE_DR16 1)
    set(ENABLE_VT03 0)
elseif(remoter_source STREQUAL "vt03")
    if(NOT HAS_VT03)
        message(FATAL_ERROR "params.remoter.source=vt03 requires UART7 RX DMA support in board/board.ioc")
    endif()
    set(ENABLE_DR16 0)
    set(ENABLE_VT03 1)
else()
    message(FATAL_ERROR "params.remoter.source must be one of: dr16, vt03")
endif()

list(LENGTH PNX_IOC_FDCAN_HW fdcan_count)
if(fdcan_count GREATER 0)
    set(HAS_MOTORS 1)
else()
    set(HAS_MOTORS 0)
endif()

if(PNX_IOC_HAS_USB AND params_usbx)
    set(ENABLE_USBX ON)
else()
    set(ENABLE_USBX OFF)
endif()

if(PNX_IOC_HAS_USB)
    set(HW_HAS_USB 1)
else()
    set(HW_HAS_USB 0)
endif()

if(ENABLE_USBX)
    set(ENABLE_USBX_C 1)
else()
    set(ENABLE_USBX_C 0)
endif()

# --- BSP policy defaults (embedded, formerly board.json) ---
set(can_max_rx_callbacks 8)
set(tx_delay_tdc 13)
set(tx_delay_filter 13)

set(can_enabled_list "")
set(can_type_list "")
set(can_id_type_list "")
set(can_config_list "")
set(can_bus_enum_entries "")
set(can_bus_index 0)

foreach(hw ${PNX_IOC_FDCAN_HW})
    string(TOLOWER "${hw}" hw_lower)

    list(APPEND can_enabled_list "true")

    pnx_ioc_fdcan_frame_format("${PNX_IOC_LINES}" "${hw_lower}" bus_type)
    if(bus_type STREQUAL "fd")
        set(can_type_expr "bus_type::fd")
    else()
        set(can_type_expr "bus_type::classic")
    endif()
    list(APPEND can_type_list "${can_type_expr}")

    pnx_ioc_fdcan_ext_filters("${PNX_IOC_LINES}" "${hw_lower}" ext_filters)
    if(ext_filters GREATER 0)
        set(can_id_type_expr "id_type::extended")
    else()
        set(can_id_type_expr "id_type::standard")
    endif()
    list(APPEND can_id_type_list "${can_id_type_expr}")
    list(APPEND can_config_list "{ true, handle_id::${hw_lower}, ${can_type_expr}, ${can_id_type_expr} }")

    if(can_bus_index GREATER 0)
        string(APPEND can_bus_enum_entries ", ")
    endif()
    string(APPEND can_bus_enum_entries "${hw_lower} = ${can_bus_index}")
    math(EXPR can_bus_index "${can_bus_index} + 1")
endforeach()

list(JOIN can_enabled_list ", " can_enabled_cpp)
list(JOIN can_type_list ", " can_type_cpp)
list(JOIN can_id_type_list ", " can_id_type_cpp)
list(JOIN can_config_list ", " can_config_cpp)
list(LENGTH PNX_IOC_FDCAN_HW can_bus_count)

set(usart_enabled_list "")
set(usart_config_list "")
set(usart_port_enum_entries "")
set(uart_binding_body "")
set(usart_port_index 0)

foreach(hw ${PNX_IOC_UART_HW})
    string(TOLOWER "${hw}" hw_lower)

    pnx_ioc_uart_has_dma("${PNX_IOC_LINES}" "${hw_lower}" "RX" has_rx_dma)
    pnx_ioc_uart_has_dma("${PNX_IOC_LINES}" "${hw_lower}" "TX" has_tx_dma)
    pnx_to_json_bool("${has_rx_dma}" has_rx_dma_cpp)
    pnx_to_json_bool("${has_tx_dma}" has_tx_dma_cpp)
    list(APPEND usart_enabled_list "true")
    list(APPEND usart_config_list "{ true, handle_id::${hw_lower}, ${has_rx_dma_cpp}, ${has_tx_dma_cpp} }")

    if(usart_port_index GREATER 0)
        string(APPEND uart_binding_body "\n")
    endif()
    string(APPEND uart_binding_body "inline constexpr bsp::usart::port ${hw_lower} = ${usart_port_index};")

    if(usart_port_index GREATER 0)
        string(APPEND usart_port_enum_entries ", ")
    endif()
    string(APPEND usart_port_enum_entries "${hw_lower} = ${usart_port_index}")
    math(EXPR usart_port_index "${usart_port_index} + 1")
endforeach()

list(JOIN usart_enabled_list ", " usart_enabled_cpp)
list(JOIN usart_config_list ", " usart_config_cpp)
list(LENGTH PNX_IOC_UART_HW usart_port_count)

if(PNX_IOC_HAS_SPI2)
    set(spi2_enabled "true")
else()
    set(spi2_enabled "false")
endif()
if(PNX_IOC_HAS_SPI6)
    set(spi6_enabled "true")
else()
    set(spi6_enabled "false")
endif()
set(spi_bus_count 2)
set(spi_config_cpp "{ ${spi2_enabled}, handle_id::spi2 }, { ${spi6_enabled}, handle_id::spi6 }")

if(PNX_IOC_HAS_TIM3)
    set(pwm_tim3_ch4_enabled "true")
    set(pwm_tim3_ch4_timer "timer_id::tim3")
    set(pwm_tim3_ch4_channel "channel_id::ch4")
else()
    set(pwm_tim3_ch4_enabled "false")
    set(pwm_tim3_ch4_timer "timer_id::none")
    set(pwm_tim3_ch4_channel "channel_id::none")
endif()
if(PNX_IOC_HAS_TIM12)
    set(pwm_tim12_ch2_enabled "true")
    set(pwm_tim12_ch2_timer "timer_id::tim12")
    set(pwm_tim12_ch2_channel "channel_id::ch2")
else()
    set(pwm_tim12_ch2_enabled "false")
    set(pwm_tim12_ch2_timer "timer_id::none")
    set(pwm_tim12_ch2_channel "channel_id::none")
endif()
set(pwm_channel_count 2)
set(pwm_timer_clock_hz 240000000)
set(pwm_config_cpp
    "{ ${pwm_tim3_ch4_enabled}, ${pwm_tim3_ch4_timer}, ${pwm_tim3_ch4_channel}, ${pwm_timer_clock_hz}U }, { ${pwm_tim12_ch2_enabled}, ${pwm_tim12_ch2_timer}, ${pwm_tim12_ch2_channel}, ${pwm_timer_clock_hz}U }")

pnx_ioc_uart_index("${PNX_IOC_UART_HW}" "${remoter_uart}" dr16_port_idx)
pnx_ioc_uart_index("${PNX_IOC_UART_HW}" "uart7" vt03_port_idx)
pnx_ioc_uart_index("${PNX_IOC_UART_HW}" "${referee_uart}" referee_port_idx)

if(dr16_port_idx GREATER_EQUAL 0)
    set(dr16_binding "${remoter_uart}")
else()
    set(dr16_binding "0")
endif()
if(vt03_port_idx GREATER_EQUAL 0)
    set(vt03_binding "uart7")
else()
    set(vt03_binding "0")
endif()
if(referee_port_idx GREATER_EQUAL 0)
    set(referee_binding "${referee_uart}")
else()
    set(referee_binding "0")
endif()

set(active_remoter_uart "")
if(ENABLE_DR16)
    set(active_remoter_uart "${remoter_uart}")
elseif(ENABLE_VT03)
    set(active_remoter_uart "uart7")
endif()

string(JSON test_report_uart ERROR_VARIABLE json_err GET "${params_json}" test report_uart)
if(json_err)
    set(test_report_uart "uart7")
endif()
string(TOLOWER "${test_report_uart}" test_report_uart)
pnx_ioc_uart_index("${PNX_IOC_UART_HW}" "${test_report_uart}" test_report_port_idx)
if(test_report_port_idx LESS 0)
    message(FATAL_ERROR "params.test.report_uart=${test_report_uart} is not present in board/board.ioc")
endif()
if(NOT active_remoter_uart STREQUAL "" AND test_report_uart STREQUAL active_remoter_uart)
    message(FATAL_ERROR "params.test.report_uart=${test_report_uart} conflicts with the active remoter UART")
endif()
set(test_report_binding "${test_report_uart}")

# --- params namespace (explicit keys per section) ---
set(generated_semicolon_token "__PNX_GENERATED_SEMICOLON__")

function(_pnx_param_float section key out_var)
    string(JSON val ERROR_VARIABLE err GET "${params_json}" ${section} ${key})
    if(err)
        set(${out_var} "" PARENT_SCOPE)
        return()
    endif()
    set(${out_var} "  inline constexpr float ${key} = ${val}f${generated_semicolon_token}\n" PARENT_SCOPE)
endfunction()

function(_pnx_param_uint section key out_var)
    string(JSON val ERROR_VARIABLE err GET "${params_json}" ${section} ${key})
    if(err)
        set(${out_var} "" PARENT_SCOPE)
        return()
    endif()
    set(${out_var} "  inline constexpr std::uint32_t ${key} = ${val}${generated_semicolon_token}\n" PARENT_SCOPE)
endfunction()

function(_pnx_param_bool section key out_var)
    string(JSON val ERROR_VARIABLE err GET "${params_json}" ${section} ${key})
    if(err)
        set(${out_var} "" PARENT_SCOPE)
        return()
    endif()
    if(val STREQUAL "true" OR val STREQUAL "1" OR val STREQUAL "ON")
        set(${out_var} "  inline constexpr bool ${key} = true${generated_semicolon_token}\n" PARENT_SCOPE)
    else()
        set(${out_var} "  inline constexpr bool ${key} = false${generated_semicolon_token}\n" PARENT_SCOPE)
    endif()
endfunction()

set(params_ahrs_body "")
_pnx_param_float("ahrs" "imu_offset_x" _line)
string(APPEND params_ahrs_body "${_line}")
_pnx_param_uint("ahrs" "imu_thread_priority" _line)
string(APPEND params_ahrs_body "${_line}")
_pnx_param_uint("ahrs" "temp_thread_priority" _line)
string(APPEND params_ahrs_body "${_line}")
_pnx_param_float("ahrs" "target_temp" _line)
string(APPEND params_ahrs_body "${_line}")
if(params_ahrs_body STREQUAL "")
    string(CONCAT params_ahrs_body
        "  inline constexpr float imu_offset_x = 0.0f${generated_semicolon_token}\n"
        "  inline constexpr std::uint32_t imu_thread_priority = 3${generated_semicolon_token}\n"
        "  inline constexpr std::uint32_t temp_thread_priority = 4${generated_semicolon_token}\n"
        "  inline constexpr float target_temp = 45.0f${generated_semicolon_token}\n")
endif()

set(params_remoter_body "")
_pnx_param_uint("remoter" "thread_priority" _line)
string(APPEND params_remoter_body "${_line}")
_pnx_param_uint("remoter" "rx_timeout_ticks" _line)
string(APPEND params_remoter_body "${_line}")
if(params_remoter_body STREQUAL "")
    string(CONCAT params_remoter_body
        "  inline constexpr std::uint32_t thread_priority = 2${generated_semicolon_token}\n"
        "  inline constexpr std::uint32_t rx_timeout_ticks = 100${generated_semicolon_token}\n")
endif()

set(params_referee_body "")
_pnx_param_uint("referee" "thread_priority" _line)
string(APPEND params_referee_body "${_line}")
if(params_referee_body STREQUAL "")
    set(params_referee_body "  inline constexpr std::uint32_t thread_priority = 8${generated_semicolon_token}\n")
endif()

set(params_test_body "")
_pnx_param_uint("test" "thread_priority" _line)
string(APPEND params_test_body "${_line}")
_pnx_param_bool("test" "auto_run_on_boot" _line)
string(APPEND params_test_body "${_line}")
if(params_test_body STREQUAL "")
    string(CONCAT params_test_body
        "  inline constexpr std::uint32_t thread_priority = 10${generated_semicolon_token}\n"
        "  inline constexpr bool auto_run_on_boot = true${generated_semicolon_token}\n")
endif()

set(params_usb_body "")
_pnx_param_uint("usb" "read_thread_priority" _line)
string(APPEND params_usb_body "${_line}")
_pnx_param_uint("usb" "write_thread_priority" _line)
string(APPEND params_usb_body "${_line}")
_pnx_param_uint("usb" "period_ticks" _line)
string(APPEND params_usb_body "${_line}")
if(params_usb_body STREQUAL "")
    string(CONCAT params_usb_body
        "  inline constexpr std::uint32_t read_thread_priority = 5${generated_semicolon_token}\n"
        "  inline constexpr std::uint32_t write_thread_priority = 5${generated_semicolon_token}\n"
        "  inline constexpr std::uint32_t period_ticks = 2${generated_semicolon_token}\n")
endif()

if(MOTOR_DJI)
    set(MOTOR_DJI_C 1)
else()
    set(MOTOR_DJI_C 0)
endif()
if(MOTOR_DM)
    set(MOTOR_DM_C 1)
else()
    set(MOTOR_DM_C 0)
endif()
if(MOTOR_LK)
    set(MOTOR_LK_C 1)
else()
    set(MOTOR_LK_C 0)
endif()

file(MAKE_DIRECTORY "${OUT_DIR}")

set(CONFIG_HPP "${OUT_DIR}/config.hpp")

file(WRITE "${CONFIG_HPP}"
"#pragma once\n"
"// Generated from board/board.ioc + config/params.json. Do not edit.\n\n"
"#include <array>\n"
"#include <cstddef>\n"
"#include <cstdint>\n\n"
"#define HW_HAS_USB ${HW_HAS_USB}\n"
"#define ENABLE_USBX ${ENABLE_USBX_C}\n"
"#define HAS_AHRS ${HAS_AHRS}\n"
"#define HAS_REMOTER ${HAS_REMOTER}\n"
"#define HAS_VT03 ${HAS_VT03}\n"
"#define ENABLE_DR16 ${ENABLE_DR16}\n"
"#define ENABLE_VT03 ${ENABLE_VT03}\n"
"#define HAS_REFEREE ${HAS_REFEREE}\n"
"#define HAS_UI ${HAS_UI}\n"
"#define HAS_LED ${HAS_LED}\n"
"#define HAS_PWM_TIM3_CH4 ${HAS_PWM_TIM3_CH4}\n"
"#define HAS_PWM_TIM12_CH2 ${HAS_PWM_TIM12_CH2}\n"
"#define HAS_MOTORS ${HAS_MOTORS}\n"
"#define MOTOR_DJI ${MOTOR_DJI_C}\n"
"#define MOTOR_DM ${MOTOR_DM_C}\n"
"#define MOTOR_LK ${MOTOR_LK_C}\n\n"
"namespace config::feature {\n\n"
"inline constexpr bool hw_has_usb = ${HW_HAS_USB};\n"
"inline constexpr bool enable_usbx = ${ENABLE_USBX_C};\n"
"inline constexpr bool has_ahrs = ${HAS_AHRS};\n"
"inline constexpr bool has_remoter = ${HAS_REMOTER};\n"
"inline constexpr bool has_vt03 = ${HAS_VT03};\n"
"inline constexpr bool enable_dr16 = ${ENABLE_DR16};\n"
"inline constexpr bool enable_vt03 = ${ENABLE_VT03};\n"
"inline constexpr bool has_referee = ${HAS_REFEREE};\n"
"inline constexpr bool has_ui = ${HAS_UI};\n"
"inline constexpr bool has_led = ${HAS_LED};\n"
"inline constexpr bool has_pwm_tim3_ch4 = ${HAS_PWM_TIM3_CH4};\n"
"inline constexpr bool has_pwm_tim12_ch2 = ${HAS_PWM_TIM12_CH2};\n"
"inline constexpr bool has_motors = ${HAS_MOTORS};\n"
"inline constexpr bool motor_dji = ${MOTOR_DJI_C};\n"
"inline constexpr bool motor_dm = ${MOTOR_DM_C};\n"
"inline constexpr bool motor_lk = ${MOTOR_LK_C};\n\n"
"} // namespace config::feature\n\n"
"namespace bsp {\n"
"namespace can {\n\n"
"enum class bus_type : std::uint8_t { classic = 0, fd = 1 };\n"
"enum class id_type : std::uint8_t { standard = 0, extended = 1 };\n"
"enum class handle_id : std::uint8_t { none = 0, fdcan1, fdcan2, fdcan3 };\n"
"enum class bus : std::uint8_t { ${can_bus_enum_entries} };\n\n"
"struct bus_config\n"
"{\n"
"    bool enabled = false;\n"
"    handle_id handle = handle_id::none;\n"
"    bus_type type = bus_type::classic;\n"
"    id_type filter_id_type = id_type::standard;\n"
"};\n\n"
"inline constexpr std::size_t bus_count = ${can_bus_count};\n"
"inline constexpr std::size_t max_rx_callbacks = ${can_max_rx_callbacks};\n"
"inline constexpr std::uint32_t tx_delay_comp_tdc = ${tx_delay_tdc};\n"
"inline constexpr std::uint32_t tx_delay_comp_filter = ${tx_delay_filter};\n\n"
"inline constexpr std::array<bus_config, bus_count> configs = {{ ${can_config_cpp} }};\n"
"inline constexpr std::array<bool, bus_count> enabled = { ${can_enabled_cpp} };\n"
"inline constexpr std::array<bus_type, bus_count> configured_bus_types = { ${can_type_cpp} };\n"
"inline constexpr std::array<id_type, bus_count> filter_id_types = { ${can_id_type_cpp} };\n\n"
"} // namespace can\n\n"
"namespace spi {\n\n"
"enum class handle_id : std::uint8_t { none = 0, spi2, spi6 };\n\n"
"struct bus_config\n"
"{\n"
"    bool enabled = false;\n"
"    handle_id handle = handle_id::none;\n"
"};\n\n"
"inline constexpr std::size_t bus_count = ${spi_bus_count};\n"
"inline constexpr std::array<bus_config, bus_count> configs = {{ ${spi_config_cpp} }};\n\n"
"} // namespace spi\n\n"
"namespace pwm {\n\n"
"enum class timer_id : std::uint8_t { none = 0, tim3, tim12 };\n"
"enum class channel_id : std::uint8_t { none = 0, ch1, ch2, ch3, ch4 };\n\n"
"struct channel_config\n"
"{\n"
"    bool enabled = false;\n"
"    timer_id timer = timer_id::none;\n"
"    channel_id channel = channel_id::none;\n"
"    std::uint32_t timer_clock_hz = 0;\n"
"};\n\n"
"inline constexpr std::size_t channel_count = ${pwm_channel_count};\n"
"inline constexpr std::array<channel_config, channel_count> configs = {{ ${pwm_config_cpp} }};\n\n"
"} // namespace pwm\n\n"
"namespace usart {\n\n"
"using port = std::size_t;\n\n"
"enum class handle_id : std::uint8_t { none = 0, uart5, uart7, usart1 };\n\n"
"struct port_config\n"
"{\n"
"    bool enabled = false;\n"
"    handle_id handle = handle_id::none;\n"
"    bool has_rx_dma = false;\n"
"    bool has_tx_dma = false;\n"
"};\n\n"
"inline constexpr std::size_t port_count = ${usart_port_count};\n"
"inline constexpr std::array<port_config, port_count> configs = {{ ${usart_config_cpp} }};\n"
"inline constexpr std::array<bool, port_count> enabled = { ${usart_enabled_cpp} };\n\n"
"} // namespace usart\n"
"} // namespace bsp\n\n"
"namespace app {\n"
"namespace uart {\n\n"
"${uart_binding_body}\n\n"
"inline constexpr bsp::usart::port dr16 = ${dr16_binding};\n"
"inline constexpr bsp::usart::port vt03 = ${vt03_binding};\n"
"inline constexpr bsp::usart::port referee = ${referee_binding};\n"
"inline constexpr bsp::usart::port test_report = ${test_report_binding};\n\n"
"} // namespace uart\n"
"} // namespace app\n\n"
"namespace params::ahrs {\n"
"${params_ahrs_body}"
"} // namespace params::ahrs\n\n"
"namespace params::remoter {\n"
"${params_remoter_body}"
"} // namespace params::remoter\n\n"
"namespace params::referee {\n"
"${params_referee_body}"
"} // namespace params::referee\n\n"
"namespace params::test {\n"
"${params_test_body}"
"} // namespace params::test\n\n"
"namespace params::usb {\n"
"${params_usb_body}"
"} // namespace params::usb\n"
)
file(READ "${CONFIG_HPP}" config_hpp_raw)
string(REPLACE "${generated_semicolon_token}" ";" config_hpp_fixed "${config_hpp_raw}")
file(WRITE "${CONFIG_HPP}" "${config_hpp_fixed}")

message(STATUS "Generated ${CONFIG_HPP}")
