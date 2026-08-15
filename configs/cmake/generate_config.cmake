cmake_minimum_required(VERSION 3.22)

include(${CMAKE_CURRENT_LIST_DIR}/import_ioc.cmake)

if(NOT DEFINED IOC OR NOT DEFINED CONFIG OR NOT DEFINED OUT_DIR)
    message(FATAL_ERROR "generate_config.cmake requires -DIOC=... -DCONFIG=... -DOUT_DIR=...")
endif()

pnx_ioc_parse("${IOC}")

file(READ "${CONFIG}" params_json)
set(robot_json "")
string(JSON robot_json ERROR_VARIABLE json_err GET "${params_json}" robot)
if(json_err OR robot_json STREQUAL "null")
    set(robot_json "")
endif()
set(generated_semicolon_token "__PNX_GENERATED_SEMICOLON__")

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

function(_pnx_can_id_type_expr val out_var)
    string(TOLOWER "${val}" val_lower)
    if(val_lower STREQUAL "standard" OR val_lower STREQUAL "std")
        set(${out_var} "id_type::standard" PARENT_SCOPE)
    elseif(val_lower STREQUAL "extended" OR val_lower STREQUAL "ext")
        set(${out_var} "id_type::extended" PARENT_SCOPE)
    else()
        message(FATAL_ERROR "can id_type must be standard or extended")
    endif()
endfunction()

function(_pnx_cpp_identifier input out_var)
    string(REGEX REPLACE "[^A-Za-z0-9_]" "_" ident "${input}")
    string(REGEX REPLACE "_+" "_" ident "${ident}")
    string(REGEX REPLACE "^_+|_+$" "" ident "${ident}")
    if(ident STREQUAL "")
        set(ident "unnamed")
    endif()
    if(ident MATCHES "^[0-9]")
        set(ident "_${ident}")
    endif()
    set(${out_var} "${ident}" PARENT_SCOPE)
endfunction()

_pnx_json_bool_to_cmake("${motor_dji}" MOTOR_DJI)
_pnx_json_bool_to_cmake("${motor_dm}" MOTOR_DM)
_pnx_json_bool_to_cmake("${motor_lk}" MOTOR_LK)

# --- robot.json: optional DMIMU build switch ---
# Absence of devices.dmimu, or absence/false value of its enabled member,
# deliberately disables DMIMU. This keeps legacy robot files opt-in.
set(HAS_DMIMU 0)
if(NOT robot_json STREQUAL "")
    string(JSON robot_dmimu_type ERROR_VARIABLE json_err TYPE "${robot_json}" devices dmimu)
    if(NOT json_err)
        if(NOT robot_dmimu_type STREQUAL "OBJECT")
            message(FATAL_ERROR "robot devices.dmimu must be an object")
        endif()
        string(JSON robot_dmimu_enabled_type ERROR_VARIABLE json_err TYPE "${robot_json}" devices dmimu enabled)
        if(NOT json_err AND NOT robot_dmimu_enabled_type STREQUAL "BOOLEAN")
            message(FATAL_ERROR "robot devices.dmimu.enabled must be a boolean")
        endif()
        string(JSON robot_dmimu_enabled ERROR_VARIABLE json_err GET "${robot_json}" devices dmimu enabled)
        if(NOT json_err)
            _pnx_json_bool_to_cmake("${robot_dmimu_enabled}" robot_dmimu_enabled_cmake)
            if(robot_dmimu_enabled_cmake)
                set(HAS_DMIMU 1)
            endif()
        endif()
    endif()
endif()

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

set(gpio_input_config_list "")
set(gpio_input_enum_entries "")
set(gpio_input_binding_body "")
set(gpio_output_config_list "")
set(gpio_output_enum_entries "")
set(gpio_output_binding_body "")

string(JSON gpio_input_count ERROR_VARIABLE json_err LENGTH "${params_json}" bindings gpio_inputs)
if(json_err)
    set(gpio_input_count 0)
endif()
if(gpio_input_count GREATER 0)
    math(EXPR gpio_input_last "${gpio_input_count} - 1")
    foreach(index RANGE 0 ${gpio_input_last})
        string(JSON role MEMBER "${params_json}" bindings gpio_inputs ${index})
        _pnx_cpp_identifier("${role}" role_ident)
        if(NOT role_ident STREQUAL role)
            message(FATAL_ERROR "GPIO input role '${role}' must be a C++ identifier")
        endif()
        string(JSON pin GET "${params_json}" bindings gpio_inputs ${role} pin)
        string(JSON active_level GET "${params_json}" bindings gpio_inputs ${role} active_level)
        string(TOLOWER "${pin}" pin)
        string(TOLOWER "${active_level}" active_level)
        if(NOT pin MATCHES "^p([a-k])([0-9]|1[0-5])$")
            message(FATAL_ERROR "GPIO input role '${role}' has invalid pin '${pin}'")
        endif()
        set(port "${CMAKE_MATCH_1}")
        set(pin_number "${CMAKE_MATCH_2}")
        if(NOT active_level STREQUAL "low" AND NOT active_level STREQUAL "high")
            message(FATAL_ERROR "GPIO input role '${role}' active_level must be low or high")
        endif()
        string(TOUPPER "${pin}" pin_upper)
        pnx_ioc_get_value("${PNX_IOC_LINES}" "${pin_upper}.Signal" signal)
        if(NOT signal STREQUAL "GPIO_Input" AND NOT signal MATCHES "^GPXTI[0-9]+$")
            message(FATAL_ERROR "GPIO input role '${role}' pin ${pin} is not an IOC input")
        endif()
        list(APPEND gpio_input_config_list
            "{ port_id::${port}, ${pin_number}U, active_level::${active_level} }")
        if(NOT gpio_input_enum_entries STREQUAL "")
            string(APPEND gpio_input_enum_entries ", ")
        endif()
        string(APPEND gpio_input_enum_entries "${role_ident} = ${index}")
        string(APPEND gpio_input_binding_body
            "inline constexpr bsp::gpio::input ${role_ident} = bsp::gpio::input::${role_ident}${generated_semicolon_token}\n")
    endforeach()
