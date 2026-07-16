# Linux and macOS installer operations

`install.sh` validates its CUDA backend, model set, booleans, and port before it
delegates to the cross-platform Python installer.

Run a normal installation with environment variables:

```bash
CUDA=cu128 MODELS=5b WITH_MANAGER=true START=false ./install.sh
```

Or use explicit arguments:

```bash
./install.sh --cuda=cpu --models=5b --with-manager=true --start=false
```

The installer resolves ComfyUI's supported `requirements.txt`. It does not
automatically consume generated local environment snapshots such as
`all-requirements.txt`. A reviewed additional requirements file is opt-in:

```bash
EXTRA_REQUIREMENTS=/absolute/path/to/reviewed-requirements.txt ./install.sh
```

Use the network-free dry run to validate command construction before a large
installation:

```bash
./install.sh --cuda=cu128 --models=5b --start=false --dry-run=true
```
