#include "usart_demo.hpp"
#include "usb_demo.hpp"

extern "C" void app_start()
{
    // demo::usart::start();
    demo::usb::start();
}