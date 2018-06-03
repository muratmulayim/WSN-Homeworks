// $Id: BlinkToRadioC.nc,v 1.5 2007/09/13 23:10:23 scipio Exp $

/*
 * "Copyright (c) 2000-2006 The Regents of the University  of California.  
 * All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without written agreement is
 * hereby granted, provided that the above copyright notice, the following
 * two paragraphs and the author appear in all copies of this software.
 * 
 * IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY FOR
 * DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING OUT
 * OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF THE UNIVERSITY OF
 * CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 * THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE PROVIDED HEREUNDER IS
 * ON AN "AS IS" BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO OBLIGATION TO
 * PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
 *
 */

/**
 * Implementation of the BlinkToRadio application.  A counter is
 * incremented and a radio message is sent whenever a timer fires.
 * Whenever a radio message is received, the three least significant
 * bits of the counter in the message payload are displayed on the
 * LEDs.  Program two motes with this application.  As long as they
 * are both within range of each other, the LEDs on both will keep
 * changing.  If the LEDs on one (or both) of the nodes stops changing
 * and hold steady, then that node is no longer receiving any messages
 * from the other node.
 *
 * @author Prabal Dutta
 * @date   Feb 1, 2006
 */
#include <Timer.h>
#include <stdarg.h>
#include "BlinkToRadio.h"

