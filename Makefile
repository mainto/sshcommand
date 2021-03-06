.PHONY: ci-dependencies shellcheck bats install lint unit-tests test build-test-container test-in-docker
SYSTEM := $(shell sh -c 'uname -s 2>/dev/null')

ci-dependencies: shellcheck bats

shellcheck:
ifneq ($(shell shellcheck --version > /dev/null 2>&1 ; echo $$?),0)
ifeq ($(SYSTEM),Darwin)
	brew install shellcheck
else
	sudo add-apt-repository 'deb http://archive.ubuntu.com/ubuntu trusty-backports main restricted universe multiverse'
	sudo apt-get update && sudo -E apt-get install -y -qq shellcheck
endif
endif

bats:
ifneq ($(shell bats --version > /dev/null 2>&1 ; echo $$?),0)
ifeq ($(SYSTEM),Darwin)
	brew install bats
else
	sudo mkdir -p /usr/local
	git clone https://github.com/sstephenson/bats.git /tmp/bats
	cd /tmp/bats && sudo ./install.sh /usr/local
	rm -rf /tmp/bats
endif
endif

install:
	@echo setting up...
	cp ./sshcommand /usr/local/bin
	chmod +x /usr/local/bin

lint:
	@echo linting...
	@$(QUIET) find . -not -path '*/\.*' | xargs file | egrep "shell|bash" | awk '{ print $$1 }' | sed 's/://g' | xargs shellcheck

unit-tests:
	@echo running unit tests...
	@$(QUIET) bats tests/unit

test: lint unit-tests

build-test-container:
	@echo building test container...
	docker build -t sshcommand_test -f Dockerfile.test .

test-in-docker:
ifneq ($(shell docker inspect sshcommand_test > /dev/null 2>&1 ; echo $$?),0)
	$(MAKE) build-test-container
endif
	docker run -ti --rm -v ${PWD}:/app -w /app --hostname='box223' sshcommand_test make ci-dependencies install test
