.PHONY: full minimal

full:
	LUNCH_TARGET=cm_biscuit-userdebug CLEAN_BISCUIT_OUT=1 ./scripts/build.sh

minimal:
	LUNCH_TARGET=biscuit_minimal-userdebug CLEAN_BISCUIT_OUT=1 ./scripts/build.sh
