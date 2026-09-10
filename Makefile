.PHONY: full minimal

WEBVIEW_PREBUILT ?= yes

full:
	WEBVIEW_PREBUILT=$(WEBVIEW_PREBUILT) LUNCH_TARGET=cm_biscuit-userdebug CLEAN_BISCUIT_OUT=1 ./scripts/build.sh

minimal:
	WEBVIEW_PREBUILT=no LUNCH_TARGET=biscuit_minimal-userdebug CLEAN_BISCUIT_OUT=1 ./scripts/build.sh