endif()

string(JSON gpio_output_count ERROR_VARIABLE json_err LENGTH "${params_json}" bindings gpio_outputs)
if(json_err)
    set(gpio_output_count 0)
endif()
if(gpio_output_count GREATER 0)
    math(EXPR gpio_output_last "${gpio_output_count} - 1")
    foreach(index RANGE 0 ${gpio_output_last})
        string(JSON role MEMBER "${params_json}" bindings gpio_outputs ${index})
        _pnx_cpp_identifier("${role}" role_ident)
        if(NOT role_ident STREQUAL role)
            message(FATAL_ERROR "GPIO output role '${role}' must be a C++ identifier")
        endif()
        string(JSON pin GET "${params_json}" bindings gpio_outputs ${role} pin)
        string(JSON active_level GET "${params_json}" bindings gpio_outputs ${role} active_level)
        string(TOLOWER "${pin}" pin)
        string(TOLOWER "${active_level}" active_level)
        if(NOT pin MATCHES "^p([a-k])([0-9]|1[0-5])$")
            message(FATAL_ERROR "GPIO output role '${role}' has invalid pin '${pin}'")
        endif()
        set(port "${CMAKE_MATCH_1}")
        set(pin_number "${CMAKE_MATCH_2}")
        if(NOT active_level STREQUAL "low" AND NOT active_level STREQUAL "high")
            message(FATAL_ERROR "GPIO output role '${role}' active_level must be low or high")
        endif()
        string(TOUPPER "${pin}" pin_upper)
        pnx_ioc_get_value("${PNX_IOC_LINES}" "${pin_upper}.Signal" signal)
        if(NOT signal STREQUAL "GPIO_Output")
            message(FATAL_ERROR "GPIO output role '${role}' pin ${pin} is not an IOC output")
        endif()
        list(APPEND gpio_output_config_list
            "{ port_id::${port}, ${pin_number}U, active_level::${active_level} }")
        if(NOT gpio_output_enum_entries STREQUAL "")
            string(APPEND gpio_output_enum_entries ", ")
        endif()
        string(APPEND gpio_output_enum_entries "${role_ident} = ${index}")
        string(APPEND gpio_output_binding_body
            "inline constexpr bsp::gpio::output ${role_ident} = bsp::gpio::output::${role_ident}${generated_semicolon_token}\n")
    endforeach()
endif()
list(JOIN gpio_input_config_list ", " gpio_input_config_cpp)
list(JOIN gpio_output_config_list ", " gpio_output_config_cpp)

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

pnx_ioc_hw_in_list("${PNX_IOC_UART_HW}" "${remoter_uart}" remoter_uart_present)
pnx_ioc_uart_has_dma("${PNX_IOC_LINES}" "${remoter_uart}" "RX" remoter_has_rx_dma)
if(remoter_uart_present AND remoter_has_rx_dma)
    set(HAS_REMOTER 1)
else()
    set(HAS_REMOTER 0)
endif()
set(HAS_PS2 ${HAS_REMOTER})

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

if(remoter_source STREQUAL "" OR remoter_source STREQUAL "none")
    if(HAS_REMOTER)
        set(ENABLE_DR16 1)
        set(ENABLE_VT03 0)
        set(ENABLE_PS2 0)
    elseif(HAS_VT03)
        set(ENABLE_DR16 0)
        set(ENABLE_VT03 1)
        set(ENABLE_PS2 0)
    else()
        set(ENABLE_DR16 0)
        set(ENABLE_VT03 0)
        set(ENABLE_PS2 0)
    endif()
elseif(remoter_source STREQUAL "dr16")
    if(NOT HAS_REMOTER)
        message(FATAL_ERROR "params.remoter.source=dr16 requires remoter UART RX DMA support in ${IOC}")
    endif()
    set(ENABLE_DR16 1)
    set(ENABLE_VT03 0)
    set(ENABLE_PS2 0)
elseif(remoter_source STREQUAL "vt03")
    if(NOT HAS_VT03)
        message(FATAL_ERROR "params.remoter.source=vt03 requires UART7 RX DMA support in ${IOC}")
    endif()
    set(ENABLE_DR16 0)
    set(ENABLE_VT03 1)
    set(ENABLE_PS2 0)
elseif(remoter_source STREQUAL "ps2")
    if(NOT HAS_PS2)
        message(FATAL_ERROR "params.remoter.source=ps2 requires the bound remoter UART to have RX DMA support in ${IOC}")
    endif()
    set(ENABLE_DR16 0)
    set(ENABLE_VT03 0)
    set(ENABLE_PS2 1)
else()
    message(FATAL_ERROR "params.remoter.source must be one of: dr16, vt03, ps2")
endif()

list(LENGTH PNX_IOC_FDCAN_HW fdcan_count)
if(fdcan_count GREATER 0)
    set(HAS_MOTORS 1)
else()
    set(HAS_MOTORS 0)
endif()

string(JSON can_diag_enabled ERROR_VARIABLE json_err GET "${params_json}" can_diag enabled)
if(json_err OR can_diag_enabled STREQUAL "")
    set(can_diag_enabled "true")
endif()
if(can_diag_enabled STREQUAL "true" OR can_diag_enabled STREQUAL "1" OR can_diag_enabled STREQUAL "ON")
    set(CAN_DIAG_ENABLED 1)
else()
    set(CAN_DIAG_ENABLED 0)
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

    string(JSON manual_can_id_type ERROR_VARIABLE json_err GET "${params_json}" can ${hw_lower} id_type)
    if(NOT json_err AND NOT manual_can_id_type STREQUAL "")
        _pnx_can_id_type_expr("${manual_can_id_type}" can_id_type_expr)
    else()
        pnx_ioc_fdcan_std_filters("${PNX_IOC_LINES}" "${hw_lower}" std_filters)
        pnx_ioc_fdcan_ext_filters("${PNX_IOC_LINES}" "${hw_lower}" ext_filters)
        if(std_filters GREATER 0)
            set(can_id_type_expr "id_type::standard")
        elseif(ext_filters GREATER 0)
            set(can_id_type_expr "id_type::extended")
        else()
            set(can_id_type_expr "id_type::standard")
        endif()
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

