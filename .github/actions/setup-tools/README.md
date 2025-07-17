# Setup Tools Action

A composite GitHub Action that automatically sets up development tools based on your `.tool-versions` file.

## Features

✨ **Automatic Detection**: Reads `.tool-versions` and sets up all specified tools
🚀 **Smart Caching**: Enables package manager caching by default
🎯 **Conditional Setup**: Only sets up tools that are actually specified
📤 **Version Outputs**: Provides tool versions as outputs for other steps

## Supported Tools

This action supports any tool that can be managed by [asdf](https://asdf-vm.com/). The available tools depend on the [asdf plugin ecosystem](https://github.com/asdf-vm/asdf-plugins).

Common tools include Node.js, Ruby, Python, Java, Bun, and many more. Check the [asdf plugin directory](https://github.com/asdf-vm/asdf-plugins) for a complete list of available plugins.

## Usage

### Basic Usage

```yaml
steps:
  - uses: actions/checkout@v4
  - uses: ./.github/actions/setup-tools
```

### With Custom Options

```yaml
steps:
  - uses: actions/checkout@v4
  - uses: ./.github/actions/setup-tools
    with:
      cache: false  # Disable caching
```

### Using Outputs

```yaml
steps:
  - uses: actions/checkout@v4
  - name: Setup tools
    id: tools
    uses: ./.github/actions/setup-tools

  - name: Show versions
    run: |
      echo "Node.js: ${{ steps.tools.outputs.node-version }}"
      echo "Ruby: ${{ steps.tools.outputs.ruby-version }}"
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `cache` | Enable caching for package managers | `false` | `true` |

## Outputs

| Output | Description |
|--------|-------------|
| `nodejs-version` | Node.js version from .tool-versions |
| `node-version` | Node.js version (alias) |
| `ruby-version` | Ruby version from .tool-versions |
| `python-version` | Python version from .tool-versions |
| `java-version` | Java version from .tool-versions |
| `bun-version` | Bun version from .tool-versions |

## Example .tool-versions

```
ruby 3.4.2
nodejs 23.9.0
bun 1.2.18
python 3.11.5
java 17.0.2
```

For more information about `.tool-versions` format and available tools, see the [asdf documentation](https://asdf-vm.com/manage/configuration.html#tool-versions).