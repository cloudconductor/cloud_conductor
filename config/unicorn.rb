worker_processes 4
pid File.expand_path('unicorn.pid')
stderr_path File.expand_path('log/unicorn.stderr.log')
stdout_path File.expand_path('log/unicorn.stdout.log')
listen ENV['CC_PORT'] || 8080, :tcp_nopush => true
timeout 1200
preload_app true
