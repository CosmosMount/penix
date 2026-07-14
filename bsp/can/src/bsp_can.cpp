#include "bsp_can.hpp"

#include <array>
#include <algorithm>
#include <cstring>

namespace bsp::can
{

namespace
{

struct rx_slot
{
    rx_handler handler = nullptr;
    void* user_data = nullptr;
};

std::array<bus_type, bus_count> active_types{};
std::array<bool, bus_count> initialized{};
std::array<std::array<rx_slot, max_rx_callbacks>, bus_count> rx_slots{};
std::array<TX_SEMAPHORE, bus_count> err_sems{};
std::array<bool, bus_count> err_sem_ready{};

uint32_t len_to_dlc(uint16_t len) noexcept
{
    if (len <= 8U)
    {
        return static_cast<uint32_t>(len) << 16U;
    }
    if (len <= 12U) { return FDCAN_DLC_BYTES_12; }
    if (len <= 16U) { return FDCAN_DLC_BYTES_16; }
    if (len <= 20U) { return FDCAN_DLC_BYTES_20; }
    if (len <= 24U) { return FDCAN_DLC_BYTES_24; }
    if (len <= 32U) { return FDCAN_DLC_BYTES_32; }
    if (len <= 48U) { return FDCAN_DLC_BYTES_48; }
    return FDCAN_DLC_BYTES_64;
}

uint8_t dlc_to_len(uint32_t dlc) noexcept
{
    switch (dlc)
    {
    case FDCAN_DLC_BYTES_0: return 0;
    case FDCAN_DLC_BYTES_1: return 1;
    case FDCAN_DLC_BYTES_2: return 2;
    case FDCAN_DLC_BYTES_3: return 3;
    case FDCAN_DLC_BYTES_4: return 4;
    case FDCAN_DLC_BYTES_5: return 5;
    case FDCAN_DLC_BYTES_6: return 6;
    case FDCAN_DLC_BYTES_7: return 7;
    case FDCAN_DLC_BYTES_8: return 8;
    case FDCAN_DLC_BYTES_12: return 12;
    case FDCAN_DLC_BYTES_16: return 16;
    case FDCAN_DLC_BYTES_20: return 20;
    case FDCAN_DLC_BYTES_24: return 24;
    case FDCAN_DLC_BYTES_32: return 32;
    case FDCAN_DLC_BYTES_48: return 48;
    case FDCAN_DLC_BYTES_64: return 64;
    default: return 0;
    }
}

types::status ensure_err_sem(bus bus)
{
    const std::size_t idx = static_cast<std::size_t>(bus);
    if (idx >= bus_count)
    {
        return types::status::invalid_arg;
    }
    if (err_sem_ready[idx])
    {
        return types::status::ok;
    }
    if (tx_semaphore_create(&err_sems[idx], const_cast<CHAR*>("can_err"), 0) != TX_SUCCESS)
    {
        return types::status::error;
    }
    err_sem_ready[idx] = true;
    return types::status::ok;
}

void notify_rx(bus bus, const rx_frame& frame)
{
    const std::size_t idx = static_cast<std::size_t>(bus);
    if (idx >= bus_count)
    {
        return;
    }
    for (auto& slot : rx_slots[idx])
    {
        if (slot.handler != nullptr)
        {
            slot.handler(bus, frame, slot.user_data);
        }
    }
}

types::status init_common(bus bus, uint32_t notification)
{
    FDCAN_HandleTypeDef* handle = handle_of(bus);
    if (handle == nullptr)
    {
        return types::status::invalid_arg;
    }
    if (HAL_FDCAN_Start(handle) != HAL_OK)
    {
        return types::status::error;
    }
    if (HAL_FDCAN_ActivateNotification(handle, notification, 0U) != HAL_OK)
    {
        return types::status::error;
    }
    return types::status::ok;
}

types::status init_classic(bus bus)
{
    return init_common(bus, FDCAN_IT_RX_FIFO0_NEW_MESSAGE |
                            FDCAN_IT_ERROR_WARNING |
                            FDCAN_IT_ERROR_PASSIVE |
                            FDCAN_IT_ARB_PROTOCOL_ERROR |
                            FDCAN_IT_DATA_PROTOCOL_ERROR |
                            FDCAN_IT_BUS_OFF);
}

types::status init_fd(bus bus)
{
    return init_common(bus, FDCAN_IT_RX_FIFO1_NEW_MESSAGE |
                            FDCAN_IT_ERROR_WARNING |
                            FDCAN_IT_ERROR_PASSIVE |
                            FDCAN_IT_ARB_PROTOCOL_ERROR |
                            FDCAN_IT_DATA_PROTOCOL_ERROR |
                            FDCAN_IT_BUS_OFF);
}

types::status transmit_frame(bus bus,
                             uint32_t id,
                             const uint8_t* data,
                             uint16_t len,
                             uint32_t fd_format)
{
    FDCAN_HandleTypeDef* handle = handle_of(bus);
    if (handle == nullptr || data == nullptr)
    {
        return types::status::invalid_arg;
    }

    FDCAN_TxHeaderTypeDef tx_header{};
    tx_header.Identifier = id;
    tx_header.IdType = (id > 0x7FFU) ? FDCAN_EXTENDED_ID : FDCAN_STANDARD_ID;
    tx_header.TxFrameType = FDCAN_DATA_FRAME;
    tx_header.DataLength = len_to_dlc(len);
    tx_header.ErrorStateIndicator = FDCAN_ESI_ACTIVE;
    tx_header.BitRateSwitch = (fd_format == FDCAN_FD_CAN) ? FDCAN_BRS_ON : FDCAN_BRS_OFF;
    tx_header.FDFormat = fd_format;
    tx_header.TxEventFifoControl = FDCAN_NO_TX_EVENTS;
    tx_header.MessageMarker = 0U;

    uint8_t payload[64]{};
    const auto copy_len = std::min<std::size_t>(len, sizeof(payload));
    std::memcpy(payload, data, copy_len);

    if (HAL_FDCAN_AddMessageToTxFifoQ(handle, &tx_header, payload) != HAL_OK)
    {
        return types::status::error;
    }
    return types::status::ok;
}

types::status transmit_classic(bus bus, uint32_t id, const uint8_t* data, uint16_t len)
{
    if (len > 8U)
    {
        return types::status::invalid_arg;
    }
    return transmit_frame(bus, id, data, len, FDCAN_CLASSIC_CAN);
}

types::status transmit_fd(bus bus, uint32_t id, const uint8_t* data, uint16_t len)
{
    if (len > 64U)
    {
        return types::status::invalid_arg;
    }
    return transmit_frame(bus, id, data, len, FDCAN_FD_CAN);
}

} // namespace

void handle_error(FDCAN_HandleTypeDef* handle, uint32_t error_status_its)
{
    const auto bus = bus_of(handle);
    const std::size_t idx = static_cast<std::size_t>(bus);
    if (idx >= bus_count || active_types[idx] != bus_type::classic)
    {
        return;
    }

    if ((error_status_its & FDCAN_IT_ERROR_WARNING) != 0U ||
        (error_status_its & FDCAN_IT_ERROR_PASSIVE) != 0U ||
        (error_status_its & FDCAN_IT_ARB_PROTOCOL_ERROR) != 0U ||
        (error_status_its & FDCAN_IT_DATA_PROTOCOL_ERROR) != 0U)
    {
        if (err_sem_ready[idx])
        {
            tx_semaphore_put(&err_sems[idx]);
        }
    }

    if ((error_status_its & FDCAN_IT_BUS_OFF) != 0U)
    {
        HAL_FDCAN_Stop(handle);
        HAL_FDCAN_Start(handle);
    }
}

void receive(FDCAN_HandleTypeDef* handle, uint32_t rx_fifo, bus_type mode)
{
    const auto bus = bus_of(handle);
    const std::size_t idx = static_cast<std::size_t>(bus);
    if (idx >= bus_count || active_types[idx] != mode)
    {
        return;
    }

    FDCAN_RxHeaderTypeDef rx_header{};
    rx_frame frame{};
    if (HAL_FDCAN_GetRxMessage(handle, rx_fifo, &rx_header, frame.data) != HAL_OK)
    {
        return;
    }

    frame.id = rx_header.Identifier;
    frame.len = dlc_to_len(rx_header.DataLength);
    notify_rx(bus, frame);
}

types::status init(bus bus, bus_type type)
{
    const std::size_t idx = static_cast<std::size_t>(bus);
    if (idx >= bus_count)
    {
        return types::status::invalid_arg;
    }

    if (!bus_enabled(idx))
    {
        return types::status::not_configured;
    }

    if (initialized[idx])
    {
        return types::status::ok;
    }

    types::status status = ensure_err_sem(bus);
    if (status != types::status::ok)
    {
        return status;
    }

    if (type == bus_type::classic)
    {
        status = init_classic(bus);
    }
    else
    {
        status = init_fd(bus);
    }

    if (status != types::status::ok)
    {
        return status;
    }

    active_types[idx] = type;
    initialized[idx] = true;
    return types::status::ok;
}

types::status transmit(bus bus, uint32_t id, const uint8_t* data, uint16_t len)
{
    if (data == nullptr || len == 0)
    {
        return types::status::invalid_arg;
    }

    const std::size_t idx = static_cast<std::size_t>(bus);
    if (idx >= bus_count)
    {
        return types::status::invalid_arg;
    }

    if (!bus_enabled(idx))
    {
        return types::status::not_configured;
    }

    if (!initialized[idx])
    {
        return types::status::error;
    }

    if (active_types[idx] == bus_type::classic)
    {
        return transmit_classic(bus, id, data, len);
    }

    return transmit_fd(bus, id, data, len);
}

types::status register_rx_handler(bus bus, rx_handler handler, void* user_data)
{
    if (handler == nullptr)
    {
        return types::status::invalid_arg;
    }

    const std::size_t idx = static_cast<std::size_t>(bus);
    if (idx >= bus_count)
    {
        return types::status::invalid_arg;
    }

    if (!bus_enabled(idx))
    {
        return types::status::not_configured;
    }

    for (auto& slot : rx_slots[idx])
    {
        if (slot.handler == nullptr)
        {
            slot.handler = handler;
            slot.user_data = user_data;
            return types::status::ok;
        }
    }

    return types::status::error;
}

void unregister_rx_handlers(bus bus)
{
    const std::size_t idx = static_cast<std::size_t>(bus);
    if (idx >= bus_count)
    {
        return;
    }

    if (!bus_enabled(idx))
    {
        return;
    }

    for (auto& slot : rx_slots[idx])
    {
        slot.handler = nullptr;
        slot.user_data = nullptr;
    }
}

TX_SEMAPHORE* err_sem(bus bus)
{
    const std::size_t idx = static_cast<std::size_t>(bus);
    if (idx >= bus_count || !err_sem_ready[idx])
    {
        return nullptr;
    }

    return &err_sems[idx];
}

} // namespace bsp::can

extern "C" void HAL_FDCAN_RxFifo0Callback(FDCAN_HandleTypeDef* hfdcan, uint32_t RxFifo0ITs)
{
    (void)RxFifo0ITs;
    bsp::can::receive(hfdcan, FDCAN_RX_FIFO0, bsp::can::bus_type::classic);
}

extern "C" void HAL_FDCAN_RxFifo1Callback(FDCAN_HandleTypeDef* hfdcan, uint32_t RxFifo1ITs)
{
    (void)RxFifo1ITs;
    bsp::can::receive(hfdcan, FDCAN_RX_FIFO1, bsp::can::bus_type::fd);
}

extern "C" void HAL_FDCAN_ErrorStatusCallback(FDCAN_HandleTypeDef* hfdcan, uint32_t ErrorStatusITs)
{
    bsp::can::handle_error(hfdcan, ErrorStatusITs);
}
