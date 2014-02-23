require File.expand_path( File.join(File.dirname(__FILE__), %w[.. lib rack streaming_proxy]))

require "rack/test"

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
end
