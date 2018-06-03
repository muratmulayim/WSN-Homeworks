
#ifndef WSN_HW3_H
#define WSN_HW3_H

	#ifndef AM_BLINKTORADIO
	#define AM_BLINKTORADIO 6
	#endif
	
	#ifndef TIMER_MILLI_EXPLORE_THRESHOLD
	#define TIMER_MILLI_EXPLORE_THRESHOLD 250
	#endif
	
	#ifndef TIMER_PERIOD_MILLI_FOR_RETRY
	#define TIMER_PERIOD_MILLI_FOR_RETRY 40
	#endif
	
	#ifndef MAX_QUEUE_SIZE
	#define MAX_QUEUE_SIZE 30
	#endif
	
	#ifndef MAX_ARRAY_SIZE
	#define MAX_ARRAY_SIZE 20
	#endif
	
	#ifndef RANDOM_MAX_VALUE
	#define RANDOM_MAX_VALUE 50
	#endif
	
	#ifndef ROOT_NODE
	#define ROOT_NODE 1
	#endif
	
	/*********************************************************/
	enum messageTypes {
		HELLO = 0, // Broadcast
		PROBE = 1, // Broadcast
		ACK = 2, // Unicast
		REJECT = 3 // Unicast
	};
	
	enum STATES {
		IDLE = 0,
		XPLORD = 1,
		TERM = 2
	};
	
	typedef nx_struct SpanningTreeMsg {
		nx_uint8_t _type;
		nx_uint16_t _nodeid;
	} SpanningTreeMsg;
	
	typedef struct {
		SpanningTreeMsg msg;
		am_addr_t _toNodeid;
	} QueueEntry;
	
	am_addr_t topology5[20][20] = {
		{2, 3}, // Node 1
		{1, 3}, // Node 2
		{1, 2, 4, 5}, // Node 3
		{3, 5}, // Node 4
		{3, 4} // Node 5
	};

	am_addr_t topology9[20][20] = {
		{4, 2}, 			// Node 1
		{5, 1}, 			// Node 2
		{7, 8, 9}, 			// Node 3
		{1, 7}, 			// Node 4
		{2, 7, 6}, 			// Node 5
		{5}, 				// Node 6 
		{4, 5, 8, 3, 9}, 	// Node 7 
		{7, 3}, 			// Node 8 
		{3, 7},				// Node 9 
	};

	am_addr_t topology20[20][20] = {
		{8, 2, 19, 10}, 				// Node 1
		{17, 1, 3}, 					// Node 2
		{2, 7, 19}, 					// Node 3
		{16, 15}, 						// Node 4
		{10, 20, 16, 18}, 				// Node 5
		{12, 15, 19}, 					// Node 6 
		{3, 19, 12}, 					// Node 7 
		{1, 20, 10}, 					// Node 8 
		{15, 13, 14}, 					// Node 9 
		{1, 8, 5, 16}, 					// Node 10 
		{16, 14}, 						// Node 11
		{6, 7, 16}, 					// Node 12
		{9, 16}, 						// Node 13 
		{11, 9, 16}, 					// Node 14
		{6, 4, 9}, 						// Node 15
		{12, 19, 10, 5, 11, 14, 13, 4}, // Node 16
		{2, 20}, 						// Node 17
		{20, 5}, 						// Node 18
		{7, 3, 1, 16, 6}, 				// Node 19
		{17, 8, 5, 18}	 				// Node 20
	};
	
#endif
