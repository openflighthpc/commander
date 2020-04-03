require 'commander'

extend Commander::CLI

at_exit { run!(ARGV) }
