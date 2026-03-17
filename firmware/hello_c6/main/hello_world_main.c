/*
 * SPDX-FileCopyrightText: 2010-2022 Espressif Systems (Shanghai) CO LTD
 *
 * SPDX-License-Identifier: CC0-1.0
 */

#include <inttypes.h>
#include <stdio.h>
#include <string.h>

#include "freertos/FreeRTOS.h"
#include "freertos/event_groups.h"
#include "freertos/queue.h"
#include "freertos/task.h"

#include "esp_chip_info.h"
#include "esp_event.h"
#include "esp_flash.h"
#include "esp_log.h"
#include "esp_mac.h"
#include "esp_netif.h"
#include "esp_random.h"
#include "esp_system.h"
#include "esp_timer.h"
#include "esp_wifi.h"
#include "mqtt_client.h"
#include "nvs_flash.h"
#include "sdkconfig.h"

static const char *TAG = "iot_logger";

static EventGroupHandle_t s_wifi_event_group;
static esp_mqtt_client_handle_t s_mqtt_client;
static QueueHandle_t s_sample_queue;
static bool s_mqtt_connected;
static int s_wifi_retry_num;

#define WIFI_CONNECTED_BIT BIT0
#define WIFI_FAIL_BIT BIT1
#define WIFI_MAXIMUM_RETRY 10

#ifndef CONFIG_APP_BUFFER_SIZE
#define CONFIG_APP_BUFFER_SIZE 32
#endif

typedef struct {
    int64_t ts_utc;
    float temperature_c;
    float humidity_pct;
    float battery_v;
} sensor_sample_t;

static void log_chip_information(void)
{
    esp_chip_info_t chip_info;
    uint32_t flash_size = 0;

    esp_chip_info(&chip_info);
    ESP_LOGI(TAG, "Target: %s, cores: %d, revision: v%u.%u",
             CONFIG_IDF_TARGET,
             chip_info.cores,
             chip_info.revision / 100,
             chip_info.revision % 100);

    if (esp_flash_get_size(NULL, &flash_size) == ESP_OK) {
        ESP_LOGI(TAG, "Flash: %" PRIu32 "MB (%s)",
                 flash_size / (uint32_t)(1024 * 1024),
                 (chip_info.features & CHIP_FEATURE_EMB_FLASH) ? "embedded" : "external");
    }
    ESP_LOGI(TAG, "Min free heap: %" PRIu32 " bytes", esp_get_minimum_free_heap_size());
}

static void format_device_id(char *buffer, size_t buffer_len)
{
    if (strlen(CONFIG_APP_DEVICE_ID) > 0) {
        snprintf(buffer, buffer_len, "%s", CONFIG_APP_DEVICE_ID);
        return;
    }

    uint8_t mac[6] = {0};
    esp_read_mac(mac, ESP_MAC_WIFI_STA);
    snprintf(buffer, buffer_len, "esp32c6-%02X%02X%02X", mac[3], mac[4], mac[5]);
}

static void wifi_event_handler(void *arg,
                               esp_event_base_t event_base,
                               int32_t event_id,
                               void *event_data)
{
    if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_START) {
        esp_wifi_connect();
    } else if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_DISCONNECTED) {
        if (s_wifi_retry_num < WIFI_MAXIMUM_RETRY) {
            esp_wifi_connect();
            s_wifi_retry_num++;
            ESP_LOGW(TAG, "Wi-Fi disconnected, retry %d/%d", s_wifi_retry_num, WIFI_MAXIMUM_RETRY);
        } else {
            xEventGroupSetBits(s_wifi_event_group, WIFI_FAIL_BIT);
        }
    } else if (event_base == IP_EVENT && event_id == IP_EVENT_STA_GOT_IP) {
        ip_event_got_ip_t *event = (ip_event_got_ip_t *) event_data;
        s_wifi_retry_num = 0;
        ESP_LOGI(TAG, "Wi-Fi connected, got IP: " IPSTR, IP2STR(&event->ip_info.ip));
        xEventGroupSetBits(s_wifi_event_group, WIFI_CONNECTED_BIT);
    }
}

static esp_err_t wifi_init_sta(void)
{
    s_wifi_event_group = xEventGroupCreate();
    if (s_wifi_event_group == NULL) {
        return ESP_FAIL;
    }

    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());
    esp_netif_create_default_wifi_sta();

    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));

    ESP_ERROR_CHECK(esp_event_handler_instance_register(WIFI_EVENT,
                                                        ESP_EVENT_ANY_ID,
                                                        &wifi_event_handler,
                                                        NULL,
                                                        NULL));
    ESP_ERROR_CHECK(esp_event_handler_instance_register(IP_EVENT,
                                                        IP_EVENT_STA_GOT_IP,
                                                        &wifi_event_handler,
                                                        NULL,
                                                        NULL));

    wifi_config_t wifi_config = {0};
    snprintf((char *) wifi_config.sta.ssid, sizeof(wifi_config.sta.ssid), "%s", CONFIG_APP_WIFI_SSID);
    snprintf((char *) wifi_config.sta.password, sizeof(wifi_config.sta.password), "%s", CONFIG_APP_WIFI_PASSWORD);
    wifi_config.sta.threshold.authmode =
        (strlen(CONFIG_APP_WIFI_PASSWORD) == 0) ? WIFI_AUTH_OPEN : WIFI_AUTH_WPA2_PSK;

    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &wifi_config));
    ESP_ERROR_CHECK(esp_wifi_start());

    EventBits_t bits = xEventGroupWaitBits(s_wifi_event_group,
                                           WIFI_CONNECTED_BIT | WIFI_FAIL_BIT,
                                           pdFALSE,
                                           pdFALSE,
                                           portMAX_DELAY);

    if (bits & WIFI_CONNECTED_BIT) {
        return ESP_OK;
    }
    return ESP_FAIL;
}

