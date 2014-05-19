# A sample Guardfile
# More info at https://github.com/guard/guard#readme

guard :rubocop do
  watch(%r{.+\.rb$})
  watch(%r{(?:.+/)?\.rubocop\.yml$}) { |m| File.dirname(m[0]) }
end

guard :rspec, :cmd => 'rspec --drb --drb-port #{ENV["RSPEC_PORT"]}' do
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^src/(.+)\.rb$})     { |m| "spec/src/#{m[1]}_spec.rb" }
  watch(%r{^lib/(.+)\.rb$})     { |m| "spec/lib/#{m[1]}_spec.rb" }

  watch('spec/spec_helper.rb')   { "spec" }
  watch('src/helpers/loader.rb') { "spec" }
  watch('config.ru') { "spec" }
end


guard 'spork', :rspec_env => { 'RAILS_ENV' => 'test' }, rspec_port: ENV['RSPEC_PORT'] do
  watch('config.ru')
  watch('Gemfile.lock')
  watch('spec/spec_helper.rb') { :rspec }
end
