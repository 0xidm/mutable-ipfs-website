# Mutable Website on IPFS

## Installation

Rendering markdown to html requires pandoc. Try the following:

- macos: `brew install pandoc`
- ubuntu/debian: `apt install pandoc`
- redhat: `rpm install pandoc`

## Configuration

Copy `settings.example.mk` to `settings.mk` and change IPFS_API to point to your IPFS node.

## Usage

### Generate key for unique IPNS

```{bash}
export IPFS_API=/ip4/127.0.0.1/tcp/5001
ipfs --api=$IPFS_API key gen website-1
```

### Publish website

Modify `index.md`, then render/deploy using the `Makefile`

```{bash}
make all
```

Now the website is available from a stable URL based on `website-1` key.

https://ipfs.io/ipns/CID

#### How to manually render and publish

`make all` is equivalent to:

```{bash}
make build publish
```

which expands into the following:

```{bash}
./bin/build-pandoc.sh default
./bin/add-ipfs.sh -k website-1 -f _site/index.html
```

### Render dark mode

The `default` style can be replaced with a dark theme called `water` during rendering.

```{bash}
make build-dark publish
```

which expands into the following:

```{bash}
./bin/build-pandoc.sh water
./bin/add-ipfs.sh -k website-1 -f _site/index.html
```

### Publish other files and link from `index.md`

Add any file to ipfs, and publish with the key.

```{bash}
echo "Hello IPFS" > hello.txt
./bin/add-ipfs.sh -k website-1 -f hello.txt
```

This file is now available from a stable URL:

https://ipfs.io/ipns/CID/hello.txt

The file can be referenced from `index.md` using a relative path.

## Pandoc

Create a template

```{bash}
pandoc -D html > styles/template.html
```

Select a style from `./styles`, set STYLE in `Makefile`, and use `make build-style`.
