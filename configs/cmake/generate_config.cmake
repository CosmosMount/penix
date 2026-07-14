cmake_minimum_required(VERSION 3.22)

include(${CMAKE_CURRENT_LIST_DIR}/import_ioc.cmake)

if(NOT DEFINED IOC OR NOT DEFINED PARAMS OR NOT DEFINED OUT_DIR)
    message(FATAL_ERROR "generate_config.cmake requires -DIOC=... -DPARAMS=... -DOUT_DIR=...")
endif()

if(NOT DEFINED CACHE)
    set(CACHE "")
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
set(can_handles_list "")
set(can_bus_enum_entries "")
set(can_bus_index 0)

foreach(hw ${PNX_IOC_FDCAN_HW})
    string(TOLOWER "${hw}" hw_lower)

    list(APPEND can_enabled_list "true")

    pnx_ioc_fdcan_frame_format("${PNX_IOC_LINES}" "${hw_lower}" bus_type)
    if(bus_type STREQUAL "fd")
        list(APPEND can_type_list "bus_type::fd")
    else()
        list(APPEND can_type_list "bus_type::classic")
    endif()

    pnx_ioc_fdcan_ext_filters("${PNX_IOC_LINES}" "${hw_lower}" ext_filters)
    if(ext_filters GREATER 0)
        list(APPEND can_id_type_list "id_type::extended")
    else()
        list(APPEND can_id_type_list "id_type::standard")
    endif()

    pnx_hw_to_handle("${hw_lower}" handle_expr)
    list(APPEND can_handles_list "${handle_expr}")

    if(can_bus_index GREATER 0)
        string(APPEND can_bus_enum_entries ", ")
    endif()
    string(APPEND can_bus_enum_entries "${hw_lower} = ${can_bus_index}")
    math(EXPR can_bus_index "${can_bus_index} + 1")
endforeach()

list(JOIN can_enabled_list ", " can_enabled_cpp)
list(JOIN can_type_list ", " can_type_cpp)
list(JOIN can_id_type_list ", " can_id_type_cpp)
list(JOIN can_handles_list ", " can_handles_cpp)
list(LENGTH PNX_IOC_FDCAN_HW can_bus_count)

set(usart_enabled_list "")
set(usart_handles_list "")
set(usart_setup_dma_body "")
set(usart_port_enum_entries "")
set(uart_binding_body "")
set(dma_extern_block "")
set(usart_port_index 0)

foreach(hw ${PNX_IOC_UART_HW})
    string(TOLOWER "${hw}" hw_lower)

    list(APPEND usart_enabled_list "true")

    pnx_hw_to_handle("${hw_lower}" handle_expr)
    list(APPEND usart_handles_list "${handle_expr}")

    pnx_ioc_uart_has_dma("${PNX_IOC_LINES}" "${hw_lower}" "RX" has_rx_dma)
    pnx_ioc_uart_has_dma("${PNX_IOC_LINES}" "${hw_lower}" "TX" has_tx_dma)

    string(APPEND usart_setup_dma_body "    if (handle == ${handle_expr}) {\n")
    if(has_rx_dma)
        pnx_hw_to_dma_handle("${hw_lower}" "rx" rx_dma_expr)
        string(APPEND dma_extern_block "extern DMA_HandleTypeDef hdma_${hw_lower}_rx;\n")
        string(APPEND usart_setup_dma_body "        __HAL_DMA_DISABLE_IT(${rx_dma_expr}, DMA_IT_HT);\n")
        string(APPEND usart_setup_dma_body "        __HAL_DMA_ENABLE_IT(${rx_dma_expr}, DMA_IT_TC);\n")
    endif()
    if(has_tx_dma)
        pnx_hw_to_dma_handle("${hw_lower}" "tx" tx_dma_expr)
        string(APPEND dma_extern_block "extern DMA_HandleTypeDef hdma_${hw_lower}_tx;\n")
        string(APPEND usart_setup_dma_body "        __HAL_DMA_DISABLE_IT(${tx_dma_expr}, DMA_IT_HT);\n")
        string(APPEND usart_setup_dma_body "        __HAL_DMA_ENABLE_IT(${tx_dma_expr}, DMA_IT_TC);\n")
    endif()
    string(APPEND usart_setup_dma_body "        return;\n    }\n")

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
list(JOIN usart_handles_list ", " usart_handles_cpp)
list(LENGTH PNX_IOC_UART_HW usart_port_count)

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
        "  inline constexpr std::uint32_t write_thread_priority = 11${generated_semicolon_token}\n"
        "  inline constexpr std::uint32_t period_ticks = 2${generated_semicolon_token}\n")
endif()

# --- gate API ---
set(gate_api_body "")
if(HAS_AHRS)
    string(APPEND gate_api_body
"inline auto& ahrs() { return ::ahrs::service::instance(); }\n")
else()
    string(APPEND gate_api_body
"struct ahrs_unavailable {};\n"
"template<typename T = void>\n"
"ahrs_unavailable ahrs() {\n"
"    static_assert(HAS_AHRS, \"ahrs unavailable: SPI2 not enabled in board/board.ioc\");\n"
"    return {};\n"
"}\n")
endif()

