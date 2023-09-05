
 
#include "RadioRoute.h"


configuration RadioRouteAppC {}
implementation {
/****** COMPONENTS *****/
  //add the other components here
  components MainC, RadioRouteC as App, LedsC;
  components new AMSenderC(AM_RADIO_COUNT_MSG);
  components new AMReceiverC(AM_RADIO_COUNT_MSG);
  components ActiveMessageC;
  // adding 2 timers components
  components new TimerMilliC() as Timer0;
  components new TimerMilliC() as Timer1;

  
  /****** INTERFACES *****/
  //Boot interface
  // receive/ sender/ control / leds / timers
  
  /****** Wire the other interfaces down here *****/
  App.Boot -> MainC.Boot;
  App.Receive -> AMReceiverC;
  App.AMSend -> AMSenderC;
  App.AMControl -> ActiveMessageC;
  App.Leds -> LedsC;
  App.Timer0 -> Timer0;
  App.Timer1 -> Timer1;
  App.Packet -> AMSenderC;
}


