idf_component_register(SRCS "hello_world_main.c"
                       PRIV_REQUIRES spi_flash nvs_flash esp_wifi esp_event esp_netif mqtt
                       INCLUDE_DIRS "")
