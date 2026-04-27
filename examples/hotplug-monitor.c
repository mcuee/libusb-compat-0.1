/*
 * hotplug-monitor.c -- exercise libusb-compat-0.1 hot-plug paths.
 *
 * Polls usb_find_busses() and usb_find_devices() in a loop and prints the
 * current bus/device tree whenever either reports a change. Useful for
 * exercising the bus-removal path in usb_find_busses() and for verifying
 * that a clean Ctrl-C exit produces no "device X.Y still referenced"
 * warnings from the underlying libusb (issue #25).
 *
 * See examples/README for how to trigger bus add/remove on Linux.
 *
 * This file is in the public domain.
 */

#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <usb.h>

static volatile sig_atomic_t running = 1;

static void on_signal(int signo)
{
	(void) signo;
	running = 0;
}

static void print_state(void)
{
	struct usb_bus *bus;
	for (bus = usb_get_busses(); bus; bus = bus->next) {
		struct usb_device *dev;
		printf("  bus %s\n", bus->dirname);
		for (dev = bus->devices; dev; dev = dev->next)
			printf("    dev %s  %04x:%04x\n",
				dev->filename,
				dev->descriptor.idVendor,
				dev->descriptor.idProduct);
	}
}

int main(int argc, char *argv[])
{
	unsigned int interval_ms = 500;
	int iter = 0;

	if (argc > 1) {
		int v = atoi(argv[1]);
		if (v > 0)
			interval_ms = (unsigned int) v;
	}

	signal(SIGINT, on_signal);
	signal(SIGTERM, on_signal);

	usb_init();

	while (running) {
		int bus_changes = usb_find_busses();
		int dev_changes = usb_find_devices();

		if (iter == 0 || bus_changes || dev_changes) {
			printf("[iter %d] bus_changes=%d dev_changes=%d\n",
				iter, bus_changes, dev_changes);
			print_state();
			fflush(stdout);
		}

		iter++;
		usleep(interval_ms * 1000u);
	}

	printf("exiting\n");
	return 0;
}