if(HAS_REMOTER)
    string(APPEND gate_api_body
"inline auto& remoter() { return ::remoter::dr16::instance(); }\n")
else()
    string(APPEND gate_api_body
"struct remoter_unavailable {};\n"
"template<typename T = void>\n"
"remoter_unavailable remoter() {\n"
"    static_assert(HAS_REMOTER, \"remoter unavailable: remoter UART missing or lacks RX DMA in board/board.ioc\");\n"
"    return {};\n"
"}\n")
endif()

if(HAS_VT03)
    string(APPEND gate_api_body
"inline auto& vt03() { return ::remoter::vt03::instance(); }\n")
else()
    string(APPEND gate_api_body
"struct vt03_unavailable {};\n"
"template<typename T = void>\n"
"vt03_unavailable vt03() {\n"
"    static_assert(HAS_VT03, \"vt03 unavailable: UART7 missing or lacks RX DMA in board/board.ioc\");\n"
"    return {};\n"
"}\n")
endif()

if(HAS_REFEREE)
    string(APPEND gate_api_body
"inline auto& referee() { return ::referee::service::instance(); }\n")
else()
    string(APPEND gate_api_body
"struct referee_unavailable {};\n"
"template<typename T = void>\n"
"referee_unavailable referee() {\n"
"    static_assert(HAS_REFEREE, \"referee unavailable: referee UART not enabled in board/board.ioc\");\n"
"    return {};\n"
"}\n")
endif()

if(HAS_UI)
    string(APPEND gate_api_body
"inline auto& ui() { return ::ui::canvas::instance(); }\n")
else()
    string(APPEND gate_api_body
"struct ui_unavailable {};\n"
"template<typename T = void>\n"
"ui_unavailable ui() {\n"
"    static_assert(HAS_UI, \"ui unavailable: referee UART not enabled in board/board.ioc\");\n"
"    return {};\n"
"}\n")
endif()

# --- modules.hpp ---
set(modules_includes "#pragma once\n// Generated from IOC + params.json. Do not edit.\n\n")
string(APPEND modules_includes "#include \"messages.hpp\"\n#include \"msg.hpp\"\n")
if(HAS_AHRS)
    string(APPEND modules_includes "#include \"ahrs.hpp\"\n")
endif()
if(HAS_REMOTER)
    string(APPEND modules_includes "#include \"dr16.hpp\"\n")
endif()
if(HAS_VT03)
    string(APPEND modules_includes "#include \"vt03.hpp\"\n")
endif()
if(HAS_REFEREE)
    string(APPEND modules_includes "#include \"referee.hpp\"\n")
endif()
if(HAS_UI)
    string(APPEND modules_includes "#include \"ui.hpp\"\n")
endif()
if(HAS_LED)
    string(APPEND modules_includes "#include \"led.hpp\"\n")
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
set(CONFIG_CAN_TABLES_CPP "${OUT_DIR}/config_can_tables.cpp")
set(CONFIG_USART_TABLES_CPP "${OUT_DIR}/config_usart_tables.cpp")
set(MODULES_HPP "${OUT_DIR}/modules.hpp")
set(APP_GATE_HPP "${OUT_DIR}/app_gate.hpp")

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
"namespace bsp {\n"
"namespace can {\n\n"
"enum class bus_type : std::uint8_t { classic = 0, fd = 1 };\n"
"enum class id_type : std::uint8_t { standard = 0, extended = 1 };\n"
"enum class bus : std::uint8_t { ${can_bus_enum_entries} };\n\n"
"inline constexpr std::size_t bus_count = ${can_bus_count};\n"
"inline constexpr std::size_t max_rx_callbacks = ${can_max_rx_callbacks};\n"
"inline constexpr std::uint32_t tx_delay_comp_tdc = ${tx_delay_tdc};\n"
"inline constexpr std::uint32_t tx_delay_comp_filter = ${tx_delay_filter};\n\n"
"inline constexpr std::array<bool, bus_count> enabled = { ${can_enabled_cpp} };\n"
"inline constexpr std::array<bus_type, bus_count> configured_bus_types = { ${can_type_cpp} };\n"
"inline constexpr std::array<id_type, bus_count> filter_id_types = { ${can_id_type_cpp} };\n\n"
"inline constexpr bool bus_enabled(std::size_t i) { return i < bus_count && enabled[i]; }\n"
"inline constexpr bus_type configured_bus_type(std::size_t i) { return i < bus_count ? configured_bus_types[i] : bus_type::classic; }\n"
"inline constexpr id_type filter_id_type_of(std::size_t i) { return i < bus_count ? filter_id_types[i] : id_type::standard; }\n\n"
"} // namespace can\n\n"
"namespace usart {\n\n"
"using port = std::size_t;\n\n"
"inline constexpr std::size_t port_count = ${usart_port_count};\n"
"inline constexpr std::array<bool, port_count> enabled = { ${usart_enabled_cpp} };\n\n"
"inline constexpr bool port_enabled(std::size_t i) { return i < port_count && enabled[i]; }\n\n"
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

