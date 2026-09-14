.PHONY: build full stage sync test

build full:
	./scripts/build.sh

stage:
	./scripts/stage-tree.sh

sync:
	./scripts/sync.sh

test:
	bash tests/test-apply-patches.sh
	bash tests/test-compatibility.sh
	bash tests/test-kernel-root-cmdline.sh
	bash tests/test-amonet2-bcb-slotselect.sh
	python3 tests/test-ota-slot-paths.py
	bash tests/test-led-countdown.sh
