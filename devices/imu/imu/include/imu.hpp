#pragma once

#include "pid.hpp"

#include <cstdint>

namespace imu
{

struct vector3
{
    float x = 0.0f;
    float y = 0.0f;
    float z = 0.0f;
};

struct accdata
{
    float x = 0.0f;
    float y = 0.0f;
    float z = 0.0f;
    float sensor_time = 0.0f;
    float temperature = 0.0f;
};

struct gyrodata
{
    float x = 0.0f;
    float y = 0.0f;
    float z = 0.0f;
};

struct reading
{
    vector3 accel{};
    vector3 gyro{};
    float temperature = 0.0f;
    float sensor_time = 0.0f;
};

struct selftest
{
    bool acc_chip_id_err = true;
    bool acc_data_err = true;
    bool gyro_chip_id_err = true;
    bool gyro_data_err = true;
    bool init_err = true;
    bool calibrate_err = false;
    bool temp_ctrl_err = true;
};

struct status
{
    bool initialized = false;
    bool accel_ok = false;
    bool gyro_ok = false;
    bool calibrated = false;
    bool temperature_control_ok = false;
};

class imu
{
public:
    virtual ~imu() = default;

    virtual void configure() = 0;
    virtual void calibrate() = 0;
    virtual bool read_acc(accdata* data) = 0;
    virtual bool read_gyro(gyrodata* data) = 0;
    virtual bool read_temperature(float* temp) = 0;
    virtual bool read(reading& data) = 0;
    virtual void verify_acc_chip_id() = 0;
    virtual void verify_gyro_chip_id() = 0;
    virtual void verify_acc_data() = 0;
    virtual void verify_gyro_data() = 0;
    virtual void temperature_control(float target_temp) = 0;

    bool ready() const { return state.initialized; }
    const reading& latest() const { return data; }
    vector3 acceleration() const { return data.accel; }
    vector3 angular_rate() const { return data.gyro; }
    float temperature() const { return data.temperature; }
    const status& diagnostics() const { return state; }

protected:
    void update_acc_cache(const accdata& value)
    {
        acc = value;
        data.accel = {value.x, value.y, value.z};
        data.sensor_time = value.sensor_time;
        data.temperature = value.temperature;
    }

    void update_gyro_cache(const gyrodata& value)
    {
        gyro = value;
        data.gyro = {value.x, value.y, value.z};
    }

    void update_temperature_cache(float value)
    {
        acc.temperature = value;
        data.temperature = value;
    }

    void update_status_from_selftest()
    {
        test.init_err = test.acc_chip_id_err || test.gyro_chip_id_err;
        state.initialized = !test.init_err;
        state.accel_ok = !test.acc_chip_id_err && !test.acc_data_err;
        state.gyro_ok = !test.gyro_chip_id_err && !test.gyro_data_err;
        state.calibrated = !test.calibrate_err;
        state.temperature_control_ok = !test.temp_ctrl_err;
    }

public:
    accdata acc{};
    gyrodata gyro{};
    selftest test{};
    reading data{};
    status state{};

    control::pid temp_pid{0.1f, 0.0f, 0.0f, 10.0f, 3.0f, control::pid_mode::position};
    float target_temp = 0.0f;
};

} // namespace imu
