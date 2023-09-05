

#ifndef RADIO_ROUTE_H
#define RADIO_ROUTE_H

// Here is the definition of the message that we are using.
/* We have 3 types of messages but we should use a single structure. Because of this we considered value and cost the same. */
 
typedef nx_struct radio_route_msg {
  nx_uint8_t type;
  nx_uint16_t sender;
  nx_uint16_t destination;
  nx_uint16_t value; // is equal to the cost for type 2 message
} radio_route_msg_t;

enum {
  AM_RADIO_COUNT_MSG = 10,
};

#endif
