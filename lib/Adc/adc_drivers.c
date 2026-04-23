#include "adc_drivers.h"
#include "stm32f1xx_hal.h"

ADC_HandleTypeDef hadc;

void ADC_Init(void){
    hadc.Instance = ADC1;
    hadc.Init.ScanConvMode = ADC_SCAN_DISABLE;
    hadc.Init.ContinuousConvMode = DISABLE;
    hadc.Init.DiscontinuousConvMode = DISABLE;
    hadc.Init.ExternalTrigConv = ADC_SOFTWARE_START;
    hadc.Init.NbrOfConversion = 3;
    hadc.Init.DataAlign = ADC_DATAALIGN_RIGHT;

    if(HAL_ADC_Init(&hadc) != HAL_OK){
        while(1);
    }
    HAL_ADCEx_Calibration_Start(&hadc);
}

uint16_t ADC_Read(uint32_t channel){
    ADC_ChannelConfTypeDef sConfig = {0};

    sConfig.Channel = channel;
    sConfig.Rank = ADC_REGULAR_RANK_1;
    sConfig.SamplingTime = ADC_SAMPLETIME_28CYCLES_5;

    if(HAL_ADC_ConfigChannel(&hadc, &sConfig) != HAL_OK){
        while(1);
    }

    HAL_ADC_Start(&hadc);
    if(HAL_ADC_PollForConversion(&hadc, 10) != HAL_OK){
        while(1);
    }

    uint16_t adcValue = HAL_ADC_GetValue(&hadc);
    
    return adcValue; 
}

void HAL_ADC_MspInit(ADC_HandleTypeDef* hadc){
    GPIO_InitTypeDef gpio = {0};

    if(hadc->Instance == ADC1){
        __HAL_RCC_ADC1_CLK_ENABLE();
        __HAL_RCC_GPIOA_CLK_ENABLE();
        
        gpio.Pin = GPIO_PIN_0 | GPIO_PIN_1 | GPIO_PIN_2;
        gpio.Mode = GPIO_MODE_ANALOG;
        HAL_GPIO_Init(GPIOA, &gpio);
    }
}