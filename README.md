# Claude Ruby Plugins

A Claude Code marketplace providing plugins for Ruby development.

## Installation

Add this marketplace to Claude Code:

```bash
/plugin marketplace add stevegeek/claude-ruby-plugins
```

Or add to your project's `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": [
    "stevegeek/claude-ruby-plugins"
  ]
}
```

Then browse and install plugins:

```bash
/plugin
```

## Available Plugins

- **ruby-rbs** - RBS type signature writing, reviewing, and maintenance

---

# ruby-rbs

Skills, commands, and agents for writing Ruby RBS type signatures - inline annotations, standalone `.rbs` files, and type maintenance.

## What is RBS?

RBS is Ruby's official type signature language, introduced with Ruby 3.0. It describes the structure of Ruby programs—classes, modules, methods, and their types—enabling static type checking with tools like [Steep](https://github.com/soutaro/steep).

## Installation

```bash
/plugin install ruby-rbs@stevegeek-marketplace
```

Or in `.claude/settings.json`:

```json
{
  "enabledPlugins": {
    "ruby-rbs@stevegeek-marketplace": true
  }
}
```

## Agents

### rbs-creator

Writes RBS type signatures for an entire codebase. Asks whether you want inline or standalone RBS, then works methodically through all Ruby files, setting up Steep, writing signatures, and validating as it goes.

### rbs-maintainer

Validates and maintains existing RBS signatures. Runs `rbs validate`, `steep check`, finds gaps, and fixes issues.

### rbs-reviewer

Critically reviews RBS signatures for quality: suggests generics, replaces `untyped`, recommends supertypes/interfaces.

## Commands

### `/write-rbs <path>`

Write standalone RBS signatures for Ruby files. Analyzes code, finds tests, optionally traces types, and creates `sig/*.rbs` files.

### `/write-inline-rbs <path>`

Add inline RBS annotations to Ruby files using `rbs-inline` comment syntax.

## Skill

The `ruby-rbs` skill provides comprehensive RBS knowledge. It's easier to use a command or agent, but you can load the skill directly by asking Claude to use its RBS skill.

## Type Tracer

Runtime tool that instruments code execution to discover actual types:

```bash
ruby plugins/ruby-rbs/scripts/type_tracer.rb -c 'MyClass' -f json test/my_test.rb
```

## Quick Examples

### Inline RBS (in Ruby files)

```ruby
# rbs_inline: enabled

class User
  attr_reader :name #: String
  attr_reader :email #: String?

  #: (String, ?String?) -> void
  def initialize(name, email = nil)
    @name = name
    @email = email
  end
end
```

### Standalone RBS (separate files)

```rbs
# sig/user.rbs
class User
  attr_reader name: String
  attr_reader email: String?

  def initialize: (String, ?String?) -> void
end
```

## Acknowledgments

- [Climbing Steep hills, or adopting Ruby 3 types with RBS](https://evilmartians.com/chronicles/climbing-steep-hills-or-adopting-ruby-types) by Evil Martians
- [RBS official documentation](https://github.com/ruby/rbs/tree/master/docs)
- [rbs-inline wiki](https://github.com/soutaro/rbs-inline/wiki)

---

## License

Unlicense
