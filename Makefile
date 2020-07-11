PATH := $(HOME)/.local/bin:$(PATH)

install:
	pip3 install --upgrade -r test/requirements.txt

install-user:
	pip3 install --user --upgrade -r test/requirements.txt

lint:
	vint --version
	vint plugin
	vint autoload

.PHONY: install install-user lint
