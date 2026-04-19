#include "app.hpp"
#include "adc_drivers.h"
#include "uart_drivers.h"
#include "stm32f1xx_hal.h"

#include <string.h>
#include <stdbool.h>

#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "semphr.h"
#include "event_groups.h"

static QueueHandle_t adcQueue;

extern "C" {
    void HAL_ADC_ConvCpltCallback(ADC_HandleTypeDef* hadc){
        if(hadc->Instance == ADC1){
            BaseType_t xHigherPriorityTaskWoken = pdFALSE;
            uint16_t adcValue = HAL_ADC_GetValue(hadc);
            xQueueSendFromISR(adcQueue, &adcValue, &xHigherPriorityTaskWoken);
            HAL_ADC_Start_IT(hadc);
            portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
        }
    }
}

ADC_HandleTypeDef hadc;
UART_HandleTypeDef huart;

struct SensorData{
    float temperature, current, voltage;
};

class SensorTask {
    public:
    SensorTask(QueueHandle_t inQ, QueueHandle_t outQ) : inputQueue(inQ), outputQueue(outQ) {}
    
    void Start(){
        xTaskCreate(vSensorTask, "SENSORS", 512, this, 3, nullptr);
    }

    private:
    QueueHandle_t inputQueue;
    QueueHandle_t outputQueue;

    static void vSensorTask(void *pvPara){
        SensorTask* task = static_cast<SensorTask*>(pvPara);
        task->run();
    }

    void run(){
        uint16_t adcValue;
        SensorData data;
        const float vREF = 3.3f, ADC_RESOLUTION = 4095.0f;

        while(true){
            if(xQueueReceive(inputQueue, &adcValue, portMAX_DELAY) == pdPASS){
                data.temperature = (adcValue * vREF) / ADC_RESOLUTION;

                float pinVoltage = (static_cast<float>(adcValue) * vREF) / ADC_RESOLUTION;
                const float VOLTAGE_DEVIDER_RATIO = 11.f;
                data.voltage = pinVoltage * VOLTAGE_DEVIDER_RATIO;

                const float SENSITIVITY = 0.185f;
                const float OFFSET = 1.65f;
                data.current = (pinVoltage - OFFSET) / SENSITIVITY;

                xQueueSend(outputQueue, &data, portMAX_DELAY);
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

        while(true){
            if(xQueueReceive(inputQueue, &data, portMAX_DELAY) == pdPASS){
                float temperature = data.temperature, current = data.current, voltage = data.voltage;

                if(temperature > 60){
                    HAL_GPIO_TogglePin(GPIOC, GPIO_PIN_13);
                    HAL_Delay(500);
                    UART_SendData("OVERHEAT!\r\n");
                }
                if(current > 10.0f || current < -10.0f){
                    HAL_GPIO_TogglePin(GPIOC, GPIO_PIN_13);
                    HAL_Delay(500);
                    UART_SendData("Check Current!\r\n");
                }
                if(voltage > 12.6f || voltage < 9.0f){
                    HAL_GPIO_TogglePin(GPIOC, GPIO_PIN_14);
                    HAL_Delay(500);
                    UART_SendData("Check Voltage!\r\n");
                }
                xQueueSend(outputQueue, &data, portMAX_DELAY);
            }
        }
    }
};

void App_Start(void){
    adcQueue = xQueueCreate(10, sizeof(uint16_t));
    QueueHandle_t resultQueue = xQueueCreate(10, sizeof(SensorData));

    static SensorTask sensorTask(adcQueue, resultQueue);
    sensorTask.Start();

    static ControlTask controlTask(adcQueue, resultQueue);
    controlTask.Start();

    HAL_ADC_Start_IT(&hadc);
}