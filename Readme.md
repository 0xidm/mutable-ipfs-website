# Mutable Website on IPFS

Create a mutable IPFS website with a stable IPNS address.

## Quick Start

```{bash}
git clone https://github.com/0xidm/mutable-ipfs-website
cd mutable-ipfs-website
cp settings.example.mk settings.mk
# if your IPFS node is not localhost, edit settings.mk to change IPFS_API
make key build publish
```

You now have a website with a URL like https://ipfs.io/ipns/$HASH

Make some changes to `index.md`, then update the website:

```{bash}
make build publish
```

Even though the content has changed, the URL remains stable.

## Installation

Rendering markdown to html requires pandoc. Try the following to install:

- macos: `brew install pandoc`
- ubuntu/debian: `apt install pandoc`
- redhat: `rpm install pandoc`

## Configuration

Copy `settings.example.mk` to `settings.mk`.

The following variables can be changed:

- IPFS_API: the IP v4 address and TCP port of your IPFS node. Default is `/ip4/127.0.0.1/tcp/5001`
- IPFS_KEY: name of IPFS key; also used as MFS path. Default is `website-1`
- STYLE: a pandoc style used when `index.md` is rendered to `index.html`

## Usage

### Generate IPFS key for unique IPNS hash

Edit `settings.mk` to specify a key name, then generate that key:

```{bash}
make key
```

which expands into:

```{bash}
ipfs --api=/ip4/127.0.0.1/tcp/5001 key gen website-1
```

It's easier to just `make key`.

### Publish website

Modify `index.md`, then render/deploy using the `Makefile`

```{bash}
make all
```

Now the website is available from a stable URL based on `website-1` key.

https://ipfs.io/ipns/$HASH

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

These commands can be invoked manually.

### Publish other files and link from `index.md`

Add any file to IPFS, then publish to the IPNS hash from the `website-1` key.

```{bash}
echo "Hello IPFS" > hello.txt
./bin/add-ipfs.sh -k website-1 -f hello.txt
```

This file is now available from a stable URL:

https://ipfs.io/ipns/$HASH/hello.txt

The file can be referenced from `index.md` using a relative path.
Specify URL in markdown as `[a link to the text file](hello.txt)`

The file can be updated by re-running `add-ipfs.sh` and the URL will remain stable, even though the file content has changed.

## Creating a new website

Clone this repo into a new directory, then initialize a new git repo inside it.

```{bash}
git clone https://github.com/0xidm/mutable-ipfs-website new-website
cd new-website
rm -rf .git
git init --initial-branch=main
git add .
git commit -m "Initial commit"
```

Create a new git repo online (e.g. on github) and update your git remote to reference the new repo.

```{bash}
git remote add origin git@github.com:0xidm/new-website
git push -u origin main
```

## Pandoc

Pandoc is used to render `index.md` into `index.html`.

### Templates

Create a template, then modify as you like:

```{bash}
pandoc -D html > styles/template.html
```

### Styles

- select a style from `./styles`
- set STYLE in `settings.mk`
- invoke `make build`

Install new pandoc CSS styles by placing them into `./styles`.

### Render dark mode

The `default` style can be replaced with a dark theme called [water](https://github.com/kognise/water.css), by [Kognise](https://kognise.dev).

```{bash}
./bin/build-pandoc.sh water
```

To make this style permanent, set `STYLE=water` in `settings.mk`.

## Vanity IPNS hash

Discover vanity IPNS hashes with brute-force:

```{bash}
go install github.com/0xidm/peer-id-generator
peer-id-generator yourvanitystring
ipfs key import vanity-1 $HASH
```

Now you have a key called vanity-1 that produces a `/ipns/$HASH` that you like.

### 0xidm fork

The 0xidm fork modifies the original code by [meehow](github.com/meehow/peer-id-generator) to reserve 1 CPU for system usability.
If you want to brute-force even faster, or if you have only 1 CPU, install their code: `go install github.com/meehow/peer-id-generator`.
