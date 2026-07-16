#pragma once

#include <cstdint>

namespace runtime
{

struct monitor_stats
{
    std::uint32_t count = 0;
    std::uint32_t last_us = 0;
    std::uint32_t min_us = 0;
    std::uint32_t max_us = 0;
    std::uint32_t budget_us = 0;
    std::uint32_t overrun_count = 0;
    std::uint64_t total_us = 0;

    float average_us() const;
};

class monitor
{
public:
    explicit monitor(std::uint32_t budget_us = 0);

    void reset();
    void set_budget_us(std::uint32_t budget_us);
    void begin();
    std::uint32_t end();

    bool active() const { return active_; }
    const monitor_stats& stats() const { return stats_; }

private:
    monitor_stats stats_{};
    std::uint64_t start_us_ = 0;
    bool active_ = false;
};

class scope
{
public:
    explicit scope(monitor& target);
    ~scope();

    scope(const scope&) = delete;
    scope& operator=(const scope&) = delete;

private:
    monitor& target_;
};

} // namespace runtime
