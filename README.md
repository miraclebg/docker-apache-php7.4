# Nimasystems PHP 7.4 images (patched)

Shared, batteries-included PHP 7.4 runtime images published to
`registry.nimahosts.com/nimasystems-public`:

| Image | SAPI | Port | Use |
|---|---|---|---|
| `apache2-php7.4-debian` | Apache 2.4 + mod_php (prefork) | 80 | single-container sites |
| `php7.4-fpm-debian` | php-fpm | 9000 | behind nginx (e.g. DesignConnected) |

PHP 7.4 has been end-of-life upstream since November 2022 and the official
`php:7.4-*` Docker images are no longer rebuilt, so security fixes that the PHP
project back-ports to 7.4 never reach them. These images close that gap.

## Patch level

| Version | Base | Patches |
|---|---|---|
| `7.4.33-pl1` | PHP 7.4.33 release tarball (GPG-verified) | CVE-2026-109618, CVE-2026-109619 (PHP security advisory, 21 Oct 2026) |

The patch level is compiled into PHP, so a running worker can be checked
directly:

```sh
php -v          # PHP 7.4.33-pl1 (cli) ...
php -r 'echo PHP_VERSION;'   # 7.4.33-pl1
```

`-plN` sorts *after* `7.4.33` in `version_compare()`, and `PHP_VERSION_ID` is
unchanged (`70433`), so Composer platform checks keep working.

## Layout

```
core/fpm, core/apache   official docker-library/php 7.4/bullseye recipes
                        (commit b9f17156020c, the last one before 7.4 was retired),
                        unchanged except for lines marked "NIMASYSTEMS"
patches/                patches applied, in order, to the PHP source before ./configure
pecl/                   vendored PECL release tarballs + SHA256SUMS
Dockerfile              extensions, locales, composer and the "app" user, on top of the core
docker-bake.hcl         wires core/<variant> into the Dockerfile as the "php-core" context
```

What the core build adds to the upstream recipe:

1. apt points at `archive.debian.org` - Debian 11 (bullseye) left LTS on
   2026-08-31 and its packages are being pruned from `deb.debian.org`.
2. Every `patches/*.patch` is applied with `--fuzz=0`, so a patch that does not
   match the source fails the build.
3. `PHP_EXTRA_VERSION` (e.g. `-pl1`) is stamped into `main/php_version.h`.
4. The patched tree is re-packed as `/usr/src/php.tar.xz`, so extensions built
   later with `docker-php-ext-install` are compiled from patched source too.

PECL extensions (`imagick`, `redis`, `yaml`, `apcu`) are pinned in
`Dockerfile` and their release tarballs are vendored in `pecl/` (verified
against `pecl/SHA256SUMS` at build time). Builds therefore never contact
pecl.php.net, which intermittently serves CI runners broken responses. To bump
one, replace its tarball from `https://pecl.php.net/get/<name>-<version>.tgz`,
regenerate `SHA256SUMS` (`shasum -a 256 *.tgz | sed 's/  / */' > SHA256SUMS`)
and update the version `ARG`. `excimer` is cloned from GitHub at a pinned tag.

## Adding a new backport

1. Download the upstream fix, e.g.
   `gh api repos/php/php-src/commits/<sha> -H "Accept: application/vnd.github.patch" > patches/0002-<name>.patch`
2. Bump `PHP_EXTRA_VERSION` / `VERSION` defaults in `docker-bake.hcl`
   (`-pl1` -> `-pl2`) and add a row to the table above.
3. Build locally: `docker buildx bake --set '*.platform=linux/amd64' --load`
4. Tag and push: `git tag 7.4.33-pl2 && git push origin 7.4.33-pl2`

## Releasing

Pushing a tag `7.4.33-plN` runs `.github/workflows/docker-publish.yml`: amd64
and arm64 are built natively on separate runners, pushed as
`<version>-amd64` / `<version>-arm64`, then merged into multi-arch
`<version>`, `<git sha>` and `latest` tags for both images. A manual
`workflow_dispatch` run builds a given version without moving `latest`.