set(pwm_channel_config_list "")
set(pwm_channel_enum_entries "")
set(pwm_feature_macros "")
set(pwm_feature_constants "")
set(pwm_binding_cases "")
set(pwm_channel_index 0)
foreach(resource ${PNX_IOC_PWM_CHANNELS})
    if(NOT resource MATCHES "^(TIM[0-9]+)_CH([1-4])$")
        message(FATAL_ERROR "Invalid discovered PWM resource ${resource}")
    endif()
    set(timer "${CMAKE_MATCH_1}")
    set(channel_number "${CMAKE_MATCH_2}")
    string(TOLOWER "${resource}" channel_ident)
    string(TOLOWER "${timer}" timer_lower)
    pnx_ioc_timer_clock_hz("${PNX_IOC_LINES}" "${timer}" timer_clock_hz)
    list(APPEND pwm_channel_config_list "{ ${timer_clock_hz}U }")
    if(NOT pwm_channel_enum_entries STREQUAL "")
        string(APPEND pwm_channel_enum_entries ", ")
    endif()
    string(APPEND pwm_channel_enum_entries "${channel_ident} = ${pwm_channel_index}")
    string(APPEND pwm_feature_macros "#define HAS_PWM_${resource} 1\n")
    string(APPEND pwm_feature_constants
        "inline constexpr bool has_pwm_${channel_ident} = true${generated_semicolon_token}\n")
    string(APPEND pwm_binding_cases
        "    case channel::${channel_ident}: out = { &h${timer_lower}, TIM_CHANNEL_${channel_number} }${generated_semicolon_token} return true${generated_semicolon_token}\n")
    math(EXPR pwm_channel_index "${pwm_channel_index} + 1")
endforeach()
list(JOIN pwm_channel_config_list ", " pwm_config_cpp)
list(LENGTH PNX_IOC_PWM_CHANNELS pwm_channel_count)

set(pwm_app_binding_body "")
string(JSON pwm_app_binding_count ERROR_VARIABLE json_err LENGTH "${params_json}" bindings pwm_channels)
if(json_err)
    set(pwm_app_binding_count 0)
endif()
if(pwm_app_binding_count GREATER 0)
    math(EXPR pwm_app_binding_last "${pwm_app_binding_count} - 1")
    foreach(index RANGE 0 ${pwm_app_binding_last})
        string(JSON role MEMBER "${params_json}" bindings pwm_channels ${index})
        _pnx_cpp_identifier("${role}" role_ident)
        if(NOT role_ident STREQUAL role)
            message(FATAL_ERROR "PWM role '${role}' must be a C++ identifier")
        endif()
        string(JSON timer GET "${params_json}" bindings pwm_channels ${role} timer)
        string(JSON channel_number GET "${params_json}" bindings pwm_channels ${role} channel)
        string(TOUPPER "${timer}" timer)
        set(resource "${timer}_CH${channel_number}")
        list(FIND PNX_IOC_PWM_CHANNELS "${resource}" resource_index)
        if(resource_index LESS 0)
            message(FATAL_ERROR "PWM role '${role}' uses ${resource}, which is not configured for PWM in the IOC")
        endif()
        string(TOLOWER "${resource}" channel_ident)
        string(APPEND pwm_app_binding_body
            "inline constexpr bsp::pwm::channel ${role_ident} = bsp::pwm::channel::${channel_ident}${generated_semicolon_token}\n")
    endforeach()
endif()

set(adc_channel_enum_entries "")
set(adc_binding_cases "")
set(adc_channel_index 0)
foreach(entry ${PNX_IOC_ADC_BLOCKING_CHANNELS})
    if(NOT entry MATCHES "^(ADC[0-9]+)_CH([0-9]+)\\|([^|]+)\\|([^|]+)$")
        message(FATAL_ERROR "Invalid discovered ADC blocking channel ${entry}")
    endif()
    set(adc "${CMAKE_MATCH_1}")
    set(adc_channel_number "${CMAKE_MATCH_2}")
    set(adc_rank "${CMAKE_MATCH_3}")
    set(adc_sampling_time "${CMAKE_MATCH_4}")
    string(TOLOWER "${adc}_ch${adc_channel_number}" adc_channel_ident)
    string(TOLOWER "${adc}" adc_lower)
    if(NOT adc_channel_enum_entries STREQUAL "")
        string(APPEND adc_channel_enum_entries ", ")
    endif()
    string(APPEND adc_channel_enum_entries "${adc_channel_ident} = ${adc_channel_index}")
    string(APPEND adc_binding_cases
        "    case channel::${adc_channel_ident}: out = { &h${adc_lower}, ADC_CHANNEL_${adc_channel_number}, ${adc_rank}, ${adc_sampling_time} }${generated_semicolon_token} return true${generated_semicolon_token}\n")
    math(EXPR adc_channel_index "${adc_channel_index} + 1")
endforeach()
list(LENGTH PNX_IOC_ADC_BLOCKING_CHANNELS adc_channel_count)

set(adc_app_binding_body "")
string(JSON adc_app_binding_count ERROR_VARIABLE json_err LENGTH "${params_json}" bindings adc_channels)
if(json_err)
    set(adc_app_binding_count 0)
endif()
if(adc_app_binding_count GREATER 0)
    math(EXPR adc_app_binding_last "${adc_app_binding_count} - 1")
    foreach(index RANGE 0 ${adc_app_binding_last})
        string(JSON role MEMBER "${params_json}" bindings adc_channels ${index})
        _pnx_cpp_identifier("${role}" role_ident)
        if(NOT role_ident STREQUAL role)
            message(FATAL_ERROR "ADC role '${role}' must be a C++ identifier")
        endif()
        string(JSON adc GET "${params_json}" bindings adc_channels ${role} adc)
        string(JSON adc_channel_number GET "${params_json}" bindings adc_channels ${role} channel)
        string(TOUPPER "${adc}" adc)
        set(resource "${adc}_CH${adc_channel_number}")
        set(resource_found FALSE)
        foreach(entry ${PNX_IOC_ADC_BLOCKING_CHANNELS})
            if(entry MATCHES "^${resource}\\|")
                set(resource_found TRUE)
            endif()
        endforeach()
        if(NOT resource_found)
            message(FATAL_ERROR
                "ADC role '${role}' uses ${resource}, which is not an IOC single regular conversion")
        endif()
        string(TOLOWER "${resource}" adc_channel_ident)
        string(APPEND adc_app_binding_body
            "inline constexpr bsp::adc::channel ${role_ident} = bsp::adc::channel::${adc_channel_ident}${generated_semicolon_token}\n")
    endforeach()
