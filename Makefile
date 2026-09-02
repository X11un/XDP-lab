.PHONY: lab-up lab-down lab-reset lab-status lab-test

lab-up:
	sudo ./lab/setup.sh

lab-down:
	sudo ./lab/cleanup.sh

lab-reset:
	sudo ./lab/cleanup.sh
	sudo ./lab/setup.sh

lab-status:
	sudo ./lab/status.sh


lab-test:
	sudo ip netns exec client ping -c 1 10.200.0.1
	sudo ip netns exec client ping -c 1 10.201.0.2
	sudo ip netns exec client ping -c 1 10.202.0.2
