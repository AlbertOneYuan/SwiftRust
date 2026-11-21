#pragma once
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
typedef struct {
    uint8_t *data;
    size_t length;
    size_t width;
    size_t height;
    size_t display;
} RDNativeFrame;
char *rd_ios_request(const char *request);
void rd_ios_free_string(char *value);
bool rd_ios_take_frame(RDNativeFrame *frame);
bool rd_ios_take_window_frame(const char *context, RDNativeFrame *frame);
void rd_ios_free_bytes(uint8_t *data, size_t length);
