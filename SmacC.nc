/*
@authors: Edwin Mascarenhas
		  Abuturab Mohammadi
Under the Esteemed guidence of Prof K.R Anupama, faculty EEE & I department
BITS Pilani, K.K Birla Goa campus
This code has been tested with 4 motes where, mote with ID 1 is booted first, and the other motes
have been added to the network at a later stage
This program should work for more motes too with some changes in the TDMA cycle. However it hasn't been tested so far.
*/

#include "Smac.h"
#include <UserButton.h>
#include "printf.h"

//different modules used
module SmacC
{
	uses 
	{
		interface Boot;
		interface Leds;
		interface Timer<TMilli> as Tsync;
		interface Timer<TMilli> as Tdata;
		interface Timer<TMilli> as Tsleep;
		interface Timer<TMilli> as Timeout;
		interface Timer<TMilli> as Tdma; 
		interface Timer<TMilli> as Delay;
		interface Timer<TMilli> as Delay2;
	}
	uses 
	{
		interface Get<button_state_t>;
		interface Notify<button_state_t>;
	}
	uses
	{
		interface Packet;
		interface AMPacket;
		interface SplitControl as AMControl;
		interface Receive;
		interface AMSend;
		interface PacketTimeStamp<TMilli,uint32_t> as Tstamp;
	}
}

//Implementation of code
implementation
{	
	//variable declarations
	uint16_t nodeHead;
	message_t pkt;
	bool radioBusy=FALSE;	
	bool head = FALSE;
	uint32_t timetodata;
	uint32_t datatime;
	uint32_t sleepperiod = 1000;
	syncpkt_t* sync_packet;
	datapkt_t* info;
	uint32_t delay = 20;
	uint32_t delay2 = 20;

	//After booting
	event void Boot.booted(){
		printf("booted \n");
		printfflush();
		//call Leds.led0Toggle();
		call AMControl.start();
		call Timeout.startPeriodic(2550);
	}

	//TDMA cycle starts
	event void Tdma.fired(){
		call Tdma.stop();
		info=call Packet.getPayload(&pkt, sizeof(datapkt_t));
		info->NodeId=TOS_NODE_ID;
		info->Data=1;
		if(call AMSend.send(nodeHead, &pkt, sizeof(datapkt_t))==SUCCESS)
			radioBusy=TRUE;
	}
	
	//after period of one entire frame is over
	event void Timeout.fired(){
		call Timeout.stop();
		head = TRUE;
		datatime = 1000;
		call Tsync.startPeriodic(500);
		printf("Starting sync period \n");
		printfflush();
		sync_packet=call Packet.getPayload(&pkt, sizeof(syncpkt_t));
		sync_packet->Node_Id = TOS_NODE_ID;
		sync_packet->DataDuration = 1000;
		sync_packet->TimeToData = 500 - (call Tsync.getNow());
		if(call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(syncpkt_t))==SUCCESS)
				{	
					radioBusy=TRUE;
				}	
	}

	//When the sync period is over
	event void Tsync.fired(){
		call Tsync.stop();
		call Tdata.startPeriodic(1000);
		printf("Data period started \n");
		printfflush();
		if(!head)
		{
			call Tdma.startPeriodic(TOS_NODE_ID * 100);
		}
	}


	//When the data period is over
	event void Tdata.fired(){
		call Tdata.stop();
		if(head){
			call Delay2.startPeriodic(delay2);
		}		
		else{
			call AMControl.stop();
			call Tsleep.startPeriodic(sleepperiod);
			printf("sleeping \n");
			printfflush();
		}	
	}

	//When sleep period is over
	event void Tsleep.fired(){
		call Tsleep.stop();
		call AMControl.start();
		printf("wokeup \n");
		printfflush();
		call Tsync.startPeriodic(500);
		printf("Starting sync period \n");
		printfflush();
	}

	event void Notify.notify(button_state_t val){
	}

	//If packet is recieved
	event message_t * Receive.receive(message_t *msg, void *payload, uint8_t len){
		if(sizeof(syncpkt_t) == len){
			if(call Timeout.isRunning()){
				call Timeout.stop();
			}
			if(!head){
				if(call Tsync.isRunning()){
					call Tsync.stop();
				}
				sync_packet = (syncpkt_t*) payload;
				timetodata = sync_packet->TimeToData;
				datatime = sync_packet->DataDuration;
				nodeHead=sync_packet->Node_Id;
				call Tsync.startPeriodic(500);
			}
		}

		if(sizeof(datapkt_t)==len && head)
		{
			info=(datapkt_t*) payload;
			switch(info->NodeId)
			{
				case 2:
					call Leds.led0Toggle();
					break;
				case 3:
					call Leds.led1Toggle();
					break;
				case 4:
					call Leds.led2Toggle();
					break;
				default:
					break;
			}
		}
		return msg;
	}

	//Other events when radio has started, stopped or finished sending
	event void AMControl.stopDone(error_t error){
		if(error != SUCCESS){
			call AMControl.stop();
		}
	}
	
	event void AMControl.startDone(error_t error){
		if(error != SUCCESS){
			call AMControl.start();
		}
		if(error == SUCCESS){

		if(head){
			call Delay.startPeriodic(delay);
		}
		}
	}

	event void AMSend.sendDone(message_t *msg, error_t error){
		radioBusy = FALSE;
	}

	event void Delay.fired(){

		call Delay.stop();
		sync_packet=call Packet.getPayload(&pkt, sizeof(syncpkt_t));
			sync_packet->Node_Id = TOS_NODE_ID;
			sync_packet->DataDuration = 1000;
			sync_packet->TimeToData = 500 - (call Tsync.getNow());
		if(call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(syncpkt_t))==SUCCESS)
				{
					radioBusy=TRUE;
				}
	}

	event void Delay2.fired(){
		call Delay2.stop();
		//delay2 += 5;
		call AMControl.stop();
		printf("sleeping \n");
		printfflush();
		call Tsleep.startPeriodic(sleepperiod);
	}
}