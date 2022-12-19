include settings.mk

help:
	@echo The following makefile targets are available:
	@echo
	@grep -e '^\w\S\+\:' Makefile | sed 's/://g' | cut -d ' ' -f 1
		
all: clean build publish
	@echo OK

clean:
	@rm -rf _site _build

build:
	@echo "build start"
	@./bin/build-pandoc.sh $(STYLE)
	@echo "build finished"
	@echo

publish:
	@echo "publish start"
	@IPFS_API=$(IPFS_API) ./bin/add-ipfs.sh -k $(IPFS_KEY) -f _site/index.html -p
	@echo "publish finished"
	@echo

refresh-ipns:
	@IPFS_API=$(IPFS_API) ./bin/add-ipfs.sh -k $(IPFS_KEY) -p

key:
	@ipfs --api=$(IPFS_API) key gen $(IPFS_KEY)

open:
	@open _site/index.html

build-readme:
	@./bin/build-pandoc.sh default Readme.md
