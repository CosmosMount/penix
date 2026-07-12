#include "msg.hpp"

#include <cstring>

namespace msg
{

namespace
{

// 消息总线只需要轻量初始化，目前用于阻止未初始化前的读写。
bool bus_ready = false;

ULONG mutex_wait_option(const publish_opts& opts)
{
    // ISR 或非阻塞发布不能等待互斥锁，否则可能卡住实时路径。
    if (opts.from_isr || !opts.block)
    {
        return TX_NO_WAIT;
    }
    return TX_WAIT_FOREVER;
}

topic_layout* layout_of(const topic* topic)
{
    // 统一处理 topic 空指针和未创建状态，简化公开接口的参数检查。
    if (topic == nullptr || !topic->valid())
    {
        return nullptr;
    }
    return topic->layout;
}

} // namespace

types::status init()
{
    if (bus_ready)
    {
        return types::status::ok;
    }

    bus_ready = true;
    return types::status::ok;
}

subscriber subscribe(const topic* topic)
{
    auto* layout = layout_of(topic);
    if (layout == nullptr)
    {
        return subscriber::invalid();
    }

    if (tx_mutex_get(&layout->lock, TX_WAIT_FOREVER) != TX_SUCCESS)
    {
        return subscriber::invalid();
    }

    subscriber sub = subscriber::invalid();
    for (std::uint8_t i = 0; i < max_subscribers_per_topic; ++i)
    {
        // 找到第一个空闲槽位作为订阅者句柄；槽位耗尽时返回 invalid。
        if (!layout->subs[i].active)
        {
            layout->subs[i].active = true;
            layout->subs[i].pending = false;
            ++layout->sub_count;
            sub.layout = layout;
            sub.slot_idx = i;
            break;
        }
    }

    tx_mutex_put(&layout->lock);
    return sub;
}

types::status publish(const topic* topic, const void* data, std::size_t size, publish_opts opts)
{
    // 发布前先做完整的基本校验，避免写入错误 topic 或错误大小的载荷。
    if (!bus_ready || data == nullptr || size == 0)
    {
        return types::status::invalid_arg;
    }

    auto* layout = layout_of(topic);
    if (layout == nullptr || layout->payload_bytes == nullptr)
    {
        return types::status::invalid_arg;
    }

    if (size != layout->payload_size)
    {
        return types::status::invalid_arg;
    }

    if (tx_mutex_get(&layout->lock, mutex_wait_option(opts)) != TX_SUCCESS)
    {
        return types::status::error;
    }

    std::memcpy(layout->payload_bytes, data, size);

    // 新消息到达后，所有活跃订阅者都标记为待读。
    for (auto& slot : layout->subs)
    {
        if (slot.active)
        {
            slot.pending = true;
        }
    }

    tx_mutex_put(&layout->lock);
    return types::status::ok;
}

bool available(subscriber sub)
{
    // available 是轻量查询：只检查订阅者自己的 pending 标记。
    if (!bus_ready || !sub.valid())
    {
        return false;
    }

    if (!sub.layout->created)
    {
        return false;
    }

    const auto& slot = sub.layout->subs[sub.slot_idx];
    return slot.active && slot.pending;
}

types::status read(subscriber sub, void* buf, std::size_t size)
{
    // 读取时同样校验订阅者、输出缓冲区和载荷大小，避免越界拷贝。
    if (!bus_ready || !sub.valid() || buf == nullptr || size == 0)
    {
        return types::status::invalid_arg;
    }

    auto* layout = sub.layout;
    if (!layout->created || layout->payload_bytes == nullptr)
    {
        return types::status::invalid_arg;
    }

    auto& slot = layout->subs[sub.slot_idx];
    if (!slot.active)
    {
        return types::status::invalid_arg;
    }

    if (size != layout->payload_size)
    {
        return types::status::invalid_arg;
    }

    if (tx_mutex_get(&layout->lock, TX_WAIT_FOREVER) != TX_SUCCESS)
    {
        return types::status::error;
    }

    if (!slot.pending)
    {
        // 没有新消息时不改动输出缓冲区，调用者可用 available 先判断。
        tx_mutex_put(&layout->lock);
        return types::status::error;
    }

    std::memcpy(buf, layout->payload_bytes, layout->payload_size);
    // 每个订阅者独立消费消息，读取成功只清除当前槽位的 pending。
    slot.pending = false;
    tx_mutex_put(&layout->lock);
    return types::status::ok;
}

} // namespace msg
