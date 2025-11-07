# Zephyr Docker Build Template

Minimal Zephyr build template that builds entirely in a container. All state (modules, builds, caches) stays in this repo. Build targets exist for the Zephyr native simulator and Nordic Semiconductor `nrf9151dk` development board. Additional targets can be built with a compose command override flag.  

Comes with an example manifest (`manifest/west.yml`) which fetches the [Zephyr custom shell module demo](https://docs.zephyrproject.org/latest/samples/subsys/shell/shell_module/README.html) and builds it against either system libraries or `nrf9151dk` dependencies.

## Quick start

```bash
# (optional) keep file ownership clean
export UID=$(id -u); export GID=$(id -g)

# 1) Fetch Zephyr + modules
docker compose run --rm bootstrap

# 2) Build (native_sim)
docker compose run --rm build-native

# 3) Run (native_sim)
docker compose run --rm run-native
# Artifacts: build/zephyr/output.elf

```

## Other common commands

```bash
# Generic builder (can override BOARD)
docker compose run --rm build
docker compose run --rm -e BOARD=nrf9151dk/nrf9151 build   # example override

# Preset MCU build
docker compose run --rm build-nrf9151dk

# Clean builds
docker compose run --rm clean-build   # remove build/
docker compose run --rm clean-all     # remove build/ and west state

# Hard reset to the minimal skeleton (keeps .git)
docker compose run --rm unbootstrap-hard
docker compose run --rm unbootstrap-hard-dry   # preview
```

### *Notes*  
1. Defaults live in .zephyr-build.env. You can override per command with -e VAR=… (e.g., BOARD, OVERLAY_CONFIG, CONF_FILE).
