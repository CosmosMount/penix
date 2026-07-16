#include "runtime_monitor.hpp"

#include "bsp_dwt.hpp"

namespace runtime
{

float monitor_stats::average_us() const
{
    if (count == 0U)
    {
        return 0.0f;
    }
    return static_cast<float>(total_us) / static_cast<float>(count);
}

monitor::monitor(std::uint32_t budget_us)
{
    stats_.budget_us = budget_us;
}

void monitor::reset()
{
    const std::uint32_t budget = stats_.budget_us;
    stats_ = {};
    stats_.budget_us = budget;
    start_us_ = 0U;
    active_ = false;
}

void monitor::set_budget_us(std::uint32_t budget_us)
{
    stats_.budget_us = budget_us;
}

void monitor::begin()
{
    if (!bsp::dwt::initialized())
    {
        bsp::dwt::init();
    }
    start_us_ = bsp::dwt::timeline_us();
    active_ = true;
}

std::uint32_t monitor::end()
{
    if (!active_)
    {
        return 0U;
    }

    const std::uint64_t now_us = bsp::dwt::timeline_us();
    const std::uint64_t elapsed64 = now_us >= start_us_ ? now_us - start_us_ : 0U;
    const std::uint32_t elapsed =
        elapsed64 > 0xFFFFFFFFULL ? 0xFFFFFFFFUL : static_cast<std::uint32_t>(elapsed64);

    stats_.last_us = elapsed;
    stats_.min_us = stats_.count == 0U || elapsed < stats_.min_us ? elapsed : stats_.min_us;
    stats_.max_us = elapsed > stats_.max_us ? elapsed : stats_.max_us;
    stats_.total_us += elapsed;
    ++stats_.count;
    if (stats_.budget_us != 0U && elapsed > stats_.budget_us)
    {
        ++stats_.overrun_count;
    }

    active_ = false;
    return elapsed;
}

scope::scope(monitor& target) : target_(target)
{
    target_.begin();
}

scope::~scope()
{
    target_.end();
}

} // namespace runtime
