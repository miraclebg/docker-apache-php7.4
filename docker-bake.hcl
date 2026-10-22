# Builds both public images from one recipe:
#
#   registry.nimahosts.com/nimasystems-public/apache2-php7.4-debian  (mod_php)
#   registry.nimahosts.com/nimasystems-public/php7.4-fpm-debian      (php-fpm)
#
# Each image = core/<variant> (official docker-library/php 7.4.33 recipe +
# patches/) feeding the extensions Dockerfile at the repo root through the
# "php-core" named context.
#
# Local build (current platform, loaded into docker):
#   docker buildx bake --load
# Single variant:
#   docker buildx bake fpm --load
# CI overrides VERSION / TAG_SUFFIX / PLATFORMS and pushes.

variable "REGISTRY" {
  default = "registry.nimahosts.com/nimasystems-public"
}

# Image version, e.g. "7.4.33-pl1". Becomes the image tag and the OCI version label.
variable "VERSION" {
  default = "7.4.33-pl1"
}

# Must match the "-plN" part of VERSION: it is compiled into PHP_VERSION.
variable "PHP_EXTRA_VERSION" {
  default = "-pl1"
}

# Appended to every tag; CI uses "-amd64" / "-arm64" for per-arch pushes that a
# later job merges into one multi-arch manifest.
variable "TAG_SUFFIX" {
  default = ""
}

# Also tag :latest (CI sets this for release tags only).
variable "TAG_LATEST" {
  default = false
}

variable "PLATFORMS" {
  default = []
}

group "default" {
  targets = ["apache", "fpm"]
}

target "_core" {
  contexts = {
    patches = "./patches"
  }
  args = {
    PHP_EXTRA_VERSION = PHP_EXTRA_VERSION
  }
  platforms = PLATFORMS
}

target "core-apache" {
  inherits = ["_core"]
  context  = "./core/apache"
}

target "core-fpm" {
  inherits = ["_core"]
  context  = "./core/fpm"
}

target "_runtime" {
  context    = "."
  dockerfile = "Dockerfile"
  target     = "runtime-prod"
  platforms  = PLATFORMS
  args = {
    VERSION = VERSION
  }
}

target "apache" {
  inherits = ["_runtime"]
  contexts = {
    php-core = "target:core-apache"
  }
  args = {
    EXPOSE_PORT = "80"
  }
  tags = concat(
    ["${REGISTRY}/apache2-php7.4-debian:${VERSION}${TAG_SUFFIX}"],
    TAG_LATEST ? ["${REGISTRY}/apache2-php7.4-debian:latest${TAG_SUFFIX}"] : []
  )
}

target "fpm" {
  inherits = ["_runtime"]
  contexts = {
    php-core = "target:core-fpm"
  }
  args = {
    EXPOSE_PORT = "9000"
  }
  tags = concat(
    ["${REGISTRY}/php7.4-fpm-debian:${VERSION}${TAG_SUFFIX}"],
    TAG_LATEST ? ["${REGISTRY}/php7.4-fpm-debian:latest${TAG_SUFFIX}"] : []
  )
}
