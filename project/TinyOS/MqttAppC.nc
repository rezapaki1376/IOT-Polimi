
#define NEW_PRINTF_SEMANTICS
#include "printf.h"
#include "Mqtt.h"


configuration MqttAppC {}
implementation {
/****** COMPONENTS *****/
  components MainC, MqttC as App;
  //adding other extra components
  components new AMSenderC(AM_RADIO_COUNT_MSG);
  components new AMReceiverC(AM_RADIO_COUNT_MSG);
  components ActiveMessageC;
  // adding timer components
  // timer for Connect
  components new TimerMilliC() as TimerConn;
  components new TimerMilliC() as Timer0;
  // timer for subscription
  components new TimerMilliC() as TimerSub;
  components new TimerMilliC() as TimerNextSub;
  components new TimerMilliC() as TimerNextPub;
  // component for random number generation
  components RandomC;
  
  // if we want to use these codes for tossim we should comment next 2 lines
  // components SerialPrintfC;
   //components SerialStartC;
  
  /****** INTERFACES *****/
  //Boot interface
  App.Boot -> MainC.Boot;
  
  // other extra interfaces such as communication and timer
  App.Receive -> AMReceiverC;
  App.AMSend -> AMSenderC;
  App.AMControl -> ActiveMessageC;
  App.Packet -> AMSenderC;
  
  App.TimerConn -> TimerConn;
  App.Timer0 -> Timer0;
  App.TimerSub -> TimerSub;
  App.TimerNextSub -> TimerNextSub;
  App.TimerNextPub -> TimerNextPub;
  
  App.Random -> RandomC;
}