endif()

pnx_ioc_uart_index("${PNX_IOC_UART_HW}" "${remoter_uart}" dr16_port_idx)
pnx_ioc_uart_index("${PNX_IOC_UART_HW}" "${remoter_uart}" ps2_port_idx)
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
if(ps2_port_idx GREATER_EQUAL 0)
    set(ps2_binding "${remoter_uart}")
else()
    set(ps2_binding "0")
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
elseif(ENABLE_PS2)
    set(active_remoter_uart "${remoter_uart}")
endif()

string(JSON test_report_uart ERROR_VARIABLE json_err GET "${params_json}" test report_uart)
if(json_err)
    set(test_report_uart "uart7")
endif()
string(TOLOWER "${test_report_uart}" test_report_uart)
pnx_ioc_uart_index("${PNX_IOC_UART_HW}" "${test_report_uart}" test_report_port_idx)
if(test_report_port_idx LESS 0)
    message(FATAL_ERROR "params.test.report_uart=${test_report_uart} is not present in ${IOC}")
endif()
if(NOT active_remoter_uart STREQUAL "" AND test_report_uart STREQUAL active_remoter_uart)
    message(FATAL_ERROR "params.test.report_uart=${test_report_uart} conflicts with the active remoter UART")
endif()
set(test_report_binding "${test_report_uart}")

# --- params namespace (explicit keys per section) ---
function(_pnx_param_float section key out_var)
    string(JSON val ERROR_VARIABLE err GET "${params_json}" ${section} ${key})
    if(err)
        set(${out_var} "" PARENT_SCOPE)
        return()
    endif()
    if(val MATCHES "[.eE]")
        set(literal "${val}f")
    else()
        set(literal "${val}.0f")
    endif()
    set(${out_var} "  inline constexpr float ${key} = ${literal}${generated_semicolon_token}\n" PARENT_SCOPE)
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

string(JSON params_dmimu_mode ERROR_VARIABLE json_err GET "${params_json}" dmimu communication_mode)
if(json_err OR params_dmimu_mode STREQUAL "")
    set(params_dmimu_mode "active")
endif()
string(TOLOWER "${params_dmimu_mode}" params_dmimu_mode_lower)
if(params_dmimu_mode_lower STREQUAL "active")
    set(params_dmimu_mode_expr "communication_mode::active")
elseif(params_dmimu_mode_lower STREQUAL "request")
    set(params_dmimu_mode_expr "communication_mode::request")
else()
    message(FATAL_ERROR "params.dmimu.communication_mode must be active or request")
endif()

string(JSON params_dmimu_offline_timeout ERROR_VARIABLE json_err GET "${params_json}" dmimu offline_timeout_ticks)
if(json_err OR params_dmimu_offline_timeout STREQUAL "")
    set(params_dmimu_offline_timeout 100)
endif()
string(JSON params_dmimu_thread_priority ERROR_VARIABLE json_err GET "${params_json}" dmimu thread_priority)
if(json_err OR params_dmimu_thread_priority STREQUAL "")
    set(params_dmimu_thread_priority 3)
endif()
string(JSON params_dmimu_receive_wait ERROR_VARIABLE json_err GET "${params_json}" dmimu receive_wait_ticks)
if(json_err OR params_dmimu_receive_wait STREQUAL "")
    set(params_dmimu_receive_wait 1)
endif()
string(JSON params_dmimu_request_period ERROR_VARIABLE json_err GET "${params_json}" dmimu request_period_ticks)
if(json_err OR params_dmimu_request_period STREQUAL "")
    set(params_dmimu_request_period 1)
endif()
if(params_dmimu_offline_timeout LESS 1 OR params_dmimu_receive_wait LESS 1)
    message(FATAL_ERROR "params.dmimu offline_timeout_ticks and receive_wait_ticks must be greater than zero")
endif()
if(params_dmimu_mode_lower STREQUAL "request" AND params_dmimu_request_period LESS 1)
    message(FATAL_ERROR "params.dmimu.request_period_ticks must be greater than zero in request mode")
endif()
string(CONCAT params_dmimu_body
    "enum class communication_mode : std::uint8_t { request = 0, active }${generated_semicolon_token}\n"
    "inline constexpr communication_mode mode = ${params_dmimu_mode_expr}${generated_semicolon_token}\n"
    "inline constexpr std::uint32_t offline_timeout_ticks = ${params_dmimu_offline_timeout}U${generated_semicolon_token}\n"
    "inline constexpr std::uint32_t thread_priority = ${params_dmimu_thread_priority}U${generated_semicolon_token}\n"
    "inline constexpr std::uint32_t receive_wait_ticks = ${params_dmimu_receive_wait}U${generated_semicolon_token}\n"
    "inline constexpr std::uint32_t request_period_ticks = ${params_dmimu_request_period}U${generated_semicolon_token}\n")

set(params_remoter_body "")
_pnx_param_uint("remoter" "thread_priority" _line)
if(_line STREQUAL "")
    set(_line "  inline constexpr std::uint32_t thread_priority = 2${generated_semicolon_token}\n")
endif()
string(APPEND params_remoter_body "${_line}")
_pnx_param_uint("remoter" "rx_timeout_ticks" _line)
if(_line STREQUAL "")
    set(_line "  inline constexpr std::uint32_t rx_timeout_ticks = 100${generated_semicolon_token}\n")
