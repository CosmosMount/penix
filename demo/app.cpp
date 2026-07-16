#include "imu_demo.hpp"
#include "motor_demo.hpp"
#include "usart_demo.hpp"
#include "usb_demo.hpp"

extern "C" void app_start()
{
    // demo::imu::run();
    demo::motor::run();
    // demo::usart::start();
    // demo::usb::start();
}
