#include "app.hpp"
#include "FreeRTOS.h"
#include "task.h"
#include "stm32f1xx_hal.h"
#include "SystemClockConfig.h"

int main(void){
    HAL_Init();
    SystemClock_Config();
    
    App_Start();
    vTaskStartScheduler();

    while(1);
}