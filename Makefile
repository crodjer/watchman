PREFIX ?= /usr/local
PREFIX := $(PREFIX:%/=%)
EXECUTABLE ?= watchman

INSTALL_PATH := $(addprefix $(PREFIX),/bin/$(EXECUTABLE))
ROOT_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
SOURCE_SCRIPT_PATH := $(addprefix $(ROOT_DIR),/watchman.sh)

develop:
	ln -sf $(SOURCE_SCRIPT_PATH) $(INSTALL_PATH)

install:
	cp $(SOURCE_SCRIPT_PATH) $(INSTALL_PATH)

uninstall:
	rm $(INSTALL_PATH)
