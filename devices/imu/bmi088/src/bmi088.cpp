#include "bmi088.hpp"

#include "bsp_exti.h"
#include "bsp_pwm.hpp"
#include "bsp_spi.hpp"
#include "constrain.hpp"
#include "config.hpp"
#include "main.h"
#include "tx_api.h"

#include <cmath>

namespace imu
{

namespace
{

constexpr bsp::spi::bus imu_spi = bsp::spi::bus::spi2;

#if HAS_PWM_TIM3_CH4
constexpr bsp::pwm::channel imu_heater_pwm = bsp::pwm::channel::tim3_ch4;
#elif HAS_PWM_TIM12_CH2
constexpr bsp::pwm::channel imu_heater_pwm = bsp::pwm::channel::tim12_ch2;
#endif

bsp::spi::cs to_spi_cs(bmi088::cs target)
{
    return target == bmi088::cs::acc ? bsp::spi::cs::bmi088_acc : bsp::spi::cs::bmi088_gyro;
}

} // namespace

void bmi088::write_reg(cs target, uint8_t addr, const uint8_t* data, uint8_t len)
{
    bsp::spi::cs_set(to_spi_cs(target), true);
    uint8_t tx_addr = static_cast<uint8_t>(addr & spi_write);
    bsp::spi::transmit(imu_spi, &tx_addr, 1, 1000);
    if (len > 0 && data != nullptr)
    {
        bsp::spi::transmit(imu_spi, data, len, 1000);
    }
    if (test.init_err)
    {
        tx_thread_sleep(1);
    }
    bsp::spi::cs_set(to_spi_cs(target), false);
}

void bmi088::read_reg(cs target, uint8_t addr, uint8_t* data, uint8_t len)
{
    bsp::spi::cs_set(to_spi_cs(target), true);
    uint8_t tx_addr = static_cast<uint8_t>(addr | spi_read);
    bsp::spi::transmit(imu_spi, &tx_addr, 1, 1000);
    bsp::spi::receive(imu_spi, data, len, 1000);
    bsp::spi::cs_set(to_spi_cs(target), false);
}

void bmi088::calibrate()
{
    constexpr int calib_samples = 4000;
    float gyro_sum[3] = {0.0f, 0.0f, 0.0f};
    gyrodata gyro_sample{};

    gyro_offset[0] = 0.0f;
    gyro_offset[1] = 0.0f;
    gyro_offset[2] = 0.0f;

    for (int i = 0; i < calib_samples; ++i)
    {
        read_gyro(&gyro_sample);
        gyro_sum[0] += gyro_sample.x;
        gyro_sum[1] += gyro_sample.y;
        gyro_sum[2] += gyro_sample.z;
        tx_thread_sleep(1);
    }

    gyro_offset[0] = gyro_sum[0] / static_cast<float>(calib_samples);
    gyro_offset[1] = gyro_sum[1] / static_cast<float>(calib_samples);
    gyro_offset[2] = gyro_sum[2] / static_cast<float>(calib_samples);

    if (std::fabs(gyro_offset[0]) > 0.1f || std::fabs(gyro_offset[1]) > 0.1f ||
        std::fabs(gyro_offset[2]) > 0.1f)
    {
        test.calibrate_err = true;
        gyro_offset[0] = gyro_preoffset_x;
        gyro_offset[1] = gyro_preoffset_y;
        gyro_offset[2] = gyro_preoffset_z;
    }
    else
    {
        test.calibrate_err = false;
    }
    update_status_from_selftest();
}

void bmi088::temperature_control(float target)
{
    target_temp = target;
    float duty_ratio = calculate_temperature_duty(acc.temperature);
    set_heater_duty(duty_ratio);
}

void bmi088::set_heater_duty(float ratio)
{
#if HAS_PWM_TIM3_CH4 || HAS_PWM_TIM12_CH2
    bsp::pwm::set_duty(imu_heater_pwm, ratio);
#else
    (void)ratio;
#endif
}

bool bmi088::start_temperature_control(const temp_control_config& cfg)
{
    if (temp_thread_started_)
    {
        return true;
    }

    temp_cfg_ = cfg;
    target_temp = temp_cfg_.target_temp;
    temperature_ready_ = false;
    temp_state_ = temp_state::boost;
    heater_duty_ = 0.0f;

    if (tx_thread_create(&temp_thread_, const_cast<CHAR*>("bmi088_temp"), temp_thread_entry,
                         reinterpret_cast<ULONG>(this),
                         temp_stack_, sizeof(temp_stack_), temp_cfg_.thread_priority,
                         temp_cfg_.thread_priority, TX_NO_TIME_SLICE, TX_AUTO_START) != TX_SUCCESS)
    {
        return false;
    }

    temp_thread_started_ = true;
    return true;
}

void bmi088::set_gyro_data_ready_callback(data_ready_callback callback, void* user)
{
    gyro_data_ready_callback_ = callback;
    gyro_data_ready_user_ = user;
    bsp_exti_attach(GYRO_INT_Pin, gyro_data_ready_entry, this);
}

void bmi088::gyro_data_ready_entry(void* user)
{
    auto* self = static_cast<bmi088*>(user);
    if (self != nullptr && self->gyro_data_ready_callback_ != nullptr)
    {
        self->gyro_data_ready_callback_(self->gyro_data_ready_user_);
    }
}

void bmi088::temp_thread_entry(ULONG arg)
{
    auto* self = reinterpret_cast<bmi088*>(arg);
    if (self == nullptr)
    {
        return;
    }

    if (!self->temp_cfg_.enabled)
    {
        self->test.temp_ctrl_err = false;
        self->update_status_from_selftest();
#if HAS_PWM_TIM3_CH4 || HAS_PWM_TIM12_CH2
        bsp::pwm::set_duty(imu_heater_pwm, 0.0f);
        bsp::pwm::stop(imu_heater_pwm);
#endif
        for (;;)
        {
            self->read_temperature(&self->acc.temperature);
            if (!self->valid_temperature(self->acc.temperature))
            {
                self->temperature_ready_ = false;
                self->test.temp_ctrl_err = true;
                self->update_status_from_selftest();
            }
            else
            {
                self->temperature_ready_ = self->acc.temperature >= 20.0f;
            }
            tx_thread_sleep(500);
        }
    }

    auto& pid = self->temp_pid;
    self->test.temp_ctrl_err = false;
    self->update_status_from_selftest();
    pid.mode = static_cast<control::pid_mode>(
        static_cast<uint8_t>(control::pid_mode::position) |
        static_cast<uint8_t>(control::pid_mode::integral_limit) |
        static_cast<uint8_t>(control::pid_mode::changing_integral_rate) |
        static_cast<uint8_t>(control::pid_mode::derivative_on_measurement));
    pid.tune(650.0f, 0.06f, 10.0f);
    pid.max_out = 300.0f;
    pid.max_iout = 300.0f;
    pid.scalar_a = 3.5f;
    pid.scalar_b = 0.08f;

#if HAS_PWM_TIM3_CH4 || HAS_PWM_TIM12_CH2
    bsp::pwm::start(imu_heater_pwm);
#endif

    for (;;)
    {
        self->read_temperature(&self->acc.temperature);
        self->temperature_ready_ = self->valid_temperature(self->acc.temperature) &&
                                   self->acc.temperature >= temp_ready_threshold;
        if (!self->valid_temperature(self->acc.temperature))
        {
            self->test.temp_ctrl_err = true;
            self->update_status_from_selftest();
            self->heater_duty_ = 0.0f;
            self->set_heater_duty(0.0f);
        }
        else
        {
            self->test.temp_ctrl_err = false;
            self->update_status_from_selftest();
            self->temperature_control(self->target_temp);
        }
        tx_thread_sleep(temp_control_period_ticks);
    }
}

bool bmi088::valid_temperature(float temperature) const
{
    return std::isfinite(temperature) && temperature >= temp_fault_low && temperature <= temp_fault_high;
}

float bmi088::calculate_temperature_duty(float temperature)
{
    if (!valid_temperature(temperature))
    {
        temp_state_ = temp_state::overtemperature;
        heater_duty_ = 0.0f;
        return heater_duty_;
    }

    switch (temp_state_)
    {
    case temp_state::boost:
        if (temperature < temp_boost_enter)
        {
            heater_duty_ = temp_boost_duty;
        }
        else
        {
            temp_state_ = temp_state::approach;
            heater_duty_ = calculate_approach_duty(temperature);
        }
        break;

    case temp_state::approach:
        if (temperature >= temp_over_enter)
        {
            temp_state_ = temp_state::overtemperature;
            heater_duty_ = 0.0f;
        }
        else if (temperature >= temp_hold_enter)
        {
            temp_state_ = temp_state::hold;
        }
        else if (temperature < temp_boost_enter)
        {
            temp_state_ = temp_state::boost;
            heater_duty_ = temp_reboost_duty;
        }
        else
        {
            heater_duty_ = calculate_approach_duty(temperature);
        }
        break;

    case temp_state::hold:
        if (temperature >= temp_over_enter)
        {
            temp_state_ = temp_state::overtemperature;
            heater_duty_ = 0.0f;
        }
        else if (temperature < temp_boost_enter)
        {
            temp_state_ = temp_state::boost;
            heater_duty_ = temp_reboost_duty;
        }
        break;

    case temp_state::overtemperature:
        heater_duty_ = 0.0f;
        if (temperature <= temp_over_exit)
        {
            temp_state_ = temp_state::approach;
        }
        break;
    }

    return heater_duty_;
}

float bmi088::calculate_approach_duty(float temperature)
{
    temp_pid.ref = target_temp;
    temp_pid.fdb = temperature;
    temp_pid.update();

    return math::clamp(temp_pid.result / 999.0f, 0.0f, temp_approach_max_duty);
}

void bmi088::verify_acc_chip_id()
{
    uint8_t rx[2] = {0};
    read_reg(cs::acc, acc_chip_id_addr, rx, 2);
    tx_thread_sleep(1);
    if (rx[1] != acc_chip_id_val)
    {
        test.acc_chip_id_err = true;
    }
    else
    {
        test.acc_chip_id_err = false;
    }
    update_status_from_selftest();
}

void bmi088::verify_gyro_chip_id()
{
    uint8_t rx = 0;
    read_reg(cs::gyro, gyro_chip_id_addr, &rx, 1);
    tx_thread_sleep(1);
    if (rx != gyro_chip_id_val)
    {
        test.gyro_chip_id_err = true;
    }
    else
    {
        test.gyro_chip_id_err = false;
    }
    update_status_from_selftest();
}

void bmi088::verify_acc_data()
{
    test.acc_data_err = false;
    update_status_from_selftest();
}

void bmi088::verify_gyro_data()
{
    test.gyro_data_err = false;
    update_status_from_selftest();
}

void bmi088::configure()
{
    tx_thread_sleep(10);

    uint8_t tx = acc_soft_reset_val;
    write_reg(cs::acc, acc_soft_reset_addr, &tx, 1);
    tx_thread_sleep(100);

    tx = acc_pwr_conf_act;
    write_reg(cs::acc, acc_pwr_conf_addr, &tx, 1);
    tx_thread_sleep(10);

    tx = acc_pwr_ctrl_on;
    write_reg(cs::acc, acc_pwr_ctrl_addr, &tx, 1);
    tx_thread_sleep(10);

    tx = acc_range_6g;
    write_reg(cs::acc, acc_range_addr, &tx, 1);
    tx_thread_sleep(5);

    tx = 0xAB;
    write_reg(cs::acc, acc_conf_addr, &tx, 1);
    tx_thread_sleep(5);

    tx = 0x08;
    write_reg(cs::acc, acc_int1_io_ctrl_addr, &tx, 1);
    tx_thread_sleep(5);

    tx = 0x04;
    write_reg(cs::acc, acc_int_map_data_addr, &tx, 1);
    tx_thread_sleep(5);

    tx = gyro_soft_reset_val;
    write_reg(cs::gyro, gyro_soft_reset_addr, &tx, 1);
    tx_thread_sleep(100);

    tx = gyro_range_1000;
    write_reg(cs::gyro, gyro_range_addr, &tx, 1);
    tx_thread_sleep(5);

    tx = static_cast<uint8_t>(gyro_odr_2000_bw_230 | gyro_lpm1_suspend);
    write_reg(cs::gyro, gyro_bandwidth_addr, &tx, 1);
    tx_thread_sleep(5);

    tx = gyro_lpm1_normal;
    write_reg(cs::gyro, gyro_lpm1_addr, &tx, 1);
    tx_thread_sleep(5);

    tx = gyro_drdy_on;
    write_reg(cs::gyro, gyro_int_ctrl_addr, &tx, 1);
    tx_thread_sleep(5);

    tx = 0x00;
    write_reg(cs::gyro, gyro_int_io_conf_addr, &tx, 1);
    tx_thread_sleep(5);

    tx = 0x01;
    write_reg(cs::gyro, gyro_int_io_map_addr, &tx, 1);
    tx_thread_sleep(5);
}

void bmi088::read_acc(accdata* data)
{
    if (data == nullptr)
    {
        return;
    }

    uint8_t buf[acc_xyz_len + 1] = {0};
    int16_t raw[3] = {0};
    read_reg(cs::acc, acc_xyz_addr, buf, acc_xyz_len + 1);

    raw[0] = static_cast<int16_t>((buf[2] << 8) | buf[1]);
    raw[1] = static_cast<int16_t>((buf[4] << 8) | buf[3]);
    raw[2] = static_cast<int16_t>((buf[6] << 8) | buf[5]);

    data->x = static_cast<float>(raw[0]) * accel_6g_sensitivity + accel_preoffset_x;
    data->y = static_cast<float>(raw[1]) * accel_6g_sensitivity + accel_preoffset_y;
    data->z = static_cast<float>(raw[2]) * accel_6g_sensitivity + accel_preoffset_z;
    data->temperature = acc.temperature;
    update_acc_cache(*data);
}

void bmi088::read_gyro(gyrodata* data)
{
    if (data == nullptr)
    {
        return;
    }

    uint8_t buf[gyro_xyz_len] = {0};
    int16_t raw[3] = {0};
    read_reg(cs::gyro, gyro_xyz_addr, buf, gyro_xyz_len);

    raw[0] = static_cast<int16_t>((buf[1] << 8) | buf[0]);
    raw[1] = static_cast<int16_t>((buf[3] << 8) | buf[2]);
    raw[2] = static_cast<int16_t>((buf[5] << 8) | buf[4]);

    data->x = static_cast<float>(raw[0]) * gyro_1000_sensitivity - gyro_offset[0];
    data->y = static_cast<float>(raw[1]) * gyro_1000_sensitivity - gyro_offset[1];
    data->z = static_cast<float>(raw[2]) * gyro_1000_sensitivity - gyro_offset[2];
    update_gyro_cache(*data);
}

void bmi088::read_temperature(float* temp)
{
    if (temp == nullptr)
    {
        return;
    }

    uint8_t buf[temp_len + 1] = {0};
    read_reg(cs::acc, temp_addr, buf, temp_len + 1);
    const uint16_t temp_uint11 = static_cast<uint16_t>((buf[1] << 3) | (buf[2] >> 5));
    int16_t temp_int11 = static_cast<int16_t>(temp_uint11);
    if (temp_uint11 > 1023)
    {
        temp_int11 = static_cast<int16_t>(temp_uint11 - 2048);
    }
    *temp = static_cast<float>(temp_int11) * temp_unit + temp_bias;
    update_temperature_cache(*temp);
}

bool bmi088::read(reading& out)
{
    accdata acc_sample{};
    gyrodata gyro_sample{};
    float temp = 0.0f;

    read_acc(&acc_sample);
    read_gyro(&gyro_sample);
    read_temperature(&temp);

    out.accel = {acc_sample.x, acc_sample.y, acc_sample.z};
    out.gyro = {gyro_sample.x, gyro_sample.y, gyro_sample.z};
    out.temperature = temp;
    out.sensor_time = acc_sample.sensor_time;
    data = out;
    return ready() && valid_temperature(temp);
}

} // namespace imu
