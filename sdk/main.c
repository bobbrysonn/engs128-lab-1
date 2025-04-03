/************************************************************************/
/*																		*/
/*	main.c	--	Zybo Audio Codec Passthrough			 				*/
/*																		*/
/************************************************************************/
/*	Author: Kendall Farnham												*/
/*  ENGS 128 - Lab 1 SDK								*/
/************************************************************************/
/*  Modified from Digilent audio DMA demo (demo.c)								*/
/*  Original Author: Sam Lowe	(9/6/2016)								*/
/*	Copyright 2015, Digilent Inc.										*/
/************************************************************************/

#include <stdio.h>
#include "xil_printf.h"
#include "intc/intc.h"
#include "iic/iic.h"
#include "audio/audio.h"

// BSP/platform include files
#include "xparameters.h"
#include "xil_exception.h"
#include "xdebug.h"
#include "xiic.h"
#include "xtime_l.h"
#include "xscugic.h"
#include "sleep.h"
#include "xil_cache.h"


// Device instances
static XIic sIic;
static XScuGic sIntc;

 // Interrupt vector table
 const ivt_t ivt[] = {
 	//IIC
 	{XPAR_FABRIC_AXI_IIC_0_IIC2INTC_IRPT_INTR, (Xil_ExceptionHandler)XIic_InterruptHandler, &sIic}
 };



int main()
{
	int Status;

	//Initialize the interrupt controller
	Status = fnInitInterruptController(&sIntc);
	if(Status != XST_SUCCESS) {
		xil_printf("Error initializing interrupts");
		return XST_FAILURE;
	}


	// Initialize IIC controller
	Status = fnInitIic(&sIic);
	if(Status != XST_SUCCESS) {
		xil_printf("Error initializing I2C controller");
		return XST_FAILURE;
	}


	// Initialize Audio Codec I2S
	Status = fnInitAudio();
	if(Status != XST_SUCCESS) {
		xil_printf("Audio initializing ERROR");
		return XST_FAILURE;
	}

	{
		XTime  tStart, tEnd;

		XTime_GetTime(&tStart);
		do {
			XTime_GetTime(&tEnd);
		}
		while((tEnd-tStart)/(COUNTS_PER_SECOND/10) < 20);
	}
	//Initialize Audio I2S
	Status = fnInitAudio();
	if(Status != XST_SUCCESS) {
		xil_printf("Audio initializing ERROR");
		return XST_FAILURE;
	}

	fnSetLineInput();
	//fnSetHpOutput();	// NOTE: do not set HP output

	// Enable all interrupts in our interrupt vector table
	// Make sure all driver instances using interrupts are initialized first
	fnEnableInterrupts(&sIntc, &ivt[0], sizeof(ivt)/sizeof(ivt[0]));


    print("Audio codec initialized.\n\r");
    print("Successfully ran configuration sequence.");

    while(1){
    	//wait forever
    }

    return 0;
}