endif()
string(APPEND params_remoter_body "${_line}")
_pnx_param_uint("remoter" "ps2_offline_timeout_ticks" _line)
if(_line STREQUAL "")
    set(_line "  inline constexpr std::uint32_t ps2_offline_timeout_ticks = 600${generated_semicolon_token}\n")
endif()
string(APPEND params_remoter_body "${_line}")
_pnx_param_uint("remoter" "ps2_frame_timeout_ticks" _line)
if(_line STREQUAL "")
    set(_line "  inline constexpr std::uint32_t ps2_frame_timeout_ticks = 20${generated_semicolon_token}\n")
endif()
string(APPEND params_remoter_body "${_line}")
_pnx_param_float("remoter" "ps2_deadzone" _line)
if(_line STREQUAL "")
    set(_line "  inline constexpr float ps2_deadzone = 0.08f${generated_semicolon_token}\n")
endif()
string(APPEND params_remoter_body "${_line}")

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

set(params_can_diag_body "")
_pnx_param_uint("can_diag" "sample_period_ms" _line)
if(_line STREQUAL "")
    set(_line "  inline constexpr std::uint32_t sample_period_ms = 1000${generated_semicolon_token}\n")
endif()
string(APPEND params_can_diag_body "${_line}")

_pnx_param_uint("can_diag" "window_size" _line)
if(_line STREQUAL "")
    set(_line "  inline constexpr std::uint32_t window_size = 60${generated_semicolon_token}\n")
endif()
string(APPEND params_can_diag_body "${_line}")

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
set(ROBOT_CONFIG_HPP "${OUT_DIR}/robot_config.hpp")
set(BSP_BINDINGS_CPP "${OUT_DIR}/bsp_bindings.cpp")

file(WRITE "${CONFIG_HPP}"
"#pragma once\n"
"// Generated from ${IOC} + ${CONFIG}. Do not edit.\n\n"
"#include <array>\n"
"#include <cstddef>\n"
"#include <cstdint>\n\n"
"#define HW_HAS_USB ${HW_HAS_USB}\n"
"#define ENABLE_USBX ${ENABLE_USBX_C}\n"
"#define HAS_AHRS ${HAS_AHRS}\n"
"#define HAS_DMIMU ${HAS_DMIMU}\n"
"#define HAS_REMOTER ${HAS_REMOTER}\n"
"#define HAS_VT03 ${HAS_VT03}\n"
"#define HAS_PS2 ${HAS_PS2}\n"
"#define ENABLE_DR16 ${ENABLE_DR16}\n"
"#define ENABLE_VT03 ${ENABLE_VT03}\n"
"#define ENABLE_PS2 ${ENABLE_PS2}\n"
"#define HAS_REFEREE ${HAS_REFEREE}\n"
"#define HAS_UI ${HAS_UI}\n"
"#define HAS_LED ${HAS_LED}\n"
"${pwm_feature_macros}"
"#define HAS_MOTORS ${HAS_MOTORS}\n"
"#define CAN_DIAG_ENABLED ${CAN_DIAG_ENABLED}\n"
"#define MOTOR_DJI ${MOTOR_DJI_C}\n"
"#define MOTOR_DM ${MOTOR_DM_C}\n"
"#define MOTOR_LK ${MOTOR_LK_C}\n\n"
"namespace config::feature {\n\n"
"inline constexpr bool hw_has_usb = ${HW_HAS_USB};\n"
"inline constexpr bool enable_usbx = ${ENABLE_USBX_C};\n"
"inline constexpr bool has_ahrs = ${HAS_AHRS};\n"
"inline constexpr bool has_dmimu = ${HAS_DMIMU};\n"
"inline constexpr bool has_remoter = ${HAS_REMOTER};\n"
"inline constexpr bool has_vt03 = ${HAS_VT03};\n"
"inline constexpr bool has_ps2 = ${HAS_PS2};\n"
"inline constexpr bool enable_dr16 = ${ENABLE_DR16};\n"
"inline constexpr bool enable_vt03 = ${ENABLE_VT03};\n"
"inline constexpr bool enable_ps2 = ${ENABLE_PS2};\n"
"inline constexpr bool has_referee = ${HAS_REFEREE};\n"
"inline constexpr bool has_ui = ${HAS_UI};\n"
"inline constexpr bool has_led = ${HAS_LED};\n"
"${pwm_feature_constants}"
"inline constexpr bool has_motors = ${HAS_MOTORS};\n"
"inline constexpr bool motor_dji = ${MOTOR_DJI_C};\n"
"inline constexpr bool motor_dm = ${MOTOR_DM_C};\n"
"inline constexpr bool motor_lk = ${MOTOR_LK_C};\n\n"
"inline constexpr bool can_diag = ${CAN_DIAG_ENABLED};\n\n"
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
"namespace gpio {\n\n"
"enum class port_id : std::uint8_t { none = 0, a, b, c, d, e, f, g, h, i, j, k }${generated_semicolon_token}\n"
"enum class active_level : std::uint8_t { low = 0, high = 1 }${generated_semicolon_token}\n"
"enum class input : std::uint8_t { ${gpio_input_enum_entries} }${generated_semicolon_token}\n"
"enum class output : std::uint8_t { ${gpio_output_enum_entries} }${generated_semicolon_token}\n\n"
"struct input_config { port_id port${generated_semicolon_token} std::uint8_t pin${generated_semicolon_token} active_level active${generated_semicolon_token} }${generated_semicolon_token}\n"
"struct output_config { port_id port${generated_semicolon_token} std::uint8_t pin${generated_semicolon_token} active_level active${generated_semicolon_token} }${generated_semicolon_token}\n\n"
"inline constexpr std::size_t input_count = ${gpio_input_count}${generated_semicolon_token}\n"
"inline constexpr std::size_t output_count = ${gpio_output_count}${generated_semicolon_token}\n"
"inline constexpr std::array<input_config, input_count> input_configs = {{ ${gpio_input_config_cpp} }}${generated_semicolon_token}\n"
"inline constexpr std::array<output_config, output_count> output_configs = {{ ${gpio_output_config_cpp} }}${generated_semicolon_token}\n\n"
"} // namespace gpio\n\n"
"namespace pwm {\n\n"
"enum class channel : std::uint8_t { ${pwm_channel_enum_entries} }${generated_semicolon_token}\n\n"
"struct channel_config\n"
"{\n"
"    std::uint32_t timer_clock_hz = 0;\n"
"};\n\n"
"inline constexpr std::size_t channel_count = ${pwm_channel_count};\n"
"inline constexpr std::array<channel_config, channel_count> configs = {{ ${pwm_config_cpp} }};\n\n"
"} // namespace pwm\n\n"
"namespace adc {\n\n"
"enum class channel : std::uint8_t { ${adc_channel_enum_entries} }${generated_semicolon_token}\n"
"inline constexpr std::size_t channel_count = ${adc_channel_count}${generated_semicolon_token}\n\n"
"} // namespace adc\n\n"
"namespace usart {\n\n"
"using port = std::size_t;\n\n"
"enum class handle_id : std::uint8_t { none = 0, uart5, uart7, usart1, usart10 };\n\n"
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
"inline constexpr bsp::usart::port ps2 = ${ps2_binding};\n"
"inline constexpr bsp::usart::port referee = ${referee_binding};\n"
"inline constexpr bsp::usart::port test_report = ${test_report_binding};\n\n"
"} // namespace uart\n"
"\nnamespace gpio {\n\n"
"${gpio_input_binding_body}${gpio_output_binding_body}"
"\n} // namespace gpio\n"
"\nnamespace pwm {\n\n"
"${pwm_app_binding_body}"
"\n} // namespace pwm\n"
"\nnamespace adc {\n\n"
"${adc_app_binding_body}"
"\n} // namespace adc\n"
"} // namespace app\n\n"
"namespace params::ahrs {\n"
"${params_ahrs_body}"
"} // namespace params::ahrs\n\n"
"namespace params::dmimu {\n"
"${params_dmimu_body}"
"} // namespace params::dmimu\n\n"
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
"namespace params::can_diag {\n"
"${params_can_diag_body}"
"} // namespace params::can_diag\n"
)
file(READ "${CONFIG_HPP}" config_hpp_raw)
string(REPLACE "${generated_semicolon_token}" ";" config_hpp_fixed "${config_hpp_raw}")
file(WRITE "${CONFIG_HPP}" "${config_hpp_fixed}")

