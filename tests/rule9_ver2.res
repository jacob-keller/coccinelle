static int usb_storage_proc_info (struct Scsi_Host *hostptr, char *buffer, char **start, off_t offset,
		int length, int inout)
{
	struct us_data *us;
	char *pos = buffer;
	unsigned long f;

	/* if someone is sending us data, just throw it away */
	if (inout)
		return length;

	us = (struct us_data*)hostptr->hostdata[0];

	/* if we couldn't find it, we return an error */
	if (!us) {
		return -ESRCH;
	}

	/* print the controller name */
	SPRINTF("   Host scsi%d: usb-storage\n", hostno);

	/* print product, vendor, and serial number strings */
	SPRINTF("       Vendor: %s\n", us->vendor);
	SPRINTF("      Product: %s\n", us->product);
	SPRINTF("Serial Number: %s\n", us->serial);

	/* show the protocol and transport */
	SPRINTF("     Protocol: %s\n", us->protocol_name);
	SPRINTF("    Transport: %s\n", us->transport_name);

	/* show the device flags */
	if (pos < buffer + length) {
		pos += sprintf(pos, "       Quirks:");
		f = us->flags;

#define DO_FLAG(a)  	if (f & US_FL_##a)  pos += sprintf(pos, " " #a)
		DO_FLAG(SINGLE_LUN);
		DO_FLAG(MODE_XLATE);
		DO_FLAG(START_STOP);
		DO_FLAG(IGNORE_SER);
		DO_FLAG(SCM_MULT_TARG);
		DO_FLAG(FIX_INQUIRY);
		DO_FLAG(FIX_CAPACITY);
#undef DO_FLAG

		*(pos++) = '\n';
		}


	/*
	 * Calculate start of next buffer, and return value.
	 */
	*start = buffer + offset;

	if ((pos - buffer) < offset)
		return (0);
	else if ((pos - buffer - offset) < length)
		return (pos - buffer - offset);
	else
		return (length);
}




/*
 * this defines our host template, with which we'll allocate hosts
 */

struct SHT usb_stor_host_template = {
	/* basic userland interface stuff */
	.name =				"usb-storage",
	.proc_name =			"usb-storage",
	.proc_info =			usb_storage_proc_info,
	.proc_dir =			NULL,
	.info =				usb_storage_info,
	.ioctl =			NULL,

	/* old-style detect and release */
	.detect =			NULL,
	.release =			NULL,

	/* command interface -- queued only */
	.command =			NULL,
	.queuecommand =			usb_storage_queuecommand,

	/* error and abort handlers */
	.eh_abort_handler =		usb_storage_command_abort,
	.eh_device_reset_handler =	usb_storage_device_reset,
	.eh_bus_reset_handler =		usb_storage_bus_reset,
	.eh_host_reset_handler =	NULL,
	.eh_strategy_handler =		NULL,

	/* queue commands only, only one command per LUN */
	.can_queue =			1,
	.cmd_per_lun =			1,

	/* unknown initiator id */
	.this_id =			-1,

	/* no limit on commands */
	.max_sectors =			0,
	
	/* pre- and post- device scan functions */
	.slave_alloc =			NULL,
	.slave_configure =		NULL,
	.slave_destroy =		NULL,

	/* lots of sg segments can be handled */
	.sg_tablesize =			SG_ALL,

	/* use 32-bit address space for DMA */
	.unchecked_isa_dma =		FALSE,
	.highmem_io =			FALSE,

	/* merge commands... this seems to help performance, but
	 * periodically someone should test to see which setting is more
	 * optimal.
	 */
	.use_clustering =		TRUE,

	/* emulated HBA */
	.emulated =			TRUE,

	/* sorry, no BIOS to help us */
	.bios_param =			NULL,

	/* module management */
	.module =			THIS_MODULE
};

