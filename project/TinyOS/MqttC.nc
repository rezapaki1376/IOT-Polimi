#include "Timer.h"
#include "Mqtt.h"
#include "printf.h"


module MqttC @safe() {
  uses {
  
    /****** INTERFACES *****/
	interface Boot;

    //interfaces for communication
    interface Receive;
    interface AMSend;
    interface SplitControl as AMControl;
    interface Packet;
    
	//interface for timers
	interface Timer<TMilli> as Timer0;
	interface Timer<TMilli> as TimerConn;
	interface Timer<TMilli> as TimerNextSub;
  	interface Timer<TMilli> as TimerSub;
  	interface Timer<TMilli> as TimerNextPub;
	
    //interface for random number generation
    interface Random;
  }
}
implementation {

  message_t packet;
  message_t queued_packet;
  uint16_t queue_addr;
  uint16_t time_delays[9]={61,173,267,371,479,583,689,800,913};
  
  // flag for controlling connection of the node with broker
  bool connection_status = FALSE;
  // flag for controlling subscription to the topic
  bool current_sub_status = FALSE;
  // interested topics index. this is for underestanding how many topics a node is interested  
  uint8_t subscribed_topic_index = 0;
  
  uint16_t connection_status_devices[10];
  // connection_status device index
  uint8_t cd_index = 0;
  
  // topic definition
  const uint8_t TEMPRATURE = 1;
  const uint8_t HUMIDITY = 2;
  const uint8_t LUMINOSITY = 3;
  const char* topic_name[3] = {"temprature", "humidity", "luminosity"};
  // the topic that 
  uint8_t publish_topic = 0;
  int sent_index[3] = {-1, -1, -1};
  // value of queued message 
  uint16_t message_queue[3] = {0, 0, 0};
  // this is for saving the early comming messages before subscription
  uint8_t message_list[3] = {0, 0, 0};
 
  bool locked;
  
  
  
  uint8_t subscribed_topic[3] = {0, 0, 0};
  // subscription matrix. each node can subscribe to 3 topics. and each topic can be published by other 8 nodes.
  bool subscription_matrix[3][8] = {
  	{FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE},
  	{FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE},
  	{FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE}
  };
  
  // function decleration
  void send_connect_msg();
  void send_connect_msg_ack(uint16_t dest);
  void sub_msg_send(uint8_t topic);
  void send_connect_msg_ack(uint16_t dest);
  void send_pub_msg();
  void publish();
  bool actual_send (uint16_t address, message_t* packet);
  // performing a send message based on created packet. 
   
  bool generate_send (uint16_t address, message_t* packet){
  	if (call Timer0.isRunning()){
  		return FALSE;
  	}
  	else{
  	  call Timer0.startOneShot( time_delays[TOS_NODE_ID-1] );
  	  queued_packet = *packet;
      queue_addr = address;
  	}
  	return TRUE;
  }
  bool actual_send (uint16_t address, message_t* packet){
	if (locked) {
	  return FALSE;
	}
	else {
	  if (call AMSend.send(address, packet, sizeof(mqtt_packet_t)) == SUCCESS) {
		//dbg("radio_send", "Sending packet");
		locked = TRUE;
		//dbg_clear("radio_send", " at time %s \n", sim_time_string());
		return TRUE;
	  }
	  return FALSE;
	}
  }
  
  
  // initialize which nods that subscribed to which topicts. this was done manually randomly. 
  event void Boot.booted() {
    dbg("boot","Application booted.\n");
    
    call AMControl.start();
    
    if (TOS_NODE_ID == 2) {
      subscribed_topic[1] = HUMIDITY;
      
      publish_topic = TEMPRATURE;
    }
    
    if (TOS_NODE_ID == 3) {
      subscribed_topic[0] = TEMPRATURE;
      
    }
    
    if (TOS_NODE_ID == 4) {
      subscribed_topic[0] = TEMPRATURE;
      subscribed_topic[1] = HUMIDITY;
      
      publish_topic = LUMINOSITY;
    }
    
    if (TOS_NODE_ID == 5) {
      subscribed_topic[0] = HUMIDITY;
      subscribed_topic[1] = LUMINOSITY;
    }
    
    if (TOS_NODE_ID == 6) {
      publish_topic = HUMIDITY;
    }
    
    if (TOS_NODE_ID == 7) {
      subscribed_topic[0] = LUMINOSITY;
      subscribed_topic[0] = TEMPRATURE;
      
      publish_topic = HUMIDITY;
    }
    
    if (TOS_NODE_ID == 8) {
      subscribed_topic[0] = LUMINOSITY;
      subscribed_topic[1] = HUMIDITY;
    }
    
    if (TOS_NODE_ID == 9) {
      subscribed_topic[0] = TEMPRATURE;
      
      publish_topic = HUMIDITY;
    }
    // all nodes should be connection_status to the broker
    if (TOS_NODE_ID != 1) {
      send_connect_msg();
    }
  }
  
  
   event void Timer0.fired() {
  	actual_send (queue_addr, &queued_packet);
  }
  
  // performing TimerConn for connect messages sending
  event void TimerConn.fired() {
  // if node connection_status correctly to the broker should receive ConnAck msg. and if connection_status flag is not True then sth wrong happened and connection wasn't successfull.
  	if (!connection_status) {
  	  dbgerror("connection", "ACK of connect message not recieved in node %d.\n", TOS_NODE_ID);
  	  send_connect_msg();
  	}
  }
  // time for subscription
  event void TimerSub.fired() {
  	// if subscription ACK not received send subscription message again.
  	if (!current_sub_status) {
  	  dbgerror("subscription", "ACK of sub message for topic %s(%u) was not recieved in node %d.\n", topic_name[subscribed_topic[subscribed_topic_index]-1], subscribed_topic[subscribed_topic_index], TOS_NODE_ID);
  	  // send subscribing message
  	  sub_msg_send(subscribed_topic[subscribed_topic_index]);
  	}
  }
  
  // timer for subscription
  event void TimerNextSub.fired() {
  	bool finished = FALSE;
    if (subscribed_topic_index < 3){
  	  if (subscribed_topic[subscribed_topic_index] != 0) {
  	  	dbg("subscription", "going to next subscription in node %d.\n", TOS_NODE_ID);
  	    current_sub_status = FALSE;
  	    sub_msg_send(subscribed_topic[subscribed_topic_index]);
  	  }
  	  // if there is no topic to subscribe then finish the procedure
  	  else { finished = TRUE; }
  	}
  	else { finished = TRUE; }
  	// if all subscriptions finished and there is at least one publish topic then perform a pub message. 
  	if (finished == TRUE && publish_topic != 0) {
  	  call TimerNextPub.startOneShot( 5000 );
  	  
  	  /**if (finished && publish_topic != 0) {
  	  call TimerNextPub.startOneShot( 5000 );
  	}**/
  	
  	}
  }
  
  // timer for publish messages
   event void TimerNextPub.fired() {
  	send_pub_msg();
  }
  
  
  //////////////////////////////////////////////////////////////// start connection functions ///////////////////////////////////////////////////////////
  // function for sending connect message
  void send_connect_msg(){
  	mqtt_packet_t* connect_msg = (mqtt_packet_t*)call Packet.getPayload(&packet, sizeof(mqtt_packet_t));
  	if (connect_msg == NULL) {
	  return;
	}
	// connection request message is with type equal to 0
	connect_msg->type = CONN;
	// message sender is current node
	connect_msg->sender = (uint16_t) TOS_NODE_ID;
	// in connection message we have not any topic and value field.
	connect_msg->topic = 0;
	connect_msg->value = 0;
	call TimerConn.startOneShot( 5000 );
	dbg("connection", "Conn message sent to the broker.\n");
	generate_send(1, &packet);
  }
  
  // ACK message for connection
  void send_connect_msg_ack(uint16_t dest){
  	mqtt_packet_t* conn_ack = (mqtt_packet_t*)call Packet.getPayload(&packet, sizeof(mqtt_packet_t));
  	if (conn_ack == NULL) {
	  return;
	}
	// setting type of message to 1
	conn_ack->type = CONNACK;
	conn_ack->sender = (uint16_t) TOS_NODE_ID;
	// ACK message hasn't topic or value.
	conn_ack->topic = 0;
	conn_ack->value = 0;
	dbg("connection", "ConnAck message sent to the node %u.\n", dest);
	generate_send(dest, &packet);
  }
  /////////////////////////////////////////////////////////////// end of connection functions   ///////////////////////////////////////////////////
  
  
  
//////////////////////////////////////////////////////////////// start of the subscription functionss /////////////////////////////////////////////
  
  void sub_msg_send(uint8_t topic){
  	mqtt_packet_t* sub_msg = (mqtt_packet_t*)call Packet.getPayload(&packet, sizeof(mqtt_packet_t));
  	if (sub_msg == NULL) {
	  return;
	}
	// sub message type is 2
	sub_msg->type = SUB;
	// sender of sub message is node itself
	sub_msg->sender = (uint16_t) TOS_NODE_ID;
	// the topic that node wants to subscribe
	sub_msg->topic = topic;
	// no value for such a message
	sub_msg->value = 0;
	call TimerSub.startOneShot( 5000 );
	dbg("subscription", "Subsription message with topic of %s(%u) sent to the broker.\n", topic_name[topic-1], topic);
	generate_send(1, &packet);
  }
  
  void sub_msg_ack(uint16_t dest, uint8_t topic){
  	mqtt_packet_t* suback_msg = (mqtt_packet_t*)call Packet.getPayload(&packet, sizeof(mqtt_packet_t));
  	if (suback_msg == NULL) {
	  return;
	}
	suback_msg->type = SUBACK;
	suback_msg->sender = (uint16_t) TOS_NODE_ID;
	suback_msg->topic = topic;
	suback_msg->value = 0;
	dbg("subscription", "SubAck message for topic %s(%u) sent to the node %u.\n", topic_name[topic-1], topic, dest);
	generate_send(dest, &packet);
  }
//////////////////////////////////////////////////////////////// end of the subscription functionss /////////////////////////////////////////////


//////////////////////////////////////////////////////////////// start of the publish functionss ////////////////////////////////////////////////
  void send_pub_msg(){
  	mqtt_packet_t* pub_msg = (mqtt_packet_t*)call Packet.getPayload(&packet, sizeof(mqtt_packet_t));
  	if (pub_msg == NULL) {
	  return;
	}
	pub_msg->type = PUB;
	pub_msg->sender = (uint16_t) TOS_NODE_ID;
	pub_msg->topic = publish_topic;
	// generate random number as the payload of the pub message 
	pub_msg->value = call Random.rand16() % 100;
	
	call TimerNextPub.startOneShot(5000);
	
	dbg("publish", " Publish message with value of %u and topic %s(%u) sent to the broker.\n", pub_msg->value, topic_name[publish_topic-1], publish_topic);
	generate_send(1, &packet);
  }
  
  
  void publish(){
  	uint8_t topic = message_list[0];
  	int i;
  	uint16_t destination = 0;
  	bool finished = TRUE;
  	mqtt_packet_t* pub_msg = (mqtt_packet_t*)call Packet.getPayload(&packet, sizeof(mqtt_packet_t));
  	if (pub_msg == NULL) {
	  return;
	}
	
	if (message_list[0] == 0 && message_list[1] == 0 && message_list[2] == 0) return;
	if (sent_index[0] < 0 && sent_index[1] < 0 && sent_index[2] < 0) return;
	// after sending first queued message update the que 
	if (topic == 0 || sent_index[topic-1] < 0) {
	  message_list[0] = message_list[1];
	  message_list[1] = message_list[2];
	  message_list[2] = 0;
	  return publish();
	}
	
	for(i=sent_index[topic-1]; i<8; i++) {
	// if a node subscribed to the topic found break the loop and set the destination 
	  if (subscription_matrix[topic-1][i]) {
	  	destination = i+2;
	  	sent_index[topic-1] = i+1;
	  	finished = FALSE;
	  	break;
	  }
	}
	
	if (finished) {
	  sent_index[topic-1] = -1;
	  message_list[0] = message_list[1];
	  message_list[1] = message_list[2];
	  message_list[2] = 0;
	  return publish();
	}
	
	else {
	  
	  pub_msg->type = PUB;
	  
	  pub_msg->sender = (uint16_t) TOS_NODE_ID;
	  // topic of the publish packet is the first message_list topic
	  pub_msg->topic = topic;
	  // value is the queued message that was stored before
	  pub_msg->value = message_queue[topic-1];

	  dbg("publish", " Publish message sent to the node %u.\n", destination);
	  generate_send(destination, &packet);
	}
  }
  
//////////////////////////////////////////////////////////////////publish block finished here //////////////////////////////////////////////////////////////

  
  event void AMControl.startDone(error_t err) {
	if (err == SUCCESS) {
      dbg("radio","Radio on on node %d!\n", TOS_NODE_ID);
    }
    else {
      dbgerror("radio", "Radio failed to start, retrying...\n");
      call AMControl.start();
    }
  }

  event void AMControl.stopDone(error_t err) {
    dbg("boot", "Radio stopped!\n");
  }
  
  
  event message_t* Receive.receive(message_t* bufPtr, void* payload, uint8_t len) {
	if (len != sizeof(mqtt_packet_t)) {return bufPtr;}
    else {
      mqtt_packet_t* msg = (mqtt_packet_t*)payload;
      
      if (msg->type == CONN && TOS_NODE_ID == 1) {
      	uint8_t i;
      	bool already_connection_status = FALSE;
      	dbg("connection", "Connect msg received from Node %u.\n", msg->sender);
      	// checking the connection. this loop checks weather the node already connection_status or not. if now then outside of the loop this connection will be stablished. 
      	for (i=0; i<cd_index; i++){
      	  if (connection_status_devices[cd_index] == msg->sender) {
      	  	already_connection_status = TRUE;
      	  	break;
      	  }
      	}
      	
      	if (!already_connection_status) {
      	  
      	  connection_status_devices[cd_index] = msg->sender;
      	  cd_index ++;
      	}
      	// after stablishing the connection, ACK message should be sent
      	send_connect_msg_ack(msg->sender);
      }
      // check for connect ACK message that if received stop the timer 
      else if (msg->type == CONNACK && TOS_NODE_ID != 1 && (call TimerConn.isRunning())) {
      	call TimerConn.stop();
      	dbg("connection", "ConnAck message in node %d received in time.\n", TOS_NODE_ID);
        connection_status = TRUE;
        // connection stablished and ack received then subscribe to the topic
        call TimerNextSub.startOneShot( 5000 );
      }
      
      else if (msg->type == SUB && TOS_NODE_ID == 1) {
      	uint8_t i;
      	bool node_connection_status = FALSE;
      	
      	dbg("subscription", "Subsription message received from Node %u.\n", msg->sender);
      	
      	for (i=0; i<cd_index; i++){
      	  if (connection_status_devices[i] == msg->sender) {
      	  	node_connection_status = TRUE;
      	  	break;
      	  }
      	}
      	// after checking the connection of the node to the topic send ACK message. 
      	if(node_connection_status) {
      	  if (!subscription_matrix[msg->topic-1][msg->sender-2]) {
      	  	dbg("subscription", "Node %u subscribed to topic %s(%u).\n\n", msg->sender, topic_name[msg->topic-1], msg->topic);
      	  	subscription_matrix[msg->topic-1][msg->sender-2] = TRUE;
      	  }
      	  sub_msg_ack(msg->sender, msg->topic);
      	}
      }
      // after receiving suback message stop the timer. 
      else if (msg->type == SUBACK && TOS_NODE_ID != 1 && (call TimerSub.isRunning())) {
      	if (subscribed_topic[subscribed_topic_index] == msg->topic){
      	  call TimerSub.stop();
      	  dbg("connection", "SubAck for topic %s(%u) received in time.\n", topic_name[msg->topic-1], msg->topic);
      	  current_sub_status = TRUE;
          subscribed_topic_index ++;
          call TimerNextSub.startOneShot( 5000 );
        }
      }
      
      else if (msg->type == PUB && TOS_NODE_ID == 1) {
      	uint8_t i;
      	bool node_connection_status = FALSE;
      	
      	dbg("publish", " Publish message %u received with topic %s(%u) from Node %u.\n", msg->value, topic_name[msg->topic-1], msg->topic, msg->sender);
      	
      	for (i=0; i<cd_index; i++){
      	  if (connection_status_devices[i] == msg->sender) {
      	  	node_connection_status = TRUE;
      	  	break;
      	  }
      	}
      	
      	if(node_connection_status) {
      	  message_queue[msg->topic-1] = msg->value;
      	  sent_index[msg->topic-1] = 0;
      	  // if there are queued messages first publish them
      	  for(i=0; i<3; i++){
      	  	if(message_list[i] == msg->topic) break;
      	  	if(message_list[i] == 0){
      	  	  message_list[i] = msg->topic;
      	  	}
      	  }
      	  dbg("publish", " Message %u is queued to be published.\n", msg->value);

      	  // if we want to use these codes for tossim we should comment next lines from here 
      	  //printf("%u %u\n",msg->topic, msg->value);
      	  //printfflush();
      	  // to here. for cooja and node-red must be uncommented.
      	  publish();
      	}
      }
      
      else if (msg->type == PUB && TOS_NODE_ID != 1) {
      	dbg("publish", "  Message %u received with topic %s(%u) from the broker.\n", msg->value, topic_name[msg->topic-1], msg->topic);
      }
      
      return bufPtr;
    }
  }

  event void AMSend.sendDone(message_t* bufPtr, error_t error) {
	if (&queued_packet == bufPtr) {
      locked = FALSE;
      if (TOS_NODE_ID == 1) {
      	uint8_t i;
      	bool waiting_message = FALSE;
      	for(i=0; i<3; i++){
      	  if (sent_index[i] != -1){
      	  	waiting_message = TRUE;
      	  	break;
      	  }
      	}
      	if(waiting_message){
      	  publish();
      	}
      }
    }
  }
}




