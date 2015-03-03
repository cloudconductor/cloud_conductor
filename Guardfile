# A sample Guardfile
# More info at https://github.com/guard/guard#readme

# rubocop: disable Style/RegexpLiteral

RSPEC_PORT = ENV['RSPEC_PORT'] || 8989

guard :rspec, cmd: "spring rspec" do
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^spec/factories/.+\.rb$}) { 'spec' }
  watch(%r{^app/(.+)\.rb$})     { |m| "spec/app/#{m[1]}_spec.rb" }
  watch(%r{^lib/(.+)\.rb$})     { |m| "spec/lib/#{m[1]}_spec.rb" }

  watch('spec/spec_helper.rb')   { 'spec' }
  watch('config.ru') { 'spec' }
end

guard :rubocop, all_on_start: false do
  watch(%r{.+\.rb$})
  watch(%r{(?:.+/)?\.rubocop\.yml$}) { |m| File.dirname(m[0]) }
end
