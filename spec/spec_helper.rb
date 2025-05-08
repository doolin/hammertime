require 'simplecov'
SimpleCov.start do
  enable_coverage :branch
  add_filter '/spec/'

  # Track files by type
  track_files 'lib/**/*.rb'

  # Add groups for better organization
  add_group 'Core', 'lib/hammertime.rb'

  # Detailed HTML report
  formatter SimpleCov::Formatter::HTMLFormatter
end

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'hammertime'
require 'rspec'

module MenuTestHelpers
  def with_menu_choice(choice)
    allow(Hammertime).to receive(:stopped).and_return(false)
    allow(Hammertime).to receive(:stopped=)

    # Create a mock menu that will handle the choice
    menu = Class.new do
      attr_accessor :choices

      def initialize
        @choices = {}
      end

      def choice(name, *args, &block)
        @choices[name] = block
      end

      def prompt=(*); end
      def default=(*); end
      def select_by=(*); end
    end.new

    # Allow the menu to be configured
    yield(menu) if block_given?

    # Find and execute the matching choice
    matching_choice = menu.choices.keys.find { |k| k.start_with?(choice) }
    if matching_choice
      # Execute the menu choice block and get its return value
      block_result = menu.choices[matching_choice].call

      # Handle special cases for menu choices
      case choice
      when 'Continue'
        true # Return true to exit menu loop and raise error
      when 'Ignore'
        nil # Return from hammertime_raise without raising
      when 'Permit by type'
        ::Hammertime.ignored_errors << RuntimeError
        true # Return true to exit menu loop after adding to ignored list
      when 'Permit by line'
        ::Hammertime.ignored_lines << 'test.rb:1'
        true # Return true to exit menu loop after adding to ignored list
      when 'Backtrace', 'Debug', 'Console'
        false # Return false to stay in menu
      else
        block_result # Use the block's return value as fallback
      end
    else
      nil
    end
  end
end

RSpec.configure do |config|
  config.include MenuTestHelpers

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = 'spec/examples.txt'
  config.disable_monkey_patching!
  config.warnings = true

  config.default_formatter = 'doc' if config.files_to_run.one?

  config.order = :random
  Kernel.srand config.seed
end
