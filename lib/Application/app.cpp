#include "app.hpp"
#include "adc_drivers.h"
#include "uart_drivers.h"
#include "stm32f1xx_hal.h"

#include <string.h>
#include <stdbool.h>
#include <stdio.h>
#include <math.h>

#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "semphr.h"
#include "event_groups.h"

struct SensorData{
    float temperature, current, voltage;
};

extern "C" {
    void vApplicationIdleHook(void){
        __WFI();
    }
}

QueueHandle_t logQueue;

class SensorTask {
    public:
    SensorTask(QueueHandle_t outQ) : outputQueue(outQ) {}
    
    void Start(){
        xTaskCreate(vSensorTask, "SENSORS", 512, this, 3, nullptr);
    }

    private:
    QueueHandle_t outputQueue;

    static void vSensorTask(void *pvPara){
        SensorTask* task = static_cast<SensorTask*>(pvPara);
        task->run();
    }

    void run(){
        SensorData data;
        constexpr float vREF = 3.3f, ADC_RESOLUTION = 4095.0f;
        constexpr float VOLTAGE_DIVIDER_RATIO = 11.f;
        constexpr float SENSITIVITY = 0.185f; // for ACS712
        constexpr float OFFSET = 1.65f;

        constexpr TickType_t interval = pdMS_TO_TICKS(1000);
        TickType_t lastWakeTime = xTaskGetTickCount();

        while(true){
            uint16_t rawTemperature = ADC_Read(ADC_CHANNEL_0);
            uint16_t rawCurrent = ADC_Read(ADC_CHANNEL_1);
            uint16_t rawVoltage = ADC_Read(ADC_CHANNEL_2);

            float tPin = (static_cast<float>(rawTemperature) * vREF) / ADC_RESOLUTION;
            data.temperature = tPin * 100.0f;
            float vPin = (static_cast<float>(rawVoltage) * vREF) / ADC_RESOLUTION;
            data.voltage = vPin * VOLTAGE_DIVIDER_RATIO;
            float cPin = (static_cast<float>(rawCurrent) * vREF) / ADC_RESOLUTION;
            data.current = (cPin - OFFSET) / SENSITIVITY;

            const int32_t v_mV = (int32_t)lroundf(data.voltage * 1000.0f);
            const int32_t i_mA = (int32_t)lroundf(data.current * 1000.0f);
            const int32_t t_cC = (int32_t)lroundf(data.temperature * 100.0f);
            char line[64];
            const int n = snprintf(line, sizeof(line), "%ld,%ld,%ld\n", (long)v_mV, (long)i_mA, (long)t_cC);
            if(n > 0){
                xQueueSend(logQueue, line, 0);
            }

            xQueueOverwrite(outputQueue, &data);
            vTaskDelayUntil(&lastWakeTime, interval);
        }
    }
};

class LoggerTask {
    public:
    LoggerTask(QueueHandle_t q) : logQueue(q) {}

    void Start(){
        xTaskCreate(vLoggerTask, "LOGGER", 256, this, 1, nullptr);
    }

    private:
    QueueHandle_t logQueue;

    static void vLoggerTask(void *pvPara){
        LoggerTask* task = static_cast<LoggerTask*>(pvPara);
        task->run();
    }

    void run(){
        char msg[64];

        while(true){
            if(xQueueReceive(logQueue, msg, portMAX_DELAY) == pdPASS){
                UART_SendData(msg);
            }
        }
    }
};

class ControlTask {
    public:
    ControlTask(QueueHandle_t inQ, QueueHandle_t outQ) : inputQueue(inQ), outputQueue(outQ) {}

    void Start(){
        xTaskCreate(vControlTask, "CONTROL SYSTEMS", 256, this, 2, nullptr);
    }

    private:
    QueueHandle_t inputQueue, outputQueue;

    static void vControlTask(void *pvPara){
        ControlTask* task = static_cast<ControlTask*>(pvPara);
        task->run();
    }

    void run(){
        SensorData data;
        TickType_t lastTempTime = 0;
        TickType_t lastCurrentTime = 0;
        TickType_t lastVoltageTime = 0;

        constexpr TickType_t interval = pdMS_TO_TICKS(1000);

        while(true){
            if(xQueueReceive(inputQueue, &data, portMAX_DELAY) == pdPASS){
                TickType_t now = xTaskGetTickCount();
                float temperature = data.temperature, current = data.current, voltage = data.voltage;
                
                if(temperature > 60.0f){
                    if(now - lastTempTime >= interval){
                        HAL_GPIO_WritePin(GPIOC, GPIO_PIN_13, GPIO_PIN_RESET);
                        char msg[64];
                        snprintf(msg, sizeof(msg), "OVERHEAT!\r\n");
                        xQueueSend(logQueue, msg, 0);
                        lastTempTime = now;
                    }
                } else {
                    HAL_GPIO_WritePin(GPIOC, GPIO_PIN_13, GPIO_PIN_SET);
                }
                if(current > 10.0f || current < -10.0f){
                    if(now - lastCurrentTime >= interval){
                        HAL_GPIO_WritePin(GPIOC, GPIO_PIN_14, GPIO_PIN_RESET);
                        char msg[64];
                        snprintf(msg, sizeof(msg), "Check Current!\r\n");
                        xQueueSend(logQueue, msg, 0);
                        lastCurrentTime = now;
                    }
                } else {
                    HAL_GPIO_WritePin(GPIOC, GPIO_PIN_14, GPIO_PIN_SET);
                }
                if(voltage > 12.0f || voltage < 9.0f){
                    if(now - lastVoltageTime >= interval){
                        HAL_GPIO_WritePin(GPIOC, GPIO_PIN_15, GPIO_PIN_RESET);
                        char msg[64];
                        snprintf(msg, sizeof(msg), "Check Voltage!\r\n");
                        xQueueSend(logQueue, msg, 0);
                        lastVoltageTime = now;
                    }
                } else {
                    HAL_GPIO_WritePin(GPIOC, GPIO_PIN_15, GPIO_PIN_SET);
                }
            }
        }
    }
};

void App_Start(void){
    __HAL_RCC_GPIOC_CLK_ENABLE();
    static QueueHandle_t adcQueue = xQueueCreate(1, sizeof(SensorData));
    logQueue = xQueueCreate(10, sizeof(char[64]));

    ADC_Init();
    UART_Init();

    GPIO_InitTypeDef gpio = {0};
    gpio.Pin = GPIO_PIN_13 | GPIO_PIN_14 | GPIO_PIN_15;
    gpio.Mode = GPIO_MODE_OUTPUT_PP;
    gpio.Speed = GPIO_SPEED_FREQ_LOW;
    HAL_GPIO_Init(GPIOC, &gpio);

    static SensorTask sensorTask(adcQueue);
    sensorTask.Start();

    static LoggerTask loggerTask(logQueue);
    loggerTask.Start();

    static ControlTask controlTask(adcQueue, nullptr);
    controlTask.Start();
}