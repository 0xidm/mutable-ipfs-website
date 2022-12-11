include settings.mk

help:
	@echo The following makefile targets are available:
	@echo
	@grep -e '^\w\S\+\:' Makefile | sed 's/://g' | cut -d ' ' -f 1
		
all: clean build publish
	@echo OK

clean:
	rm -rf _site _build

build:
	./bin/build-pandoc.sh default

build-dark:
	./bin/build-pandoc.sh water

build-style:
	./bin/build-pandoc.sh $(STYLE)

publish:
	IPFS_API=$(IPFS_API) ./bin/add-ipfs.sh -k website-1 -f _site/index.html

key:
	ipfs --api=$(IPFS_API) key gen website-1

open:
	open _site/index.html
