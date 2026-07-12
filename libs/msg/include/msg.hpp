#pragma once

#include "memory.h"
#include "usertypes.hpp"
#include "tx_api.h"

#include <cstddef>
#include <cstdint>
#include <type_traits>

namespace msg
{

// 单个 topic 最多支持的订阅者数量；每个订阅者都有独立的 pending 标记。
inline constexpr std::uint8_t max_subscribers_per_topic = 8;

struct subscriber_slot
{
    // active 表示槽位已分配，pending 表示该订阅者尚未读取最新发布的数据。
    bool active = false;
    bool pending = false;
};

struct topic_layout
{
    // 每个 topic 自带互斥锁，保护 payload 与订阅者槽位的并发访问。
    TX_MUTEX lock{};
    std::size_t payload_size = 0;
    std::uint8_t* payload_bytes = nullptr;
    subscriber_slot subs[max_subscribers_per_topic]{};
    std::uint8_t sub_count = 0;
    bool created = false;
};

template <typename Payload>
struct topic_entry : topic_layout
{
    // payload 存放最后一次发布的消息；topic 本身只保留最新值。
    alignas(8) Payload payload{};
};

struct topic
{
    topic_layout* layout = nullptr;

    [[nodiscard]] bool valid() const { return layout != nullptr && layout->created; }
};

struct publish_opts
{
    // block=false 或 from_isr=true 时发布不会等待互斥锁，适合中断/非阻塞场景。
    bool block = true;
    bool from_isr = false;
};

struct subscriber
{
    topic_layout* layout = nullptr;
    std::uint8_t slot_idx = 0xFF;

    [[nodiscard]] bool valid() const { return layout != nullptr && slot_idx != 0xFF; }

    [[nodiscard]] static constexpr subscriber invalid() { return {nullptr, 0xFF}; }
};

types::status init();

template <typename Payload>
topic* create()
{
    // 消息系统直接按字节拷贝载荷，因此载荷类型必须能安全地平凡复制。
    static_assert(std::is_trivially_copyable_v<Payload>, "msg payload must be trivially copyable");

    if (init() != types::status::ok)
    {
        return nullptr;
    }

    static topic_entry<Payload> storage RAM_D1_BSS;
    static topic handle;

    if (!storage.created)
    {
        // 每种 Payload 类型对应一个静态 topic，首次创建时完成一次性初始化。
        storage.payload_size = sizeof(Payload);
        storage.payload_bytes = reinterpret_cast<std::uint8_t*>(&storage.payload);
        storage.sub_count = 0;

        for (auto& slot : storage.subs)
        {
            slot.active = false;
            slot.pending = false;
        }

        if (tx_mutex_create(&storage.lock, const_cast<CHAR*>("msg"), TX_NO_INHERIT) != TX_SUCCESS)
        {
            return nullptr;
        }

        storage.created = true;
        handle.layout = &storage;
    }

    return &handle;
}

subscriber subscribe(const topic* topic);

template <typename Payload>
subscriber subscribe()
{
    // 便捷订阅接口：按消息类型获取对应 topic，再为调用者分配订阅槽位。
    const topic* topic = create<Payload>();
    if (topic == nullptr)
    {
        return subscriber::invalid();
    }
    return subscribe(topic);
}

types::status publish(const topic* topic, const void* data, std::size_t size, publish_opts opts = {});

template <typename T>
types::status publish(const topic* topic, const T& data, publish_opts opts = {})
{
    // 模板重载负责推导载荷大小，底层 publish 会校验大小是否匹配 topic。
    static_assert(std::is_trivially_copyable_v<T>, "msg payload must be trivially copyable");
    return publish(topic, &data, sizeof(T), opts);
}

bool available(subscriber sub);
types::status read(subscriber sub, void* buf, std::size_t size);

template <typename T>
types::status read(subscriber sub, T& out)
{
    // 读取成功后会清除该订阅者自己的 pending 标记，不影响其他订阅者。
    static_assert(std::is_trivially_copyable_v<T>, "msg payload must be trivially copyable");
    return read(sub, &out, sizeof(T));
}

} // namespace msg
