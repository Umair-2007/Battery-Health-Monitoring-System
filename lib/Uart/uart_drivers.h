#ifndef UART_DRIVERS_H
#define UART_DRIVERS_H

#include <stdint.h>
#include "stm32f1xx_hal.h"

#ifdef __cplusplus
extern "C" {
    #endif
    
    void UART_Init();
    void UART_SendData(const char* data);
    void HAL_UART_MspInit(UART_HandleTypeDef* huart);

    #ifdef __cplusplus
}

#endif
#endif