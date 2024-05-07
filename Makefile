.PHONY: run
run:
	hugo server

.PHONY: update
update:
	git submodule update --init --recursive
