require_relative '../lib/ruby_zmq_framework'

$stdout.sync = true

# Runs the library's StateRegistry as a flow node. What it caches is
# decided entirely by the subscribes list in flow.yml — this file knows
# nothing about topics. Prints its snapshot every 5 seconds.
registry = RubyZmqFramework.boot(RubyZmqFramework::StateRegistry)
puts 'online'

loop do
  sleep 5
  puts '---- Global State Snapshot ----'
  pp registry.store
end
