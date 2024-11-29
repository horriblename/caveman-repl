# Caveman-repl

REPL plugin for neovim, because somehow everything else does too much for me.

## Usage

commands:

- [#CavemanReplStart]
- [#CavemanReplSend]

### CavemanReplStart

Start a REPL session. this will bring up a `:terminal` session running the
repl command (`b:caveman_repl_cmd` or if not set, your user shell)

### CavemanReplSend

Send the selected text to the repl, options:

All of these options use the `b:caveman_repl_*` variables if not specified.

- `-trim=<trim_behavior>`: how to do indentation trimming. Possible values:
  - `none`: do not trim indents
  - `always`: trim all indents
  - `follow_first_line`: Indentation on first line will be trimmed. Following
    lines are trimmed to the same level as the first.
  - `follow_least`: Looks for the line with the least amount of indent.
    Other lines are trimmed to match that line.
