#include "app.hpp"
#include "FreeRTOS.h"
#include "task.h"
#include "stm32f1xx_hal.h"
#include "SystemClockConfig.h"
#include <string.h>

void System_Init(){
    HAL_Init();
    SystemClock_Config();
}
UART_HandleTypeDef huart;

void Error_Handler(){
    const char* msg = "System Error\r\n";

    while(true){
        if(huart.Instance != nullptr){
            HAL_UART_Transmit_DMA(&huart, (uint8_t *)msg, strlen(msg));
            HAL_GPIO_TogglePin(GPIOC, GPIO_PIN_13);
            HAL_Delay(500);
        }
    }
}

int main(void){
    System_Init();
    App_Start();
    vTaskStartScheduler();
    
    while(true);
}