static void mqtt_event_handler(void *handler_args,
                               esp_event_base_t base,
                               int32_t event_id,
                               void *event_data)
{
    (void) handler_args;
    (void) base;
    (void) event_data;

    switch ((esp_mqtt_event_id_t) event_id) {
        case MQTT_EVENT_CONNECTED:
            s_mqtt_connected = true;
            ESP_LOGI(TAG, "MQTT connected");
            break;
        case MQTT_EVENT_DISCONNECTED:
            s_mqtt_connected = false;
            ESP_LOGW(TAG, "MQTT disconnected");
            break;
        case MQTT_EVENT_ERROR:
            ESP_LOGE(TAG, "MQTT event error");
            break;
        default:
            break;
    }
}

static void mqtt_start(void)
{
    esp_mqtt_client_config_t mqtt_cfg = {
        .broker.address.uri = CONFIG_APP_MQTT_BROKER_URI,
    };

    s_mqtt_client = esp_mqtt_client_init(&mqtt_cfg);
    ESP_ERROR_CHECK(esp_mqtt_client_register_event(s_mqtt_client,
                                                   ESP_EVENT_ANY_ID,
                                                   mqtt_event_handler,
                                                   NULL));
    ESP_ERROR_CHECK(esp_mqtt_client_start(s_mqtt_client));
}

static void generate_fake_sensor_task(void *pvParameters)
{
    (void) pvParameters;
    ESP_LOGI(TAG, "Starting fake sensor producer (queue depth=%d)", CONFIG_APP_BUFFER_SIZE);

    while (true) {
        sensor_sample_t sample = {
            .ts_utc = esp_timer_get_time() / 1000000,
            .temperature_c = 18.0f + ((float) (esp_random() % 1700) / 100.0f),
            .humidity_pct = 30.0f + ((float) (esp_random() % 5500) / 100.0f),
            .battery_v = 3.5f + ((float) (esp_random() % 700) / 1000.0f),
        };

        if (xQueueSend(s_sample_queue, &sample, 0) != pdTRUE) {
            sensor_sample_t dropped;
            if (xQueueReceive(s_sample_queue, &dropped, 0) == pdTRUE && xQueueSend(s_sample_queue, &sample, 0) == pdTRUE) {
                ESP_LOGW(TAG, "Buffer full, dropped oldest sample and kept newest");
            } else {
                ESP_LOGW(TAG, "Buffer full, sample dropped");
            }
        }

        vTaskDelay(pdMS_TO_TICKS(CONFIG_APP_PUBLISH_INTERVAL_SEC * 1000));
    }
}

static void publish_buffered_sensor_task(void *pvParameters)
{
    (void) pvParameters;
    char payload[256];
    char device_id[40];
    sensor_sample_t sample;

    format_device_id(device_id, sizeof(device_id));
    ESP_LOGI(TAG, "Starting buffered publisher for device_id=%s topic=%s", device_id, CONFIG_APP_MQTT_TOPIC);

    while (true) {
        if (!s_mqtt_connected) {
            vTaskDelay(pdMS_TO_TICKS(1000));
            continue;
        }

        if (xQueueReceive(s_sample_queue, &sample, pdMS_TO_TICKS(1000)) == pdTRUE) {
            snprintf(payload,
                     sizeof(payload),
                     "{\"device_id\":\"%s\",\"ts_utc\":%lld,\"temperature_c\":%.2f,\"humidity_pct\":%.2f,\"battery_v\":%.3f,\"fw_version\":\"%s\"}",
                     device_id,
                     (long long) sample.ts_utc,
                     sample.temperature_c,
                     sample.humidity_pct,
                     sample.battery_v,
                     IDF_VER);

            int msg_id = esp_mqtt_client_publish(s_mqtt_client, CONFIG_APP_MQTT_TOPIC, payload, 0, 1, 0);
            if (msg_id < 0) {
                ESP_LOGW(TAG, "Publish failed, sample may be lost");
            } else {
                ESP_LOGI(TAG, "Published (msg_id=%d): %s", msg_id, payload);
            }
        }
    }
}

void app_main(void)
{
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);

    log_chip_information();

    if (strlen(CONFIG_APP_WIFI_SSID) == 0 || strlen(CONFIG_APP_MQTT_BROKER_URI) == 0) {
        ESP_LOGE(TAG, "Missing config. Set APP_WIFI_SSID and APP_MQTT_BROKER_URI in menuconfig.");
        return;
    }

    if (wifi_init_sta() != ESP_OK) {
        ESP_LOGE(TAG, "Wi-Fi connect failed");
        return;
    }

    s_sample_queue = xQueueCreate(CONFIG_APP_BUFFER_SIZE, sizeof(sensor_sample_t));
    if (s_sample_queue == NULL) {
        ESP_LOGE(TAG, "Failed to create sample buffer queue");
        return;
    }

    mqtt_start();
    xTaskCreate(generate_fake_sensor_task, "fake_sensor_gen", 3072, NULL, 5, NULL);
    xTaskCreate(publish_buffered_sensor_task, "fake_sensor_pub", 4096, NULL, 5, NULL);
}
