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
	./bin/build-pandoc.sh $(STYLE)

publish:
	IPFS_API=$(IPFS_API) ./bin/add-ipfs.sh -k $(IPFS_KEY) -f _site/index.html

refresh-ipns:
	IPFS_API=$(IPFS_API) ./bin/add-ipfs.sh -k $(IPFS_KEY)

key:
	ipfs --api=$(IPFS_API) key gen $(IPFS_KEY)

open:
	open _site/index.html

build-readme:
	./bin/build-pandoc.sh default Readme.md
