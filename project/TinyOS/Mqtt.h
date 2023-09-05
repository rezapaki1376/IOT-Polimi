

#ifndef MQTT_H
#define MQTT_H

typedef nx_struct mqtt_packet {
// defining the message structure.
  nx_uint8_t type;
  nx_uint16_t sender;
  nx_uint8_t topic;
  nx_uint16_t value;
  
} mqtt_packet_t;

// we use these constatnt variables to define the type of the messages and this is because make codding simple. 
enum {
  CONN = 0,
  CONNACK = 1,
  SUB = 2,
  SUBACK = 3,
  PUB = 4,
  AM_RADIO_COUNT_MSG = 10,
};

#endif
