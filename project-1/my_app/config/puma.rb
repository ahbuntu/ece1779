port        ENV['PORT']     || 3000
environment ENV['RACK_ENV'] || 'development'
threads     (ENV["MIN_PUMA_THREADS"] || 0), (ENV["MAX_PUMA_THREADS"] || 16)
#workers     (ENV["MIN_PUMA_WORKERS"] || 1), (ENV["MAX_PUMA_WORKERS"] || 3)

pidfile "/var/www/my_app/shared/tmp/pids/puma.pid"
state_path "var/www/my_app/shared/tmp/puma-state"
activate_control_app

# preload_app!
