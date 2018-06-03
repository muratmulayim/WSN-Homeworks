// $Id: BlinkToRadio.h,v 1.4 2006/12/12 18:22:52 vlahan Exp $

#ifndef BLINKTORADIO_H
#define BLINKTORADIO_H

enum {
  AM_BLINKTORADIO = 6,
  TIMER_MILLI_DISCOVER_THRESHOLD = 100,
  TIMER_PERIOD_MILLI = 250,
  TIMER_PERIOD_MILLI_FOR_RETRY = 50
};

enum STATE{
	STATE_DISCOVER = 0,
	STATE_MESSAGE = 1
};

enum msgType{
  BROADCAST_DISCOVER = 1,
  UNICAST_DISCOVER_RESPONSE = 2,
  UNICAST_MESSAGE = 3
};

/*typedef nx_struct BlinkToRadioMsg {
	nx_uint16_t nodeid;
	nx_uint16_t counter;
} BlinkToRadioMsg;
*/
typedef nx_struct BlinkToRadioMsg {
	nx_uint8_t type;
	nx_uint16_t nodeid;
	nx_uint16_t counter;
} BlinkToRadioMsg;

#endif