message(STATUS "Generated ${CONFIG_HPP}")

file(WRITE "${BSP_BINDINGS_CPP}"
"// Generated from ${IOC}. Do not edit.\n\n"
"#include \"bsp_adc.hpp\"\n"
"#include \"bsp_pwm.hpp\"\n"
"#include \"adc.h\"\n"
"#include \"tim.h\"\n\n"
"namespace bsp::pwm::detail {\n\n"
"bool binding_for(channel channel_id, binding& out) noexcept\n"
"{\n"
"    switch (channel_id)\n"
"    {\n"
"${pwm_binding_cases}"
"    default: return false${generated_semicolon_token}\n"
"    }\n"
"}\n\n"
"} // namespace bsp::pwm::detail\n\n"
"namespace bsp::adc::detail {\n\n"
"bool binding_for(channel channel_id, binding& out) noexcept\n"
"{\n"
"    switch (channel_id)\n"
"    {\n"
"${adc_binding_cases}"
"    default: return false${generated_semicolon_token}\n"
"    }\n"
"}\n\n"
"} // namespace bsp::adc::detail\n")
file(READ "${BSP_BINDINGS_CPP}" bsp_bindings_raw)
string(REPLACE "${generated_semicolon_token}" ";" bsp_bindings_fixed "${bsp_bindings_raw}")
file(WRITE "${BSP_BINDINGS_CPP}" "${bsp_bindings_fixed}")
message(STATUS "Generated ${BSP_BINDINGS_CPP}")

function(_pnx_motor_type_flag model out_var)
    string(TOLOWER "${model}" model_lower)
    if(model_lower MATCHES "^dji_")
        set(${out_var} "Dji" PARENT_SCOPE)
    elseif(model_lower MATCHES "^dm_")
        set(${out_var} "Dm" PARENT_SCOPE)
    elseif(model_lower MATCHES "^lk_")
        set(${out_var} "Lk" PARENT_SCOPE)
    elseif(model_lower MATCHES "^xv2_")
        set(${out_var} "Xv2" PARENT_SCOPE)
    else()
        set(${out_var} "Other" PARENT_SCOPE)
    endif()
endfunction()

function(_pnx_motor_control_mode_expr mode out_var)
    string(TOLOWER "${mode}" mode_lower)
    if(mode_lower STREQUAL "" OR mode_lower STREQUAL "relax")
        set(${out_var} "::motors::mode::relax" PARENT_SCOPE)
    elseif(mode_lower STREQUAL "torque")
        set(${out_var} "::motors::mode::torque" PARENT_SCOPE)
    elseif(mode_lower STREQUAL "mit")
        set(${out_var} "::motors::mode::mit" PARENT_SCOPE)
    elseif(mode_lower STREQUAL "pos_speed" OR mode_lower STREQUAL "position_speed")
        set(${out_var} "::motors::mode::pos_speed" PARENT_SCOPE)
    elseif(mode_lower STREQUAL "speed" OR mode_lower STREQUAL "velocity")
        set(${out_var} "::motors::mode::speed" PARENT_SCOPE)
    elseif(mode_lower STREQUAL "multi")
        set(${out_var} "::motors::mode::multi" PARENT_SCOPE)
    else()
        message(FATAL_ERROR "robot motor control_mode must be relax, torque, mit, pos_speed, speed, or multi")
    endif()
endfunction()

