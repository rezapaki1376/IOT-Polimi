
/*
*	IMPORTANT:
*	The code will be avaluated based on:
*		Code design  
*
*/
 
 
#include "Timer.h"
#include "RadioRoute.h"


module RadioRouteC @safe() {
  uses {
  
  
    /****** INTERFACES *****/
    //interfaces for communication
	//interface for timers
	//interface for LED
    //other interfaces, if needed
    
    interface Boot;
    interface Receive;
    interface AMSend;
    interface SplitControl as AMControl;
    interface Leds;
    interface Timer<TMilli> as Timer0;
  	interface Timer<TMilli> as Timer1;
    interface Packet;
  }
}
implementation {
  // definign a structure for routing table.
  typedef nx_struct rt_struct{
  	nx_uint16_t destination;
  	nx_uint16_t Next_Hop;
  	nx_uint16_t cost; // cost of the path
  } rt_struct;
  // defining routing table here.
  rt_struct routing_table[6];
  // Variables to store the message to send
  message_t packet;
  message_t queued_packet;
  uint16_t queue_addr;
  uint16_t time_delays[7]={61,173,267,371,479,583,689}; //Time delay in milli seconds
  bool route_req_sent=FALSE;
  bool route_rep_sent=FALSE;
  
    // defining student ID as a string
  const char *student_id = "10832693";
  uint16_t Node6_LED_status[30]; 
  // flag for checking if the message in sent or not
  bool msg_sent_flag = FALSE;
  // define variable to count the messages 
  uint16_t msgs_number = 0;
  // variable to see how many elements will be added to the routing table
  uint8_t rt_elements = 0;
  bool locked;
  // actual send function declaration
  bool actual_send (uint16_t address, message_t* packet);
  // generate send function declaration. this function shouldn't be modified
  bool generate_send (uint16_t address, message_t* packet, uint8_t type);
  // the custom functions that we used 
  void Route_Req_Msg (uint16_t node_requested);
  void Route_Rep_Msg(uint16_t node_requested, uint16_t cost);
  void Data_Message_Send(uint16_t dest, uint16_t value);
  uint8_t Dest_searching(uint16_t dest);
  // function for routing table initializing
  void routing_table_initialize ();
  
 
  void routing_table_initialize(){
  	uint16_t k; 
    for(k=0; k<6; k++){
  	  routing_table[k].destination = 0;
  	  routing_table[k].Next_Hop = 0;
  	  routing_table[k].cost = 0;
  	}
  }
  uint8_t Dest_searching(uint16_t dest){
  	uint16_t k;
  	/* simply here we are checking that if the destination is reachable from current node or not. if this is not reachable then return 0 and in this case we need to broadcast route reply or route request. But if it's reachable return the index of the node.*/
  	if (rt_elements != 0){
  	for (k=0; k<rt_elements; k++){
  	  if(routing_table[k].destination == dest){
  	  	return k+1;
  	}
  	else{
  		return 0;
  	   }}}}
  
  // define data message send function
  void Data_Message_Send(uint16_t dest, uint16_t value){
  	if (!msg_sent_flag){
  	  uint8_t rt_currentIndex = Dest_searching(dest);
  	  // define type as zero for Data messages
  	  uint8_t type = 0;
  	  // just define rcm as a message.then fill it
  	  radio_route_msg_t* rcm = (radio_route_msg_t*)call Packet.getPayload(&packet, sizeof(radio_route_msg_t));
  	  if (rcm == NULL) {
	  	return;
	  }
  	  // filling type
  	  rcm->type = type;
  	  // sender node
  	  rcm->sender = TOS_NODE_ID;
  	  // final destination::::::: in this case it is 7
  	  rcm->destination = dest;
  	  // explicit value of message
  	  rcm->value = value;  	
  	  generate_send(routing_table[rt_currentIndex-1].Next_Hop, &packet, type);
  	  msg_sent_flag = TRUE;
  	  dbg("radio_send", "Data message generated with type: %u\tand destination: %u\tand sender: %u\tand value: %u \n", rcm->type, rcm->destination, rcm->sender, rcm->value);
  	}}
  
  
  // sending route request message
  void Route_Req_Msg(uint16_t node_requested){
  // in the beggining route_req_sent is false
  	if (!route_req_sent){
  	// this is route req message then give it type=1 
    uint8_t type = 1;
    // just define rcm as a message.then fill it
  	radio_route_msg_t* rcm = (radio_route_msg_t*)call Packet.getPayload(&packet, sizeof(radio_route_msg_t));
  	if (rcm == NULL) {
	  return;
	}
  	rcm->type = type;
  	// in this case there is no any sender then put it zero
  	rcm->sender = 0;
  	// just node_requested is exist.
  	rcm->destination = node_requested;
  	// there is no value in this type of message.
  	rcm->value = 0;
  	// broadcast this message 
  	generate_send(AM_BROADCAST_ADDR, &packet, type);
  	dbg("radio_send", "route request message generated with type: %u\tand destination: %u \n", rcm->type, rcm->destination);
  	}
  }
  
  // defining route reply message function
  void Route_Rep_Msg(uint16_t node_requested, uint16_t cost){
  // route_rep_sent is FALSE from the beggining of the code
  	if (!route_rep_sent){
  	// define the type = 2 for route rep messages
  	uint8_t type = 2;
  	// just define rcm as a message.then fill it
  	radio_route_msg_t* rcm = (radio_route_msg_t*)call Packet.getPayload(&packet, sizeof(radio_route_msg_t));
  	if (rcm == NULL) {
	  return;
	}
  	// filling the type of message
  	rcm->type = type;
  	// define the sender node
  	rcm->sender = (uint16_t) TOS_NODE_ID;
  	// define the node requested
  	rcm->destination = node_requested;
  	// consider value as cost for route reply messages
  	rcm->value = cost;
  	// broadcast this message 
  	generate_send(AM_BROADCAST_ADDR, &packet, type);
  	dbg("radio_send", "route reply message generated with type: %u\tand destination: %u\tand sender: %u\tand value: %u \n", rcm->type, rcm->destination, rcm->sender, rcm->value);
  	}
  }
  
  bool generate_send (uint16_t address, message_t* packet, uint8_t type){
  /*
  * 
  * Function to be used when performing the send after the receive message event.
  * It store the packet and address into a global variable and start the timer execution to schedule the send.
  * It allow the sending of only one message for each REQ and REP type
  * @Input:
  *		address: packet destination address
  *		packet: full packet to be sent (Not only Payload)
  *		type: payload message type
  *
  * MANDATORY: DO NOT MODIFY THIS FUNCTION
  */
  	if (call Timer0.isRunning()){
  		return FALSE;
  	}else{
  	if (type == 1 && !route_req_sent ){
  		route_req_sent = TRUE;
  		call Timer0.startOneShot( time_delays[TOS_NODE_ID-1] );
  		queued_packet = *packet;
  		queue_addr = address;
  	}else if (type == 2 && !route_rep_sent){
  	  	route_rep_sent = TRUE;
  		call Timer0.startOneShot( time_delays[TOS_NODE_ID-1] );
  		queued_packet = *packet;
  		queue_addr = address;
  	}else if (type == 0){
  		call Timer0.startOneShot( time_delays[TOS_NODE_ID-1] );
  		queued_packet = *packet;
  		queue_addr = address;
  	}
  	}
  	return TRUE;
  }
  
  event void Timer0.fired() {
  	/*
  	* Timer triggered to perform the send.
  	* MANDATORY: DO NOT MODIFY THIS FUNCTION
  	*/
  	actual_send (queue_addr, &queued_packet);
  }
  
  
  bool actual_send (uint16_t address, message_t* packet){
	/*
	* Implement here the logic to perform the actual send of the packet using the tinyOS interfaces
	*/
	if (!locked) {
	if (call AMSend.send(address, packet, sizeof(radio_route_msg_t)) == SUCCESS) {
		locked = TRUE;
		dbg_clear("radio_send", " sending packet at time %s \n", sim_time_string());
	  }
	  
	}
	else {
	  return FALSE;
	}
  }
  
  
  event void Boot.booted() {
    
    dbg("boot","Application booted.\n");
    routing_table_initialize();
    call AMControl.start();
    
    if (TOS_NODE_ID == 1){
      call Timer1.startOneShot(5000);
      dbg("timer","application have booted and timer1 called.\n");
    }
  }

  event void AMControl.startDone(error_t err) {
	if (err == SUCCESS) {
      //dbg("radio","Radio on on node %d!\n", TOS_NODE_ID);
    }
    else {
      dbgerror("radio", "Radio failed to start, retrying...\n");
      call AMControl.start();
    }
  }

  event void AMControl.stopDone(error_t err) {
    dbg("boot", "Radio stopped!\n");
  }
  

  
  event void Timer1.fired() {
  	uint8_t rt_currentIndex=0;  	
	rt_currentIndex = Dest_searching(7);
	// in first run the returned value by Dest_searching is zero then we need to send a route req message.
	if (rt_currentIndex == 0){
	// send route req message
		Route_Req_Msg(7);
	}
	else {
	// sending Data message
	 Data_Message_Send(7, 5); 
	}
  }
  
event message_t* Receive.receive(message_t* bufPtr, void* payload, uint8_t len) {
	uint8_t rt_currentIndex=0;
	uint16_t k=0;
	if (len != sizeof(radio_route_msg_t)) {return bufPtr;}
    else {
   	  uint8_t LED_index = student_id[msgs_number%8]%3;
   	  radio_route_msg_t* rcm = (radio_route_msg_t*)payload;
   	  
   	  switch(LED_index){
   	  	case 0:
   	  		call Leds.led0Toggle();
   	  		break;
   	  	case 1:
   	  		call Leds.led1Toggle();
   	  		break;
   	  	case 2:
   	  		call Leds.led2Toggle();
   	  		break;
   	  }
      msgs_number ++;
      
      
      
      //dbg("radio_rec", "node  %u  received a message of type %u at time %s and LEDs status is like this:\n", TOS_NODE_ID, rcm->type , sim_time_string());
      //dbg("led_0", "Led 0 status %u\n",  (call Leds.get() & LEDS_LED0) >0);
      //dbg("led_1", "Led 1 status %u\n",  (call Leds.get() & LEDS_LED1) >0);
      //dbg("led_2", "Led 2 status %u\n",  (call Leds.get() & LEDS_LED2) >0);
      
      if(TOS_NODE_ID == 6){
      	dbg("node6_leds", " message of type %u received by node 6. save the LEDs status\n", rcm->type);
      	Node6_LED_status[(msgs_number)*3+0] = (call Leds.get() & LEDS_LED0) >0;
      	Node6_LED_status[(msgs_number)*3+1] = (call Leds.get() & LEDS_LED1) >0;
      	Node6_LED_status[(msgs_number)*3+2] = (call Leds.get() & LEDS_LED2) >0;
      }
      
      while ( TOS_NODE_ID == 6 && k<=((msgs_number)*3)+2){
      if(k == 0)
      dbg_clear("node6_leds", "Node 6 LEDs status:\n");
      
      	dbg_clear("node6_leds", "%u",  Node6_LED_status[k]);
      	k++;
      }
      dbg_clear("node6_leds", "\n\n");
      
      switch(rcm->type){
      case 0:
      
      
      	// if we are in destination then do nothing just print that Data message received by the destination.
      	if (rcm->destination == TOS_NODE_ID){
      	  	dbg("radio_pack", "Data message received by the destination node: %u with the value of: %u\n", rcm->destination, rcm->value);
      		}
      	// otherwise call data message send function till reaching to the desired destination 
      	else {
      	  Data_Message_Send(rcm->destination, rcm->value);
      		}
      	break;
      	case 1:
      // if we are in required destination then send a route reply message
      	
      	rt_currentIndex = Dest_searching(rcm->destination);
      // check if requested node is not in my routing table and not me
      if (rcm->destination != TOS_NODE_ID && rt_currentIndex ==0){
      	Route_Req_Msg(rcm->destination);
      }
      // if I'm the requested node
      else if (rcm->destination == TOS_NODE_ID) {
      // second argument of the Route_Rep_Msg is cost
      	  Route_Rep_Msg(rcm->destination, 1);
      	}
      // if requested node is in my table. 
      	else if (rt_currentIndex !=0){
      		// update the cost with cost of routing table +1 and send the reply message.
		  	Route_Rep_Msg(rcm->destination, routing_table[rt_currentIndex-1].cost+1);
      	}
      	break;
      	
      	case 2:
			rt_currentIndex = Dest_searching(rcm->destination);
			// check if routing table doesn't have any entry send update the routing table and send route reply message
			if (rt_currentIndex == 0) {
			
		  	routing_table[rt_elements].destination = rcm->destination;
		  	routing_table[rt_elements].Next_Hop = rcm->sender;
		  	routing_table[rt_elements].cost = rcm->value;
		  	rt_elements ++;
		  	if (TOS_NODE_ID != 1)
		    	Route_Rep_Msg(rcm->destination, rcm->value + 1);
			}
			// check the cost of new received message and if is less than previous one then update the table for that node.
			else if (routing_table[rt_currentIndex-1].cost > rcm->value){
		  	routing_table[rt_currentIndex-1].destination = rcm->destination;
		  	routing_table[rt_currentIndex-1].cost = rcm->value + 1;
		  	routing_table[rt_currentIndex-1].Next_Hop = rcm->sender;
		  	if (TOS_NODE_ID != 1)
		    	Route_Rep_Msg(rcm->destination, rcm->value + 1);
				}
			// if i'm the requested node in reply
      		if (TOS_NODE_ID == 1) {
      	  	  Data_Message_Send(7, 5);
      			}
      	break;
      	//end of switch case
      	}
      
      return bufPtr;
    }
  }
  
  
  
  event void AMSend.sendDone(message_t* bufPtr, error_t error) {
  	
	if (&queued_packet == bufPtr) {
      locked = FALSE;
      dbg("radio_send", "Packet sent at time %s \n", sim_time_string());
    }
  }
}