module BlinkToRadioC {
  uses interface Boot;
  uses interface Leds;
  uses interface Timer<TMilli> as Timer0;
  uses interface Timer<TMilli> as Timer1;
  uses interface Packet;
  uses interface AMPacket;
  uses interface AMSend;
  uses interface Receive;
  uses interface SplitControl as AMControl;
  uses interface PacketAcknowledgements;
}
implementation {

	uint16_t counter = 1;
	message_t pkt;
	bool busy = FALSE;
	am_addr_t neighbor_index = 0;
	uint16_t retries = 0;
	am_addr_t neighbors[10];
	uint8_t numberOfNeighbors = 0;
	uint8_t state = STATE_DISCOVER;
  
void printLog(char* message){
	printf("[ %s ] [Mote-%d] -- %s\n", sim_time_string(), TOS_NODE_ID, message);
}


void sendUnicastMessage(nx_uint8_t type, am_addr_t nodeId){
	if( 0 < numberOfNeighbors && neighbor_index < numberOfNeighbors){
		if (!busy) {
			BlinkToRadioMsg* btrpkt = (BlinkToRadioMsg*)(call Packet.getPayload(&pkt, sizeof(BlinkToRadioMsg)));
			if (btrpkt == NULL) {
				return;
			}
			btrpkt->type = type;
			btrpkt->nodeid = TOS_NODE_ID;
			btrpkt->counter = counter;
		
			call PacketAcknowledgements.requestAck(&pkt);
		
			if (call AMSend.send(nodeId, &pkt, sizeof(BlinkToRadioMsg)) == SUCCESS) {
				dbg("BlinkToRadioC", "[ %s ] -- sendUnicastMessage packet: Mote(%d) --> Mote(%d) -- counter: (%d), retry-%d\n", sim_time_string(), btrpkt->nodeid, nodeId, btrpkt->counter, retries);
				busy = TRUE;
			}	
		}
	}
}

void sendBroadcastDiscover(){
	if (!busy) {
		BlinkToRadioMsg* btrpkt = (BlinkToRadioMsg*)(call Packet.getPayload(&pkt, sizeof(BlinkToRadioMsg)));
      if (btrpkt == NULL) {
		return;
      }
	  btrpkt->type = BROADCAST_DISCOVER;
      btrpkt->nodeid = TOS_NODE_ID;
	  btrpkt->counter = counter;
	  
		if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(BlinkToRadioMsg)) == SUCCESS) {
			//dbg("BlinkToRadioC", "[ %s ] -- sendBroadcastDiscover packet: Mote(%d) --> Everyone\n", sim_time_string(), btrpkt->nodeid);
			busy = TRUE;
		}	
    }
  }	  
	
  void setLeds(uint16_t val) {
    if (val & 0x01)
      call Leds.led0On();
    else 
      call Leds.led0Off();
    if (val & 0x02)
      call Leds.led1On();
    else
      call Leds.led1Off();
    if (val & 0x04)
      call Leds.led2On();
    else
      call Leds.led2Off();
  }

  event void Boot.booted() {
	printLog("Booted.");
    call AMControl.start();
  }

  event void AMControl.startDone(error_t err) {
	printLog("AMControl.startDone.");
    if (err == SUCCESS) {
      call Timer0.startPeriodic(TIMER_PERIOD_MILLI);
	  
	  // Aim of this timer is to send broadcast messages in order to introduce ourselves to neighbors at beginning of the process 
	  call Timer1.startOneShot(TIMER_MILLI_DISCOVER_THRESHOLD);
    }
    else {
      call AMControl.start();
    }
  }

  event void AMControl.stopDone(error_t err) {
	  printLog("AMControl.stopDone.");
  }

  event void Timer0.fired() {
	//printLog("Timer0.fired.");
	
	/* List neighbors of current mote. */
	uint8_t j;
	if(neighbor_index == 0 && numberOfNeighbors > 0){
		printf("\n ++++ Neightbors of Mote(%d) = (", TOS_NODE_ID);
		for (j = 0; j < numberOfNeighbors; j++ ) {
			printf("%d%s", neighbors[j], ((j == numberOfNeighbors - 1) ? ") \n" : ", ") );
		}
	}
	/* End of listing neighbors of current mote. */
	
	state = STATE_MESSAGE;
	sendUnicastMessage(UNICAST_MESSAGE, neighbors[neighbor_index]);
	
  }
  
  event void Timer1.fired() {
	// to be called whenever packet is not sent incase of timeout.
	//printLog("Timer1.fired.");

	if(state == STATE_DISCOVER){
		sendBroadcastDiscover();
	}else{
		sendUnicastMessage(UNICAST_MESSAGE, neighbors[neighbor_index]);
	}
  }

  event void AMSend.sendDone(message_t* msg, error_t err) {
	BlinkToRadioMsg* sentPkt;
	bool wasAcked;
	
	if(&pkt == msg){
		sentPkt = (BlinkToRadioMsg*)(call Packet.getPayload(msg, sizeof(BlinkToRadioMsg)));
		
		switch(sentPkt->type){
			case BROADCAST_DISCOVER:
				//dbg("BlinkToRadioC", "[ %s ] -- AMSend.sendDone(): discover from Mote(%d) --> Mote all\n", sim_time_string(), TOS_NODE_ID);
				// for the moment do nothing!
				break;
			/*
			case UNICAST_DISCOVER_RESPONSE:
				//This case is currently not in use since any node does not send message whose type is UNICAST_DISCOVER_RESPONSE.
				//dbg("BlinkToRadioC", "[ %s ] -- AMSend.sendDone(): discover response from Mote(%d) --> Mote(%d)\n", sim_time_string(), TOS_NODE_ID, sentPkt->nodeid);
				break;
			*/
			case UNICAST_MESSAGE:
				wasAcked = call PacketAcknowledgements.wasAcked(&pkt);
				if(wasAcked){
					/*
					* If packet is ACKed, then release next packet 
					*/
					//dbg("BlinkToRadioC", "[ %s ] -- AMSend.sendDone(): acked from Mote(%d) --> Mote(%d) -- counter: (%d).\n", sim_time_string(), TOS_NODE_ID, neighbors[neighbor_index], sentPkt->counter);
					counter++;
					neighbor_index++;
					retries = 0;
				}else{
					/*
					* If packet is not ACKed, then start timer and send current packet again.
					* Sending next packet will be blocked until current one is sent properly.
					*/
					retries++;
					dbgerror("Error", "[ %s ] -- AMSend.sendDone(): Sending %d. packet from Mote(%d) --> Mote(%d) failed for %d. retry.\n", sim_time_string(), sentPkt->counter, TOS_NODE_ID, neighbors[neighbor_index], (retries-1));
					call Timer1.startOneShot(TIMER_PERIOD_MILLI_FOR_RETRY);
				}
				break;
			default:
				dbgerror("Error", "[ %s ] -- AMSend.sendDone(): No match for the packet from Mote(%d) --> Mote(%d)", sim_time_string(), TOS_NODE_ID, neighbors[neighbor_index], sentPkt->counter);
		}		
		busy = FALSE;
	}
	
  }

  event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
	//uint8_t j;
	//printLog("Receive.receive.");
    if (len == sizeof(BlinkToRadioMsg)) {
		BlinkToRadioMsg* btrpkt = (BlinkToRadioMsg*)payload;
		switch(btrpkt->type){
			case BROADCAST_DISCOVER:
				//dbg("BlinkToRadioC", "[ %s ] -- Receive.receive        BROADCAST_DISCOVER packet: Mote(%d) --> Mote(%d)\n", sim_time_string(), btrpkt->nodeid, TOS_NODE_ID);
				//sendUnicastMessage(UNICAST_DISCOVER_RESPONSE, btrpkt->nodeid);
				neighbors[numberOfNeighbors] = btrpkt->nodeid;
				numberOfNeighbors++;
				
				break;
			/*
			case UNICAST_DISCOVER_RESPONSE:
				//This case is currently not in use.
				neighbors[numberOfNeighbors] = btrpkt->nodeid;
				numberOfNeighbors++;
				dbg("BlinkToRadioC", "[ %s ] -- Receive.receive UNICAST_DISCOVER_RESPONSE packet: Mote(%d) --> Mote(%d)\n", sim_time_string(), btrpkt->nodeid, TOS_NODE_ID);	
				
				printf("Neightbors of Mote(%d) = (", TOS_NODE_ID);
				for (j = 0; j < numberOfNeighbors; j++ ) {
					printf("%d%s", neighbors[j], ((j == numberOfNeighbors - 1) ? ") \n" : ", ") );
				}
				
				break;
			*/
			case UNICAST_MESSAGE:
				setLeds(btrpkt->counter);
				dbg("BlinkToRadioC", "[ %s ] -- Receive.receive           UNICAST_MESSAGE packet: Mote(%d) --> Mote(%d) -- counter: (%d)\n", sim_time_string(), btrpkt->nodeid, TOS_NODE_ID, btrpkt->counter);
				break;
			default: 
				dbgerror("BlinkToRadioC", "[ %s ] -- Receive.receive message is not 	matched!! packet: Mote(%d) --> Mote(%d)", sim_time_string(), btrpkt->nodeid, TOS_NODE_ID);
		}
	}
    return msg;
  }
}