function(_pnx_motor_model_expr model out_var)
    string(TOLOWER "${model}" model_lower)
    if(model_lower STREQUAL "dji_m2006")
        set(${out_var} "model::dji_m2006" PARENT_SCOPE)
    elseif(model_lower STREQUAL "dji_m3508")
        set(${out_var} "model::dji_m3508" PARENT_SCOPE)
    elseif(model_lower STREQUAL "dji_gm6020")
        set(${out_var} "model::dji_gm6020" PARENT_SCOPE)
    elseif(model_lower STREQUAL "dji_xroll")
        set(${out_var} "model::dji_xroll" PARENT_SCOPE)
    elseif(model_lower STREQUAL "dm_dm4310")
        set(${out_var} "model::dm_dm4310" PARENT_SCOPE)
    elseif(model_lower STREQUAL "dm_dm8009p")
        set(${out_var} "model::dm_dm8009p" PARENT_SCOPE)
    elseif(model_lower STREQUAL "lk_lk8016")
        set(${out_var} "model::lk_lk8016" PARENT_SCOPE)
    elseif(model_lower STREQUAL "lk_lk9025")
        set(${out_var} "model::lk_lk9025" PARENT_SCOPE)
    elseif(model_lower STREQUAL "unknown" OR model_lower STREQUAL "")
        set(${out_var} "model::unknown" PARENT_SCOPE)
    else()
        message(FATAL_ERROR "robot motor model ${model} is not supported")
    endif()
endfunction()

set(robot_motors_body "")
set(robot_motor_count 0)
set(robot_has_dji 0)
set(robot_has_dm 0)
set(robot_has_lk 0)
set(robot_has_xv2 0)
set(robot_has_other 0)
set(robot_dm_id_base "0x01")
set(robot_dm_master_id_base "0x05")
set(robot_dm_max_motors "4")
set(robot_dmimu_include "")
set(robot_dmimu_body "// DMIMU is not enabled in the robot device tree.\n")

if(NOT robot_json STREQUAL "")
    if(HAS_DMIMU)
        string(JSON robot_dmimu_can_bus ERROR_VARIABLE json_err GET "${robot_json}" devices dmimu can_bus)
        if(json_err OR robot_dmimu_can_bus STREQUAL "")
            message(FATAL_ERROR "enabled robot devices.dmimu requires can_bus")
        endif()
        string(JSON robot_dmimu_can_type ERROR_VARIABLE json_err GET "${robot_json}" devices dmimu can_type)
        if(json_err OR robot_dmimu_can_type STREQUAL "")
            message(FATAL_ERROR "enabled robot devices.dmimu requires can_type=classic")
        endif()
        string(JSON robot_dmimu_can_id ERROR_VARIABLE json_err GET "${robot_json}" devices dmimu can_id)
        if(json_err OR robot_dmimu_can_id STREQUAL "")
            message(FATAL_ERROR "enabled robot devices.dmimu requires can_id")
        endif()
        string(JSON robot_dmimu_master_id ERROR_VARIABLE json_err GET "${robot_json}" devices dmimu master_id)
        if(json_err OR robot_dmimu_master_id STREQUAL "")
            message(FATAL_ERROR "enabled robot devices.dmimu requires master_id")
        endif()

        string(TOLOWER "${robot_dmimu_can_bus}" robot_dmimu_can_bus_lower)
        string(TOLOWER "${robot_dmimu_can_type}" robot_dmimu_can_type_lower)
        pnx_ioc_hw_in_list("${PNX_IOC_FDCAN_HW}" "${robot_dmimu_can_bus_lower}" robot_dmimu_can_bus_present)
        if(NOT robot_dmimu_can_bus_present)
            message(FATAL_ERROR "robot DMIMU uses ${robot_dmimu_can_bus_lower}, but it is not present in ${IOC}")
        endif()
        if(NOT robot_dmimu_can_type_lower STREQUAL "classic")
            message(FATAL_ERROR "robot DMIMU only supports can_type=classic")
        endif()
        pnx_ioc_fdcan_frame_format("${PNX_IOC_LINES}" "${robot_dmimu_can_bus_lower}" robot_dmimu_ioc_can_type)
        if(NOT robot_dmimu_ioc_can_type STREQUAL "classic")
            message(FATAL_ERROR "robot DMIMU requires ${robot_dmimu_can_bus_lower} to use Classic CAN in ${IOC}")
        endif()

        math(EXPR robot_dmimu_can_id_value "${robot_dmimu_can_id}")
        math(EXPR robot_dmimu_master_id_value "${robot_dmimu_master_id}")
        if(robot_dmimu_can_id_value LESS 0 OR robot_dmimu_can_id_value GREATER 255)
            message(FATAL_ERROR "robot DMIMU can_id must be in the uint8 range 0x00..0xFF")
        endif()
        if(robot_dmimu_master_id_value LESS 0 OR robot_dmimu_master_id_value GREATER 255)
            message(FATAL_ERROR "robot DMIMU master_id must be in the uint8 range 0x00..0xFF")
        endif()

        set(robot_dmimu_include "#include \"dmimu.hpp\"\n")
        string(CONCAT robot_dmimu_body
            "inline constexpr ::imu::dmimu::transport_config dmimu{\n"
            "        bsp::can::bus::${robot_dmimu_can_bus_lower},\n"
            "        bsp::can::bus_type::classic,\n"
            "        ${robot_dmimu_can_id}U,\n"
            "        ${robot_dmimu_master_id}U,\n"
            "};\n")
    endif()

    string(JSON robot_dm_id_base_json ERROR_VARIABLE json_err GET "${robot_json}" devices motors dm id_base)
    if(NOT json_err AND NOT robot_dm_id_base_json STREQUAL "")
        set(robot_dm_id_base "${robot_dm_id_base_json}")
    endif()
    string(JSON robot_dm_master_id_base_json ERROR_VARIABLE json_err GET "${robot_json}" devices motors dm master_id_base)
    if(NOT json_err AND NOT robot_dm_master_id_base_json STREQUAL "")
        set(robot_dm_master_id_base "${robot_dm_master_id_base_json}")
    endif()
    string(JSON robot_dm_max_motors_json ERROR_VARIABLE json_err GET "${robot_json}" devices motors dm max_motors)
    if(NOT json_err AND NOT robot_dm_max_motors_json STREQUAL "")
        set(robot_dm_max_motors "${robot_dm_max_motors_json}")
    endif()

    string(JSON motor_count ERROR_VARIABLE json_err LENGTH "${robot_json}" devices motors list)
    if(json_err)
        set(motor_count 0)
    endif()

    if(motor_count GREATER 0)
        math(EXPR motor_last_index "${motor_count} - 1")
        foreach(i RANGE 0 ${motor_last_index})
            string(JSON motor_name ERROR_VARIABLE json_err GET "${robot_json}" devices motors list ${i} name)
            if(json_err OR motor_name STREQUAL "")
                message(FATAL_ERROR "robot motor at index ${i} requires a non-empty name")
            endif()
            string(JSON motor_model ERROR_VARIABLE json_err GET "${robot_json}" devices motors list ${i} model)
            if(json_err OR motor_model STREQUAL "")
                set(motor_model "unknown")
            endif()
            string(JSON motor_can_bus ERROR_VARIABLE json_err GET "${robot_json}" devices motors list ${i} can_bus)
            if(json_err OR motor_can_bus STREQUAL "")
                message(FATAL_ERROR "robot motor ${motor_name} requires can_bus")
            endif()
            string(JSON motor_can_type ERROR_VARIABLE json_err GET "${robot_json}" devices motors list ${i} can_type)
            if(json_err OR motor_can_type STREQUAL "")
                message(FATAL_ERROR "robot motor ${motor_name} requires can_type")
            endif()
            string(JSON motor_can_id ERROR_VARIABLE json_err GET "${robot_json}" devices motors list ${i} can_id)
            if(json_err OR motor_can_id STREQUAL "")
                message(FATAL_ERROR "robot motor ${motor_name} requires can_id")
            endif()
            string(JSON motor_control_mode ERROR_VARIABLE json_err GET "${robot_json}" devices motors list ${i} control_mode)
            if(json_err)
                set(motor_control_mode "relax")
            endif()

            string(TOLOWER "${motor_can_bus}" motor_can_bus_lower)
            string(TOLOWER "${motor_can_type}" motor_can_type_lower)
            pnx_ioc_hw_in_list("${PNX_IOC_FDCAN_HW}" "${motor_can_bus_lower}" motor_can_bus_present)
            if(NOT motor_can_bus_present)
                message(FATAL_ERROR "robot motor ${motor_name} uses ${motor_can_bus_lower}, but it is not present in ${IOC}")
            endif()
            if(NOT motor_can_type_lower STREQUAL "classic" AND NOT motor_can_type_lower STREQUAL "fd")
                message(FATAL_ERROR "robot motor ${motor_name} can_type must be classic or fd")
            endif()

            _pnx_cpp_identifier("${motor_name}" motor_ident)
            string(REGEX MATCH "^[A-Za-z_][A-Za-z0-9_]*$" valid_ident "${motor_ident}")
            if(NOT valid_ident)
                message(FATAL_ERROR "robot motor ${motor_name} cannot be converted to a valid C++ identifier")
            endif()

            _pnx_motor_type_flag("${motor_model}" motor_type_flag)
            _pnx_motor_control_mode_expr("${motor_control_mode}" motor_control_mode_expr)
            _pnx_motor_model_expr("${motor_model}" motor_model_expr)
            if(motor_type_flag STREQUAL "Dji")
                set(robot_has_dji 1)
            elseif(motor_type_flag STREQUAL "Dm")
                set(robot_has_dm 1)
            elseif(motor_type_flag STREQUAL "Lk")
                set(robot_has_lk 1)
            elseif(motor_type_flag STREQUAL "Xv2")
                set(robot_has_xv2 1)
            else()
                set(robot_has_other 1)
            endif()

            string(APPEND robot_motors_body
                "// ${motor_model}\n"
                "inline constexpr model ${motor_ident}_model = ${motor_model_expr};\n"
                "inline constexpr ::motors::config ${motor_ident}{\n"
                "    bsp::can::bus::${motor_can_bus_lower},\n"
                "    bsp::can::bus_type::${motor_can_type_lower},\n"
                "    ${motor_can_id}U,\n"
                "    ${motor_control_mode_expr},\n"
                "};\n\n")
            math(EXPR robot_motor_count "${robot_motor_count} + 1")
        endforeach()
    endif()
