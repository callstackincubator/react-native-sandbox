const repackCommands = require('@callstack/repack/commands/rspack')
const commands = repackCommands.filter(cmd => cmd.name.startsWith('webpack'))

module.exports = {
  commands,
}
