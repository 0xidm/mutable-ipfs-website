# Mutable Website on IPFS

Publish a website to IPFS that can be updated without breaking all the URLs.
In more technical terms: create a mutable IPFS website with a stable IPNS hash.
Using this method, a website built with relative URLs will function the same on IPFS as on the classic web.

- [github project](https://github.com/0xidm/mutable-ipfs-website)
- [view on ipfs](https://ipfs.io/ipns/12D3KooWPEU9jjJKHWdTJwZgr3xAegKdQEspikURgJ21cmooxidm)

## Quick Start

```{bash}
git clone https://github.com/0xidm/mutable-ipfs-website new-website
cd new-website
cp settings.example.mk settings.mk
# change IPFS_API in settings.mk if IPFS not on localhost
make key build publish
```

You now have a website with a URL like https://ipfs.io/ipns/$HASH

Make some changes to `index.md`, then update the website:

```{bash}
make build publish
```

Even though the content has changed, the URL remains stable.

## How this Works

One unique feature of [IPFS](https://ipfs.io/ipns/docs.ipfs.tech/) is that it is [immutable](https://ipfs.io/ipns/docs.ipfs.tech/concepts/immutability/).
When content is changed on IPFS, this produces a new URL to reference the new content.
For content like a website, it's desirable to have a URL that stays the same - and the trouble with IPFS occurs when the website needs to be updated.

[IPNS](https://ipfs.io/ipns/docs.ipfs.tech/concepts/ipns/) provides a Name System that can solve the problem of ever-changing IPFS URLs.
When IPFS content is updated, IPNS can be updated to point to the new content.
This IPNS hash never changes; it is stable over time.
On its own, IPNS is a complete solution for single-page websites.

What if you needed to publish many files at once, like a regular website?
[MFS](https://ipfs.io/ipns/docs.ipfs.tech/concepts/file-systems/#mutable-file-system-mfs) is a Mutable File System that provides a familiar path, subdirectory, and file metaphor on top of IPFS.
With MFS, it's possible to publish and update a whole hierarchy of files and folders, just like a regular website.
MFS provides a natural bridge between HTTP, HTML, and IPFS so that URLs can contain a file path - like normal.

This method for publishing via IPFS+IPNS+MFS+HTTP enables a classic website built for IPv4+HTTP (with relative URLs) to be published without modification on IPFS.

## Requirements

Rendering markdown to html requires pandoc. Try the following to install:

- macos: `brew install pandoc`
- ubuntu/debian: `apt install pandoc`
- redhat: `rpm install pandoc`

## Usage

### Create a new website

Clone into the `new-website` path and remove the existing git repo.

```{bash}
git clone https://github.com/0xidm/mutable-ipfs-website new-website
cd new-website
rm -rf .git
```

### Configuration

Copy `settings.example.mk` to `settings.mk`.

The following variables can be changed:

- `IPFS_API`: the IP v4 address and TCP port of your IPFS node. Default is `/ip4/127.0.0.1/tcp/5001`
- `IPFS_KEY`: name of IPFS key; also used as MFS path. Default is `website-1`
- `STYLE`: a pandoc style used when `index.md` is rendered to `index.html`

### Generate key for stable IPNS hash

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

### Publish any other files

Add any file to IPFS, then publish to the IPNS hash from the `website-1` key.

```{bash}
echo "Hello IPFS" > hello.txt
./bin/add-ipfs.sh -k website-1 -f hello.txt
```

This file is now available from a stable URL:

https://ipfs.io/ipns/$HASH/hello.txt

The file can be updated by re-running `add-ipfs.sh` and the URL will remain stable, even though the file content has changed.

#### Link any file from `index.md`

A file can be referenced from `index.md` using a relative path.
In the `hello.txt` example, specify URL in markdown as `[a link to the text file](hello.txt)`

#### Subdirectories

A file can be placed in an MFS subdirectory.
In the following example, `hello.txt` is placed into the `documents` subdirectory:

```{bash}
echo "Hello IPFS" > hello.txt
./bin/add-ipfs.sh -k website-1 -d documents -f hello.txt
```

The file is now available inside the `documents` subdirectory:

https://ipfs.io/ipns/$HASH/documents/hello.txt

Currently just 1-level of subdirectory nesting is supported.
For more complex trees, consider the IPFS Web UI.

### IPFS Web UI

The IPFS web UI is an easy way to manage files for a website.
Using the Files interface, navigate to `/public/$YOUR_KEY` to see the website files.

#### Force IPNS Refresh

Any time files are changed, IPNS must be updated.
Although `add-ipfs.sh` generally updates IPNS automatically, sometimes IPNS must be manually refreshed.
When the IPFS Web UI changes files - or *any* process other than `add-ipfs.sh` - it's necessary to refresh IPNS.

The following will refresh IPNS for the configured key:

```{bash}
make refresh-ipns
```

which expands into:

```{bash}
IPFS_API=$(IPFS_API) ./bin/add-ipfs.sh -k $(IPFS_KEY)
```

Since no filename is provided to `add-ipfs.sh`, this command only updates IPNS.

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

Now you have a key called `vanity-1` that produces a `/ipns/$HASH` that you like.

To view your IPNS hash again:

```{bash}
ipfs key list -l --ipns-base b58mh
```

### 0xidm fork

The 0xidm fork modifies the original code by [meehow](https://github.com/meehow/peer-id-generator) to reserve 1 CPU for system usability.
If you want to brute-force even faster, or if you have only 1 CPU, install their code: `go install github.com/meehow/peer-id-generator`.

## Version control for website

Create a new local git repo for the site.

```{bash}
git init --initial-branch=main
git add .
git commit -m "Initial commit"
```

Create a remote git repo (e.g. on github) and update your git remote to reference the new repo.

```{bash}
git remote add origin git@github.com:0xidm/new-website
git push -u origin main
```
