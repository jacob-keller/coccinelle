static int usb_storage_proc_info (char *buffer, char **start, off_t offset,
		int length, int hostno, int inout)
{
	struct us_data *us;
	char *pos = buffer;
	struct Scsi_Host *hostptr;
	unsigned long f;

	/* if someone is sending us data, just throw it away */
	if (inout)
		return length;

	/* find our data from the given hostno */
	hostptr = scsi_host_hn_get(hostptr->host_no);
	if (!hostptr) {	 /* if we couldn't find it, we return an error */
		return -ESRCH;
	}
	us = (struct us_data*)hostptr->hostdata[0];

	/* if we couldn't find it, we return an error */
	if (!us) {
		scsi_host_put(hostptr);
		return -ESRCH;
	}

	/* print the controller name */
	SPRINTF("   Host scsi%d: usb-storage\n", hostptr->host_no);

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

	/* release the reference count on this host */
	scsi_host_put(hostptr);

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
