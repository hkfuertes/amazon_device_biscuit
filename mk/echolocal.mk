# EchoLocal host-side preparation and provisioning helpers.
ECHOLOCAL_MK_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ECHOLOCAL_PREPARE ?= $(abspath $(ECHOLOCAL_MK_DIR)/../scripts/prepare-echolocal.sh)
ECHOCTL ?= echoctl

.PHONY: echolocal-prepare echolocal-wifi

echolocal-prepare:
	@"$(ECHOLOCAL_PREPARE)"

# Interactive by default: do not put Wi-Fi credentials in make variables or logs.
echolocal-wifi:
	@"$(ECHOCTL)" wifi
