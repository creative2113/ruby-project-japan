# Puma can serve each request in a thread from an internal thread pool.
# The `threads` method setting takes two numbers: a minimum and maximum.
# Any libraries that use thread pools should be configured to match
# the maximum value specified for Puma. Default is set to 5 threads for minimum
# and maximum; this matches the default thread size of Active Record.
#
threads 4, 16

# Specifies the `port` that Puma will listen on to receive requests; default is 3000.
#
port        ENV.fetch("PORT") { 3000 }

# Specifies the number of `workers` to boot in clustered mode.
# Workers are forked webserver processes. If using threads and workers together
# the concurrency of the application would be max `threads` * `workers`.
# Workers do not work on JRuby or Windows (both of which do not support
# processes).
#
workers 2

# Use the `preload_app!` method when specifying a `workers` number.
# This directive tells Puma to first boot the application and load code
# before forking the application. This takes advantage of Copy On Write
# process behavior so workers use less memory.
#
# preload_app!

# Allow puma to be restarted by `rails restart` command.
plugin :tmp_restart

# バインドに関して、間違っているかもしれないが、予想も込みで
#   shared_file=/opt/GETCD/shared
#   これはdeploy.rbで指定されている 「{:deproy_to}/shared/」で決められる
#
# 同じくdeploy.rbの
#   :puma_bind, "unix://#{shared_path}/tmp/sockets/puma.sock"
#   ここにソケットファイルが作られるので、これとバインドする。
# bundle exec puma -C /opt/GETCD/current/config/puma/dev.rb -b unix:///opt/GETCD/shared/tmp/sockets/puma.sock
