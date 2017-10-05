DEV_ROCKS=busted luacov luacov-coveralls luacheck ldoc
BUSTED_ARGS ?= -v -o gtest
CASSANDRA ?= 3.10
PROD_ROCKFILE = $(shell ls lua-cassandra-*.rockspec | grep -v dev)
DEV_ROCKFILE = $(shell ls lua-cassandra-*.rockspec | grep dev)
FLAGS ?=

.PHONY: install dev busted prove test clean coverage lint doc

install:
	@luarocks make $(PROD_ROCKFILE)

install-dev:
	@luarocks $(FLAGS) make $(DEV_ROCKFILE) OPENSSL_DIR=$(OPENSSL_DIR)

dev:
	@for rock in $(DEV_ROCKS) ; do \
		if ! luarocks list | grep $$rock > /dev/null ; then \
			echo $$rock not found, installing via luarocks... ; \
			luarocks install $(FLAGS) $$rock ; \
		else \
			echo $$rock already installed, skipping ; \
		fi \
	done;

busted: install-dev
	@busted $(BUSTED_ARGS)

prove:
	@util/prove_ccm.sh $(CASSANDRA)
	@t/reindex t/*
	@prove

test: busted prove

clean:
	@rm -f luacov.*
	@util/clean_ccm.sh

coverage: clean install-dev
	@busted $(BUSTED_ARGS) --coverage
	@util/prove_ccm.sh $(CASSANDRA)
	@TEST_COVERAGE_ENABLED=true TEST_NGINX_TIMEOUT=30 prove
	@luacov

lint:
	@luacheck -q . \
		--std 'ngx_lua+busted' \
		--exclude-files 'docs/examples/*.lua'  \
		--no-redefined --no-unused-args

doc:
	@ldoc -c docs/config.ld lib
