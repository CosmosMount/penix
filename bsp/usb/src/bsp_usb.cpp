#include "bsp_usb.hpp"

#include "bridge_usb.h"
#include "memory.h"

#include "ux_api.h"
#include "ux_device_class_cdc_acm.h"

#include <cstring>

namespace bsp::usb
{

namespace
{

constexpr uint16_t k_io_buffer_size = 512;
constexpr uint16_t k_read_stack_size = 1536;
constexpr uint16_t k_write_stack_size = 1536;

alignas(8) uint8_t read_stack[k_read_stack_size] RAM_D1_BSS{};
alignas(8) uint8_t write_stack[k_write_stack_size] RAM_D1_BSS{};
alignas(4) uint8_t rx_buffer[k_io_buffer_size] RAM_D1_BSS{};
alignas(4) uint8_t tx_buffer[k_io_buffer_size] RAM_D1_BSS{};

TX_THREAD read_thread RAM_D1_BSS{};
TX_THREAD write_thread RAM_D1_BSS{};

config cdc_config{};
bool initialized = false;

bool device_ready()
{
    UX_SLAVE_CLASS_CDC_ACM* cdc = usb_cdc_handle();
    if (cdc == UX_NULL)
    {
        return false;
    }

    UX_SLAVE_DEVICE* device = &_ux_system_slave->ux_system_slave_device;
    return device->ux_slave_device_state == UX_DEVICE_CONFIGURED;
}

void read_thread_entry(ULONG thread_input)
{
    (void)thread_input;

    while (true)
    {
        if (device_ready() && cdc_config.on_rx != nullptr)
        {
            ULONG actual_length = 0;
            UX_SLAVE_CLASS_CDC_ACM* cdc = usb_cdc_handle();
            const UINT status = ux_device_class_cdc_acm_read(
                cdc, rx_buffer, static_cast<ULONG>(k_io_buffer_size), &actual_length);

            if (status == UX_SUCCESS && actual_length >= cdc_config.min_rx_size)
            {
                cdc_config.on_rx(rx_buffer, static_cast<uint16_t>(actual_length), cdc_config.user);
            }
        }

        tx_thread_sleep(cdc_config.period_ticks);
    }
}

void write_thread_entry(ULONG thread_input)
{
    (void)thread_input;

    tx_thread_sleep(10);

    while (true)
    {
        if (device_ready() && cdc_config.fill_tx != nullptr)
        {
            const uint16_t tx_len = cdc_config.fill_tx(tx_buffer, cdc_config.max_tx_size, cdc_config.user);
            if (tx_len > 0)
            {
                ULONG actual_length = 0;
                UX_SLAVE_CLASS_CDC_ACM* cdc = usb_cdc_handle();
                (void)ux_device_class_cdc_acm_write(
                    cdc, tx_buffer, static_cast<ULONG>(tx_len), &actual_length);
            }
        }

        tx_thread_sleep(cdc_config.period_ticks);
    }
}

} // namespace

types::status init(const config& cfg)
{
    if (initialized)
    {
        return types::status::ok;
    }

    if (cfg.on_rx == nullptr && cfg.fill_tx == nullptr)
    {
        return types::status::error;
    }

    cdc_config = cfg;
    if (cdc_config.max_tx_size > k_io_buffer_size)
    {
        cdc_config.max_tx_size = k_io_buffer_size;
    }

    if (tx_thread_create(&read_thread, const_cast<CHAR*>("usb_cdc_rx"), read_thread_entry, 0,
                         read_stack, sizeof(read_stack), cdc_config.read_priority, cdc_config.read_priority,
                         TX_NO_TIME_SLICE, TX_AUTO_START) != TX_SUCCESS)
    {
        return types::status::error;
    }

    if (tx_thread_create(&write_thread, const_cast<CHAR*>("usb_cdc_tx"), write_thread_entry, 0,
                         write_stack, sizeof(write_stack), cdc_config.write_priority, cdc_config.write_priority,
                         TX_NO_TIME_SLICE, TX_AUTO_START) != TX_SUCCESS)
    {
        return types::status::error;
    }

    initialized = true;
    return types::status::ok;
}

bool connected()
{
    return device_ready();
}

} // namespace bsp::usb
