# Note: This is a fork

The version number was reset to 1.0.0 at the time of forking and
roughly maps to v4.4.4 of the upstream project.

You can find the original repo at
[commander-rb/commander](https://github.com/commander-rb/commander).

This fork adds a number of patches and modifications to the upstream
project that support the OpenFlightHPC tools.

To ship a new release, do the following:

 * Increment the version number in `version.rb`

Documentation from the upstream project follows.

---

# Commander

The complete solution for Ruby command-line executables.
Commander bridges the gap between other terminal related libraries
you know and love (Slop, HighLine), while providing many new
features, and an elegant API.

## Features

* Auto-generates help documentation via pluggable help formatters
* Optional default command when none is present
* Global / Command level options
* Packaged with one help formatters (Terminal)
* Imports the highline gem for interacting with the terminal
* Adds additional user interaction functionality
* Highly customizable progress bar with intuitive, simple usage
* Sexy paging for long bodies of text
* Command aliasing (very powerful, as both switches and arguments can be used)
* Use the `commander` executable to initialize a commander driven program

## Installation

    $ gem install commander

## Example

For more option examples view the `Commander::Command#option` method. Also
an important feature to note is that action may be a class to instantiate,
as well as an object, specifying a method to call, so view the RDoc for more information.

### Classic style

```ruby
require 'rubygems'
require 'commander/import'

# :name is optional, otherwise uses the basename of this executable
program :name, 'Foo Bar'
program :version, '1.0.0'
program :description, 'Stupid command that prints foo or bar.'

command :foo do |c|
  c.syntax = 'foobar foo'
  c.description = 'Displays foo'
  c.action do |args, options|
    say 'foo'
  end
end

command :bar do |c|
  c.syntax = 'foobar bar [options]'
  c.description = 'Display bar with optional prefix and suffix'
  c.option '--prefix STRING', 'Adds a prefix to bar'
  c.option '--suffix STRING', 'Adds a suffix to bar'
  c.action do |args, options|
    options.default :prefix => '(', :suffix => ')'
    say "#{options.prefix}bar#{options.suffix}"
  end
end
```

Example output:

```
$ foobar bar
# => (bar)

$ foobar bar --suffix '}' --prefix '{'
# => {bar}
```

### Modular style

**NOTE:** Make sure to use `require 'commander'` rather than `require 'commander/import'`, otherwise Commander methods will still be imported into the global namespace.

```ruby
require 'rubygems'
require 'commander'

class MyApplication
  extend Commander::CLI

  program :name, 'Foo Bar'
  program :version, '1.0.0'
  program :description, 'Stupid command that prints foo or bar.'

  command :foo do |c|
    c.syntax = 'foobar foo'
    c.description = 'Displays foo'
    c.action do |args, options|
      say 'foo'
    end
  end
end

MyApplication.run!(ARGV) if $0 == __FILE__
```

## Commander Goodies

### Option Defaults

The options struct passed to `#action` provides a `#default` method, allowing you
to set defaults in a clean manner for options which have not been set.

```ruby
command :foo do |c|
  c.option '--interval SECONDS', 'Interval in seconds'
  c.option '--timeout SECONDS', 'Timeout in seconds'
  c.action do |args, options|
    options.default \
      :interval => 2,
      :timeout  => 60
  end
end
```

### Command Aliasing

Aliases can be created using the `#alias_command` method like below:

```ruby
command :'install gem' do |c|
  c.action { puts 'foo' }
end
alias_command :'gem install', :'install gem'
```

Or more complicated aliases can be made, passing any arguments
as if it was invoked via the command line:

```ruby
command :'install gem' do |c|
  c.syntax = 'install gem <name> [options]'
  c.option '--dest DIR', String, 'Destination directory'
  c.action { |args, options| puts "installing #{args.first} to #{options.dest}" }
end
alias_command :update, :'install gem', 'rubygems', '--dest', 'some_path'
```

```
$ foo update
# => installing rubygems to some_path
```

### Command Defaults

Although working with a command executable framework provides many
benefits over a single command implementation, sometimes you still
want the ability to create a terse syntax for your command. With that
in mind we may use `#default_command` to help with this. Considering
our previous `:'install gem'` example:

```ruby
default_command :update
```

```
$ foo
# => installing rubygems to some_path
```

Keeping in mind that commander searches for the longest possible match
when considering a command, so if you were to pass arguments to foo
like below, expecting them to be passed to `:update`, this would be incorrect,
and would end up calling `:'install gem'`, so be careful that the users do
not need to use command names within the arguments.

```
$ foo install gem
# => installing  to
```

### Long descriptions

If you need to have a long command description, keep your short description under `summary`, and consider multi-line strings for `description`:

```ruby
  program :summary, 'Stupid command that prints foo or bar.'
  program :description, %q(
#{c.summary}

More information about that stupid command that prints foo or bar.

And more
  )
```

### Additional Global Help

Arbitrary help can be added using the following `#program` symbol:

```ruby
program :help, 'Author', 'TJ Holowaychuk <tj@vision-media.ca>'
```

Which will output the rest of the help doc, along with:

    AUTHOR:

      TJ Holowaychuk <tj@vision-media.ca>

### Global Options

WIP: Update globals behaviour

### Tracing

WIP: Update OpenFlight --trace behaviour

## Running Specifications

    $ rake spec

OR

    $ spec --color spec

## Contrib

Feel free to fork and request a pull, or submit a ticket
http://github.com/commander-rb/commander/issues

## License

This project is available under the MIT license. See LICENSE for details.
