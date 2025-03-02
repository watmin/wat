# frozen_string_literal: true

require "wat"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Enable focus filtering
  config.filter_run_when_matching :focus

  # Optional: If no focused tests are found, run all tests
  config.run_all_when_everything_filtered = true
end
