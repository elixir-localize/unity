import Config

# The unity escript carries Localize's English and root locale data only.
# Any other locale named with `--locale` is downloaded from the Localize
# CDN on first use, checked against Localize's hash manifest, and cached.
# Mix embeds this file in the escript, one installed with
# `mix escript.install hex unity` included.
config :localize, allow_runtime_locale_download: true