file(WRITE "${APP_GATE_HPP}"
"#pragma once\n"
"// Generated from board/board.ioc + config/params.json. Do not edit.\n\n"
"#include \"config.hpp\"\n"
"#include \"modules.hpp\"\n\n"
"namespace app {\n\n"
"${gate_api_body}"
"} // namespace app\n"
)

file(WRITE "${CONFIG_CAN_TABLES_CPP}"
"#include \"bsp_can.hpp\"\n\n"
"namespace bsp {\n"
"namespace can {\n\n"
"static FDCAN_HandleTypeDef* const handles[bus_count] = { ${can_handles_cpp} };\n\n"
"FDCAN_HandleTypeDef* handle_of(bus b) noexcept\n"
"{\n"
"    const auto idx = static_cast<std::size_t>(b);\n"
"    return idx < bus_count ? handles[idx] : nullptr;\n"
"}\n\n"
"bus bus_of(FDCAN_HandleTypeDef* handle) noexcept\n"
"{\n"
"    for (std::size_t i = 0; i < bus_count; ++i)\n"
"    {\n"
"        if (handles[i] == handle)\n"
"        {\n"
"            return static_cast<bus>(i);\n"
"        }\n"
"    }\n"
"    return static_cast<bus>(0);\n"
"}\n\n"
"} // namespace can\n"
"} // namespace bsp\n"
)

file(WRITE "${CONFIG_USART_TABLES_CPP}"
"#include \"bsp_usart.hpp\"\n\n"
"extern \"C\" {\n"
"${dma_extern_block}"
"}\n\n"
"namespace bsp {\n"
"namespace usart {\n\n"
"static UART_HandleTypeDef* const handles[port_count] = { ${usart_handles_cpp} };\n\n"
"UART_HandleTypeDef* handle_of(std::size_t index) noexcept\n"
"{\n"
"    return index < port_count ? handles[index] : nullptr;\n"
"}\n\n"
"std::size_t index_of(UART_HandleTypeDef* handle) noexcept\n"
"{\n"
"    for (std::size_t i = 0; i < port_count; ++i)\n"
"    {\n"
"        if (handles[i] == handle)\n"
"        {\n"
"            return i;\n"
"        }\n"
"    }\n"
"    return port_count;\n"
"}\n\n"
"void setup_dma(UART_HandleTypeDef* handle) noexcept\n"
"{\n"
"${usart_setup_dma_body}"
"}\n\n"
"} // namespace usart\n"
"} // namespace bsp\n"
)

file(WRITE "${MODULES_HPP}" "${modules_includes}")

if(CACHE)
    get_filename_component(cache_dir "${CACHE}" DIRECTORY)
    if(NOT cache_dir STREQUAL "")
        file(MAKE_DIRECTORY "${cache_dir}")
    endif()
    file(WRITE "${CACHE}"
        "# Generated from template.ioc + config/params.json. Do not edit.\n"
        "set(HAS_AHRS ${HAS_AHRS})\n"
        "set(HAS_REMOTER ${HAS_REMOTER})\n"
        "set(HAS_VT03 ${HAS_VT03})\n"
        "set(ENABLE_DR16 ${ENABLE_DR16})\n"
        "set(ENABLE_VT03 ${ENABLE_VT03})\n"
        "set(HAS_REFEREE ${HAS_REFEREE})\n"
        "set(HAS_UI ${HAS_UI})\n"
        "set(HAS_LED ${HAS_LED})\n"
        "set(HAS_PWM_TIM3_CH4 ${HAS_PWM_TIM3_CH4})\n"
        "set(HAS_PWM_TIM12_CH2 ${HAS_PWM_TIM12_CH2})\n"
        "set(HAS_MOTORS ${HAS_MOTORS})\n"
        "set(HW_HAS_USB ${HW_HAS_USB})\n"
        "set(ENABLE_USBX ${ENABLE_USBX})\n"
        "set(MOTOR_DJI ${MOTOR_DJI})\n"
        "set(MOTOR_DM ${MOTOR_DM})\n"
        "set(MOTOR_LK ${MOTOR_LK})\n"
    )
endif()

message(STATUS "Generated ${CONFIG_HPP}")
message(STATUS "Generated ${CONFIG_CAN_TABLES_CPP}")
message(STATUS "Generated ${CONFIG_USART_TABLES_CPP}")
message(STATUS "Generated ${MODULES_HPP}")
message(STATUS "Generated ${APP_GATE_HPP}")
if(CACHE)
    message(STATUS "Generated ${CACHE}")
endif()