endif()

if(robot_motors_body STREQUAL "")
    set(robot_motors_body "// No motors are described in the robot device tree.\n")
endif()

file(WRITE "${ROBOT_CONFIG_HPP}"
"#pragma once\n"
"// Generated from robot device tree. Do not edit.\n\n"
"#include \"config.hpp\"\n"
"#include \"motor.hpp\"\n\n"
"${robot_dmimu_include}\n"
"#include <cstddef>\n"
"#include <cstdint>\n\n"
"namespace robot::motors {\n\n"
"inline constexpr std::size_t motor_count = ${robot_motor_count};\n"
"inline constexpr bool has_dji = ${robot_has_dji};\n"
"inline constexpr bool has_dm = ${robot_has_dm};\n"
"inline constexpr bool has_lk = ${robot_has_lk};\n"
"inline constexpr bool has_xv2 = ${robot_has_xv2};\n"
"inline constexpr bool has_other = ${robot_has_other};\n\n"
"enum class model : std::uint8_t {\n"
"    unknown = 0,\n"
"    dji_m2006,\n"
"    dji_m3508,\n"
"    dji_gm6020,\n"
"    dji_xroll,\n"
"    dm_dm4310,\n"
"    dm_dm8009p,\n"
"    lk_lk8016,\n"
"    lk_lk9025,\n"
"};\n\n"
"namespace dm {\n"
"inline constexpr std::uint32_t id_base = ${robot_dm_id_base}U;\n"
"inline constexpr std::uint32_t master_id_base = ${robot_dm_master_id_base}U;\n"
"inline constexpr std::size_t max_motors = ${robot_dm_max_motors};\n"
"} // namespace dm\n\n"
"${robot_motors_body}"
"} // namespace robot::motors\n\n"
"namespace robot::imu {\n\n"
"inline constexpr bool has_dmimu = ${HAS_DMIMU};\n"
"${robot_dmimu_body}"
"\n} // namespace robot::imu\n")

message(STATUS "Generated ${ROBOT_CONFIG_HPP}")
