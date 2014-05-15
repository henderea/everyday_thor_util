# EverydayThorUtil

Two parts: `everyday_thor_util/thor-fix` patches `Thor` with a fix for help messages with multi-level command nesting not showing the full command string. `everyday_thor_util/plugin-helper` provides `everyday-plugins` types for `Thor` commands and `Thor` flags

## Installation

Add this line to your application's Gemfile:

    gem 'everyday_thor_util'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install everyday_thor_util

## Usage

###Thor patch
An issue I found with `Thor` is that when you have subcommands of a subcommand, the help messages mess up and just show the script name and the last subcommand.  `everyday_thor_util/thor-fix` provides a patch for this issue that will make sure that the messages display the full chain of commands by storing the parent command and referencing it (recursively) when getting the banner.  If you just want the patch, use
```ruby
require 'everyday_thor_util/thor-fix'
```
instead of requiring the base package (which loads the `plugin-helper` module too)

###Plugin Helper
My gem `everyday-plugins` is something I use for my own projects for allowing a plugin-based structure that can support loading plugins from other gems that provide them in the right way.  The `everyday_thor_util/plugin-helper` module will provide you with a method to register types for `Thor` commands, flags, and helpers.

Here's an example (from my `mvn2chain` gem; note that I'm assuming you have already included `everyday-plugins` properly):
```ruby
require 'everyday_thor_util'
EverydayThorUtil::SubCommandTypes.def_types(:command_ids, :flag, :command, :helper)
register(:command, id: :path, parent: nil, name: 'path', short_desc: 'path', desc: 'print out the path of the current file') { puts __FILE__ }

register(:command, id: :dep, parent: nil, name: 'dep', aliases: %w(deps dependency dependencies), short_desc: 'dep SUBCOMMAND ARGS...', desc: 'alter the stored dependencies')

register(:command, id: :dep_add, parent: :dep, name: 'add', aliases: %w(register reg), short_desc: 'add DEP_ID DEP', desc: 'add a dependency to the list') { |dep_id, dep|
  #contents excluded for brevity
}

register :flag, name: :force, aliases: ['-f'], parent: :dep_add, type: :boolean, desc: 'force the dependency to be added even if the provided directory does not contain a pom.xml or the dependency ID is already in use'

register(:helper, name: 'chain_args', parent: nil) { |dep_id, arg_hash, exclude|
  #contents excluded for brevity
}

root_command = Class.new(Thor)
Plugins.get :command, root_command, nil

root_command.start(ARGV)
```

A parent of `nil` means the parent is the root command.  Otherwise, use the `:id` parameter of the parent as the value of `:parent`.  For helpers, you can provide `global: true` instead of a parent if you want it to be available in all `Thor` command classes.  Command aliases actually duplicate the command and any children because I don't know of a `Thor` feature that lets you provide command aliases.  It will automatically replace the value provided for `:name` with the alias name in the `:short_desc` parameter that is used for the copied commands.

####Define Helper
The `plugin-helper` package contains a method for defining a pre-made helper function.  Currently, the only one I have created is `print_info`, but more may be added as I come up with them.

Here is an example of `print_info` (note that I'm assuming you have already included `everyday-plugins` properly):

```ruby
require 'everyday_thor_util'
EverydayThorUtil::SubCommandTypes.def_types(:command_ids, :flag, :command, :helper)
EverydayThorUtil::SubCommandTypes.def_helper(:helper, :print_info)
register(:command, id: :dep_add, parent: :dep, name: 'add', aliases: %w(register reg), short_desc: 'add DEP_ID DEP', desc: 'add a dependency to the list') { |dep_id, dep|
  print_info(__method__) { |p| eval p }
}
```

Now, if you run `mvn2chain dep add -f my_id /path/to/my/id`, it will print

	command: mvn2chain dep add
	parent_options: {"force"=>true}
	options: {"force"=>true}
	dep_id: my_id
	dep: /path/to/my/id

If you leave off the block passed to the `print_info` helper, it will not print out the parameter info.  This is because the scope change causes it to lose reference to the variables, meaning that in order to show the parameter values, it has to be given a way to turn the parameter name into a value.

## Contributing

1. Fork it ( https://github.com/henderea/everyday_thor_util/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
