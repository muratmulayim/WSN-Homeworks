
#include <Timer.h>
#include "Wsn_hw3.h"

configuration WSN_HW3_AppC {
}
implementation {
  components MainC;
  components LedsC;
  components WSN_HW3_C as App;
  components new TimerMilliC() as Timer0;
  components new TimerMilliC() as Timer1;
  components ActiveMessageC;
  components new AMSenderC(AM_BLINKTORADIO);
  components new AMReceiverC(AM_BLINKTORADIO);
  components new QueueC(QueueEntry, MAX_QUEUE_SIZE) as Queue;
  components RandomC;
  

  App.Boot -> MainC;
  App.Leds -> LedsC;
  App.Timer0 -> Timer0;
  App.Timer1 -> Timer1;
  App.Packet -> AMSenderC;
  App.AMPacket -> AMSenderC;
  App.AMControl -> ActiveMessageC;
  App.AMSend -> AMSenderC;
  App.Receive -> AMReceiverC;
  App.PacketAcknowledgements -> ActiveMessageC;
  App.Random -> RandomC;
  App.msgQueue -> Queue;
}
