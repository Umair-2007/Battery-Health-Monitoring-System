#include "uart_drivers.h"
#include "stm32f1xx_hal.h"
#include "string.h"

UART_HandleTypeDef huart;

void UART_Init(){
    huart.Instance = USART1;
    huart.Init.BaudRate = 9600;
    huart.Init.HwFlowCtl = UART_HWCONTROL_NONE;
    huart.Init.WordLength = UART_WORDLENGTH_8B;
    huart.Init.StopBits = UART_STOPBITS_1;
    huart.Init.Parity = UART_PARITY_NONE;
    huart.Init.OverSampling = UART_OVERSAMPLING_16;
    huart.Init.Mode = UART_MODE_TX_RX;

    if(HAL_UART_Init(&huart) != HAL_OK){
        while(1){
            UART_SendData("System Error!\r\n");
        }
    }
}

void HAL_UART_MspInit(UART_HandleTypeDef* huart){
    GPIO_InitTypeDef gpio = {0};

    if(huart->Instance == USART1){
        __HAL_RCC_USART1_CLK_ENABLE();
        __HAL_RCC_GPIOA_CLK_ENABLE();

        gpio.Pin = GPIO_PIN_9;
        gpio.Mode = GPIO_MODE_AF_PP;
        gpio.Speed = GPIO_SPEED_FREQ_HIGH;
        HAL_GPIO_Init(GPIOA, &gpio);

        gpio.Pin = GPIO_PIN_10;
        gpio.Mode = GPIO_MODE_INPUT;
        gpio.Pull = GPIO_PULLUP;
        HAL_GPIO_Init(GPIOA, &gpio);
    }
}

void UART_SendData(const char *data){
    if(data == NULL){
        while(1){
            UART_SendData("System Error!\r\n");
        }
    }

    HAL_UART_Transmit_DMA(&huart, (uint8_t *)data, strlen(data));
}