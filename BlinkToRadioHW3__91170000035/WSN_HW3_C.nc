#include <Timer.h>
#include "Wsn_hw3.h"

module WSN_HW3_C {

	uses{
		interface Boot;
		interface Leds;
		interface Timer<TMilli> as Timer0;
		interface Timer<TMilli> as Timer1;
		interface Packet;
		interface AMPacket;
		interface AMSend;
		interface Receive;
		interface SplitControl as AMControl;
		interface PacketAcknowledgements;
		interface Random;
		interface Queue<QueueEntry> as msgQueue;
	}
}

implementation {

	
	message_t pkt;
	bool busy = FALSE;
	
	uint8_t state = IDLE;
	
	uint8_t currentState;
	am_addr_t parentNode;
	am_addr_t childNodes[MAX_ARRAY_SIZE] = {};
	am_addr_t otherNodes[MAX_ARRAY_SIZE] = {};
	am_addr_t neighborNodes[MAX_ARRAY_SIZE] = {};
	

	
	uint8_t generateRandom(uint32_t upperBound){
		uint16_t rnd = call Random.rand16();		
		return (rnd % upperBound) + 1;
	}
	
	/*
	* Function to count number of element in integer array
	*/
	uint8_t sizeofArray(am_addr_t* array){
		uint8_t size = 0;
		while(array[size]){
			size++; 
		}
		
		return size;
	}
	
	char* messageTypeToString(uint8_t type){
		return (type == ACK ? "ACK" : (type == REJECT ? "REJECT" : "PROBE") );
	}
	
	void sendUnicastMessage(uint8_t messageType, am_addr_t destination){
		
		SpanningTreeMsg* btrpkt = (SpanningTreeMsg*)(call Packet.getPayload(&pkt, sizeof(SpanningTreeMsg)));
		if (btrpkt == NULL) {
			return;
		}
		btrpkt->_type = messageType;
		btrpkt->_nodeid = TOS_NODE_ID;
		
		call PacketAcknowledgements.requestAck(&pkt);
		
		
		
		if (call AMSend.send(destination, &pkt, sizeof(SpanningTreeMsg)) == SUCCESS) {
			dbg("sendUnicastMessage", "[ %s ] -- %s from Mote-(%d) --> Mote-(%d). \n", sim_time_string(), messageTypeToString(messageType), TOS_NODE_ID, destination);
		}
	}

	void sendBroadcastMessage(uint8_t type){
	
		SpanningTreeMsg* btrpkt = (SpanningTreeMsg*)(call Packet.getPayload(&pkt, sizeof(SpanningTreeMsg)));
		
		if (btrpkt == NULL) {
			return;
		}
		
		btrpkt->_type = type;
		btrpkt->_nodeid = TOS_NODE_ID;
		
		if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(SpanningTreeMsg)) == SUCCESS) {
			
			dbg("sendBroadcastMessage", "[ %s ] -- sendBroadcastMessage(): %s packet from Mote-(%d) --> All\n", sim_time_string(), messageTypeToString(type), TOS_NODE_ID);
		}else{
			dbgerror("Error", "[ %s ] -- sendBroadcastMessage(): %s packet from Mote-(%d) --> All has failed\n", sim_time_string(), messageTypeToString(type), TOS_NODE_ID);
		}
		
	}	  

	void printArray(char* arrName, am_addr_t arr[]){
		uint8_t i, size = sizeofArray(arr);
		
		printf("*** Mote-(%d) - %s: [ ", TOS_NODE_ID, arrName);
		for(i = 0; i < size; i++){
			printf("%d; ", arr[i] );
		}
		printf("] \n \n");
	}
	
	/* 
	* Function to sort an array by using insertion sort
	* Note that node ids are assumed as integer type
	*/
	void insertionSort(am_addr_t arr[]){
		int8_t i, j; 
		uint8_t size = sizeofArray(arr);
		am_addr_t key;
		
		for (i = 1; i < size; i++){
			key = arr[i];
			j = i-1;
		
			/* Move elements of arr[0..i-1], that are
				greater than key, to one position ahead
				of their current position */
			while (j >= 0 && arr[j] > key)
			{
				arr[j+1] = arr[j];
				j = j-1;
			}
			
			arr[j+1] = key;
		}
	}
	
	
	
	bool isXPLORDdone(){
		am_addr_t childsPlusOthers[20] = {};
		uint8_t i, j;
		uint8_t size;
		
		uint8_t childSize = sizeofArray(childNodes);
		uint8_t othersSize = sizeofArray(otherNodes);
		uint8_t childsPlusOthersSize;
		
		for(i = 0; i < childSize; i++){
			childsPlusOthers[i] = childNodes[i];
		}
		
		for (j = 0; j < othersSize; j++){
			childsPlusOthers[i + j] = otherNodes[j];
		}
		
		childsPlusOthers[i + j] = parentNode;
		
		insertionSort(childsPlusOthers);
		
		size = sizeofArray(neighborNodes);
		childsPlusOthersSize = sizeofArray(childsPlusOthers);
		
		dbg("isXPLORDdone", "isXPLORDdone, sizeofArray(neighborNodes)= %d, sizeofArray(childsPlusOthers) = %d. \n", size, childsPlusOthersSize );
		
		if(size == childsPlusOthersSize ){
			
			for(i = 0; i < size; i ++){
				if(neighborNodes[i] != childsPlusOthers[i]){
					dbg("isXPLORDdone", "isXPLORDdone, return FALSE 1 \n");
					return FALSE;
				}
			}
			dbg("isXPLORDdone", "isXPLORDdone, return TRUE \n");
			return TRUE;
		}
		
		dbg("isXPLORDdone", "isXPLORDdone, return FALSE 2 \n");
		return FALSE;
		
	}
	
	void createMessage(uint8_t type, am_addr_t dest){
		QueueEntry queueEntry; 
		
		queueEntry.msg._type = type;
		queueEntry.msg._nodeid = TOS_NODE_ID;
		queueEntry._toNodeid = dest;
					
		if(call msgQueue.enqueue(queueEntry) == SUCCESS){
			dbg("createMessage", "[ %s ] -- createMessage(): %s packet from Mote-(%d) --> Mote-(%d) was enqueued into queue. \n", sim_time_string(), messageTypeToString(type), TOS_NODE_ID, queueEntry._toNodeid);
			
		}else{
			dbgerror("Error", "[ %s ] -- Not able to enqueue packet. \n", sim_time_string());
		}
	}
	
	void printStep(){
		uint8_t i, childSize = sizeofArray(childNodes);
		uint8_t othersSize = sizeofArray(otherNodes);
		char childs[MAX_ARRAY_SIZE] = {};
		char others[MAX_ARRAY_SIZE] = {};
		
		for(i = 0; i < childSize; i++){
			char current[MAX_ARRAY_SIZE] = {};
			snprintf(current, sizeof(current), "%d%s", childNodes[i], (i + 1 < childSize ? ", " : ""));
			strcat(childs, current);
		}
		
		for(i = 0; i < othersSize; i++){
			char current[MAX_ARRAY_SIZE] = {};
			snprintf(current, sizeof(current), "%d%s", otherNodes[i], (i + 1 < othersSize ? ", " : ""));
			strcat(others, current);
		}
						
		if(TOS_NODE_ID == ROOT_NODE)
			dbg("printStep", "[ %s ] -- printStep(): ROOT childs: [ %s ], others: [ %s ]. \n", sim_time_string(), childs, others);
		else
			dbg("printStep", "[ %s ] -- printStep(): parent: %d, childs: [ %s ], others: [ %s ]. \n", sim_time_string(), parentNode, childs, others);
	}
	
	void printCheckTerm(){
		uint8_t i, childSize = sizeofArray(childNodes);
		char childs[MAX_ARRAY_SIZE] = {};
		
		for(i = 0; i < childSize; i++){
			char current[MAX_ARRAY_SIZE] = {};
			snprintf(current, sizeof(current), "%d%s", childNodes[i], (i + 1 < childSize ? ", " : ""));
			strcat(childs, current);
		}
						
		if(TOS_NODE_ID == ROOT_NODE)
			dbg("printCheckTerm", "[ %s ] -- checkTerm(): Real TERM!!! - childs: [ %s ]. \n", sim_time_string(), childs);
		else
			dbg("printCheckTerm", "[ %s ] -- checkTerm(): local TERM! - parent: %d, childs: [ %s ]. \n", sim_time_string(), parentNode, childs);
	}
	
	void checkTerm(){
		dbg("checkTerm", "[ %s ] -- checkTerm() \n", sim_time_string());
		
		if(isXPLORDdone()){
			currentState = TERM;
			call Timer1.stop();
			printCheckTerm();
			
			if(TOS_NODE_ID != ROOT_NODE){
				createMessage(ACK, parentNode);
			}
		}
	}
	
	bool isNodeInLists(am_addr_t nodeid){
		uint8_t i;
		
		uint8_t childSize = sizeofArray(childNodes);
		uint8_t otherSize = sizeofArray(otherNodes);
		
		for(i = 0; i < childSize; i++){
			if(childNodes[i] == nodeid){
				// If node is a child, then return TRUE
				return TRUE;
			}
		}
		
		for(i = 0; i < otherSize; i++){
			if(otherNodes[i] == nodeid){
				// If node is an other, then return TRUE
				return TRUE;
			}
		}
		
		// If received node is parent, then return TRUE
		return nodeid == parentNode;
		
	}
	
	
	
	
	/**************** Boot *********************/
	event void Boot.booted() {	
		
		uint8_t i;
		uint8_t size = sizeofArray(topology20[TOS_NODE_ID - 1]);
		
		for(i = 0; i < size; i++){
			neighborNodes[i] = topology20[TOS_NODE_ID - 1][i];
		}
		
		//printArray("neighborNodes", neighborNodes);
		
		insertionSort(neighborNodes);
		
		printArray("sorted neighborNodes", neighborNodes);
		
		/*printf("*** Mote-(%d) - neighborNodes: [ ", TOS_NODE_ID);
		for(i = 0; i < size; i++){
			printf("%d; ", neighborNodes[i] );
		}
		printf("] \n \n");
		*/
		
		dbg("booted", "[ %s ] -- Booted.\n", sim_time_string());
		
		currentState = IDLE;
		call AMControl.start();
	}

	/**************** AMControl event handlers *********************/
	event void AMControl.startDone(error_t err) {
		if (err == SUCCESS) {
			if(TOS_NODE_ID == ROOT_NODE){
				call Timer0.startOneShot( TIMER_MILLI_EXPLORE_THRESHOLD + generateRandom(RANDOM_MAX_VALUE) );
				call Timer1.startOneShot( 3*TIMER_MILLI_EXPLORE_THRESHOLD + generateRandom(RANDOM_MAX_VALUE) );
			}
		}
		else {
			call AMControl.start();
		}
	}

	event void AMControl.stopDone(error_t err) {
		dbg("stopDone", "[ %s ] -- AMControl.stopDone(). \n", sim_time_string());
	}

	/**************** Timer0.fired() event handler *********************/
	event void Timer0.fired() {
		bool isQueueEmpty;
		dbg("Timer0fired", "[ %s ] -- onTimer0Fired: Allocated queue (%d/%d) \n", sim_time_string(), call msgQueue.size(), call msgQueue.maxSize());
		
		if(currentState == IDLE){
			if(TOS_NODE_ID == ROOT_NODE){
				if(currentState == IDLE){
					dbg("Timer0fired", "[ %s ] -- IDLE, ROOT_NODE. \n", sim_time_string());
					currentState = XPLORD;
					
					createMessage(PROBE, AM_BROADCAST_ADDR);
					call Timer0.startOneShot( generateRandom(RANDOM_MAX_VALUE) );
					
				}
			}
		}else{
		
			if(!call msgQueue.empty()){
				QueueEntry entry = call msgQueue.dequeue();
				
				if(entry._toNodeid == AM_BROADCAST_ADDR){
					sendBroadcastMessage(entry.msg._type);				
				}else{
					sendUnicastMessage(entry.msg._type, entry._toNodeid);
				}
			}
			
			isQueueEmpty = call msgQueue.empty();
			
			if( (isQueueEmpty && currentState != TERM) || !isQueueEmpty ){
				call Timer0.startOneShot( (TIMER_PERIOD_MILLI_FOR_RETRY + generateRandom(RANDOM_MAX_VALUE)) );
			}
		
		}
	}
	
	event void Timer1.fired() {
		if(currentState == XPLORD){
			createMessage(PROBE, AM_BROADCAST_ADDR);
			dbg("Timer1fired", "[ %s ] -- onTimer1Fired: Allocated(%d/%d) \n", sim_time_string(), call msgQueue.size(), call msgQueue.maxSize());
			
			call Timer1.startOneShot(2*TIMER_MILLI_EXPLORE_THRESHOLD + generateRandom(RANDOM_MAX_VALUE));
		}
	}

	/**************** AMSend.sendDone() event handler *********************/
	event void AMSend.sendDone(message_t* msg, error_t err) {
		bool wasAcked;
		
		SpanningTreeMsg* releasedMsg = (SpanningTreeMsg*)(call Packet.getPayload(msg, sizeof(SpanningTreeMsg)));
		
		
		switch(releasedMsg->_type){
			case ACK: case REJECT:
				wasAcked = call PacketAcknowledgements.wasAcked(&pkt);
				if(wasAcked){
					/*
					* If packet is ACKed, then release next packet 
					*/
					
					dbg("sendDone", "[ %s ] -- AMSend.sendDone(): %s message from Mote-(%d) --> Mote-(%d) is ACKed.\n", sim_time_string(), messageTypeToString(releasedMsg->_type), TOS_NODE_ID, call AMPacket.destination(msg));
				}else{
					/*
					* In order to be able to send packet again, add the same packet to queue
					*/
					createMessage(releasedMsg->_type, call AMPacket.destination(msg));
					dbg("sendDone", "[ %s ] -- AMSend.sendDone(): Message from Mote-(%d) --> Mote-(%d) was not acked.\n", sim_time_string(), TOS_NODE_ID, call AMPacket.destination(msg) );
				}
				break;
			case PROBE:
				dbg("sendDone", "[ %s ] -- AMSend.sendDone(): PROBE done from Mote-(%d) --> All.\n", sim_time_string(), TOS_NODE_ID);
				break;
			default:
				dbgerror("Error", "[ %s ] -- AMSend.sendDone(): No match for the packet from Mote-(%d) --> Mote-(%d) \n", sim_time_string(), TOS_NODE_ID, call AMPacket.destination(msg));
		}
		
	}

	/**************** Receive.receive() event handlers *********************/
	event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
		uint8_t size;
		if (len == sizeof(SpanningTreeMsg)) {
			
			SpanningTreeMsg* rcvpkt = (SpanningTreeMsg*)payload;
			
			
			if(!isNodeInLists(rcvpkt->_nodeid)){
			switch(currentState){
				case IDLE:
				
					switch(rcvpkt->_type){
						case PROBE:
							parentNode = rcvpkt->_nodeid;
							dbg("receivePROBE", "[ %s ] -- Receive.receive(): 1. PROBE from Mote-(%d) --> Mote-(%d), parent: %d. \n", sim_time_string(), rcvpkt->_nodeid, TOS_NODE_ID, parentNode);
							
							createMessage(PROBE, AM_BROADCAST_ADDR);
							
							currentState = XPLORD;
							
							if(TOS_NODE_ID != ROOT_NODE){
								/*
								* Start queue timer for non root nodes
								*/
								call Timer0.startOneShot( TIMER_MILLI_EXPLORE_THRESHOLD + generateRandom(RANDOM_MAX_VALUE) );
								call Timer1.startOneShot( 3*TIMER_MILLI_EXPLORE_THRESHOLD + generateRandom(RANDOM_MAX_VALUE) );
							}
							break;
						default:
							dbgerror("Error", "[ %s ] -- Receive.receive(): Message type does not match for packet from Mote-(%d) while state is IDLE! \n", sim_time_string(), rcvpkt->_nodeid);
					}
					checkTerm();
					
					break;
					
				case XPLORD:
				
					switch(rcvpkt->_type){
						case PROBE:
							dbg("receivePROBE_REJECT", "[ %s ] -- Receive.receive(): PROBE from Mote-(%d) --> Mote-(%d) will be REJECTed. \n", sim_time_string(), rcvpkt->_nodeid, TOS_NODE_ID);//sendUnicastMessage(REJECT, rcvpkt->
							
							createMessage(REJECT, rcvpkt->_nodeid);
							
							break;
							
						case ACK:
							
							size = sizeofArray(childNodes);
							childNodes[size] = rcvpkt->_nodeid;
							
							dbg("receiveACK", "[ %s ] -- Receive.receive(): ACK from Mote-(%d) --> Mote-(%d), add %d into childs. \n", sim_time_string(), rcvpkt->_nodeid, TOS_NODE_ID, rcvpkt->_nodeid);
							
							if(size > 1){
								insertionSort(childNodes);
							}
							
							break;
							
						case REJECT:
						
							size = sizeofArray(otherNodes);
							otherNodes[size] = rcvpkt->_nodeid;
							
							dbg("receiveREJECT", "[ %s ] -- Receive.receive(): REJECT from Mote-(%d) --> Mote-(%d), size: %d. \n", sim_time_string(), rcvpkt->_nodeid, TOS_NODE_ID, size);
							
							if(size > 1){
								insertionSort(otherNodes);
							}
							
							break;
							
						default: 
							dbgerror("Error", "[ %s ] -- Receive.receive(): Message type does not match for packet from Mote-(%d) while state is XPLORD. \n", sim_time_string(), rcvpkt->_nodeid);
					}
					checkTerm();
					
					break;
					
				case TERM:
					
					dbg("receiveTERM", "[ %s ] -- Receive.receive(): Any packet from Mote-(%d) --> Mote-(%d) while state is TERM locally. \n", sim_time_string(), rcvpkt->_nodeid, TOS_NODE_ID);
					createMessage(REJECT, rcvpkt->_nodeid);
					
					/*
					* Although node is locally TERMed algorithm, if node receives a packet, then start queue timer again to flush queue
					*/
					call Timer0.startOneShot( TIMER_PERIOD_MILLI_FOR_RETRY + generateRandom(RANDOM_MAX_VALUE) );
					
					break;
					
				default:
					dbgerror("Error", "[ %s ] -- Receive.receive(): No match for state! \n", sim_time_string());
			}
			}else{
				dbgerror("Error", "[ %s ] -- Receive.receive(): Mote-(%d) was in one of the lists! \n", sim_time_string(), rcvpkt->_nodeid);
			}
			printStep();

		}
		return msg;
	}
}
