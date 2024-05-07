.PHONY: run
run:
	hugo server

.PHONY: update
update:
	cd themes/PaperMod/ && git pull
