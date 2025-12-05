# Ruby RBS Plugin for Claude Code

A Claude Code plugin providing skills for writing RBS type signatures in Ruby projects.

## What is RBS?

RBS is Ruby's official type signature language, introduced with Ruby 3.0. It describes the structure of Ruby programs—classes, modules, methods, and their types—enabling static type checking with tools like [Steep](https://github.com/soutaro/steep).

## Installation

### Option 1: Install as a Plugin (Recommended)

Add this repository as a marketplace and install the plugin:

```bash
# Add the marketplace
claude /plugin marketplace add https://github.com/anthropics/claude-rbs-skill

# Install the plugin
claude /plugin install ruby-rbs
```

Or use the interactive plugin menu:

```bash
claude /plugin
```

### Option 2: Copy Skills Directly

If you prefer not to use the plugin system, copy the skills directly to your Claude Code skills directory:

```bash
# Clone the repository
git clone https://github.com/anthropics/claude-rbs-skill.git

# Copy the skill to your global skills directory
cp -r claude-rbs-skill/skills/ruby-rbs ~/.claude/skills/

# Or copy to a project-specific location
cp -r claude-rbs-skill/skills/ruby-rbs .claude/skills/
```

### Option 3: Project-Level Plugin

Add this plugin to your project's `.claude/settings.json`:

```json
{
  "plugins": {
    "marketplaces": ["https://github.com/anthropics/claude-rbs-skill"],
    "installed": ["ruby-rbs"]
  }
}
```

Team members will automatically get the plugin when they trust the repository.

## Usage

The skill activates automatically when you ask Claude Code to help with Ruby type signatures. It covers:

- **Inline RBS** - Type annotations as comments in Ruby files using `rbs-inline`
- **Standalone RBS files** - Separate `.rbs` signature files in a `sig/` directory
- **Steep integration** - Type checker setup and configuration
- **Scaffolding** - Generating initial types from existing code

For example:

```
> I want you to use your RBS skill to write inline RBS types for all ruby files under lib/. Avoid using untyped. You can scaffold and enhance. Remember to check with steep as you go.
```

Claude will then prompt you to confirm loading the skill:

```
> The "ruby-rbs" skill is running

● Now I'll create the inline RBS
...
```

## Plugin Structure

```
claude-rbs-skill/
├── .claude-plugin/
│   ├── plugin.json              # Plugin metadata
│   └── marketplace.json         # Marketplace manifest
├── skills/
│   └── ruby-rbs/
│       ├── SKILL.md             # Main skill entry point
│       ├── subskills/
│       │   ├── inline/SKILL.md  # Inline RBS annotations
│       │   └── rbs-files/SKILL.md # Standalone .rbs files
│       └── references/
│           ├── type-syntax.md   # Complete type syntax
│           ├── patterns.md      # Patterns and gotchas
│           ├── steep-integration.md # Steep setup
│           └── scaffolding.md   # Generate RBS from code
└── test/                        # Example typed projects
    ├── inline/                  # Inline RBS examples
    └── standalone/              # Standalone RBS examples
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

This skill was written with guidance from:

- [Climbing Steep hills, or adopting Ruby 3 types with RBS](https://evilmartians.com/chronicles/climbing-steep-hills-or-adopting-ruby-types) by Evil Martians - An excellent practical guide to adopting RBS
- [RBS official documentation](https://github.com/ruby/rbs/tree/master/docs) - The authoritative syntax reference
- [rbs-inline wiki](https://github.com/soutaro/rbs-inline/wiki) - Inline annotation syntax guide

## License

Unlicense
