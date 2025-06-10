require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'highline'

RSpec.describe Hammertime do
  describe '.ignored_errors' do
    it 'defaults to including LoadError' do
      expect(Hammertime.ignored_errors).to include(LoadError)
    end

    it 'can be modified' do
      original = Hammertime.ignored_errors.dup
      Hammertime.ignored_errors << RuntimeError
      expect(Hammertime.ignored_errors).to include(RuntimeError)
      Hammertime.ignored_errors.replace(original)
    end
  end

  describe '.ignored_lines' do
    it 'defaults to an empty array' do
      expect(Hammertime.ignored_lines).to be_empty
    end

    it 'can be modified' do
      Hammertime.ignored_lines << 'test.rb:1'
      expect(Hammertime.ignored_lines).to include('test.rb:1')
      Hammertime.ignored_lines.clear
    end
  end

  describe '.stopped' do
    # We assume that any particular session invoking Hammertime
    # will not initialize the @stopped class instance variable.
    # Without this, spec order matters, or the spec will fail
    # intermittently.
    before { Hammertime.stopped = false }

    it 'defaults to false' do
      expect(Hammertime.stopped).to be false
    end

    it 'can be set to true' do
      Hammertime.stopped = true
      expect(Hammertime.stopped).to be true
      Hammertime.stopped = false
    end
  end

  describe '.debug_supported?' do
    it 'returns true when debug gem is available' do
      expect(Hammertime.debug_supported?).to be true
    end
  end

  # TODO: Fix the order dependency of this example group.
  xdescribe '#hammertime_raise' do
    it 'raises the original error when ignored' do
      error = RuntimeError.new('test error')
      allow(Hammertime).to receive(:ignored_errors).and_return([RuntimeError])
      expect { Object.new.hammertime_raise(error) }.to raise_error(RuntimeError, 'test error')
    end

    it 'handles string errors' do
      expect { Object.new.hammertime_raise('test error') }.to raise_error(RuntimeError, 'test error')
    end

    it 'handles error with message' do
      expect { Object.new.hammertime_raise(RuntimeError, 'test error') }.to raise_error(RuntimeError, 'test error')
    end

    it 'handles error with message and backtrace' do
      backtrace = ['test.rb:1']
      expect do
        Object.new.hammertime_raise(RuntimeError, 'test error', backtrace)
      end.to raise_error(RuntimeError, 'test error')
    end

    it 'handles no arguments' do
      expect { Object.new.hammertime_raise }.to raise_error(RuntimeError)
    end

    it 'handles too many arguments' do
      expect { Object.new.hammertime_raise(RuntimeError, 'test', ['backtrace'], 'extra') }.to raise_error(ArgumentError)
    end
  end

  describe '#hammertime_ignore_error?' do
    let(:test_object) { Object.new }

    before do
      # Make the private method public for testing
      test_object.singleton_class.class_eval { public :hammertime_ignore_error? }
    end

    it 'returns true when stopped' do
      allow(Hammertime).to receive(:stopped).and_return(true)
      expect(test_object.hammertime_ignore_error?(RuntimeError.new, [])).to be true
    end

    it 'returns true when error type is ignored' do
      allow(Hammertime).to receive(:ignored_errors).and_return([RuntimeError])
      expect(test_object.hammertime_ignore_error?(RuntimeError.new, [])).to be true
    end

    it 'returns true when line is ignored' do
      allow(Hammertime).to receive(:ignored_lines).and_return(['test.rb:1'])
      expect(test_object.hammertime_ignore_error?(RuntimeError.new, ['test.rb:1'])).to be true
    end

    it 'returns false when error is not ignored' do
      allow(Hammertime).to receive(:stopped).and_return(false)
      allow(Hammertime).to receive(:ignored_errors).and_return([])
      allow(Hammertime).to receive(:ignored_lines).and_return([])
      expect(test_object.hammertime_ignore_error?(RuntimeError.new, ['test.rb:1'])).to be false
    end
  end

  describe 'interactive menu' do
    let(:console) { instance_double(HighLine) }
    let(:error) { RuntimeError.new('test error') }
    let(:backtrace) { ['test.rb:1'] }
    let(:test_object) { Object.new }

    before do
      allow(Hammertime).to receive(:hammertime_console).and_return(console)
      allow(console).to receive(:say)
      error.set_backtrace(backtrace)
    end

    context 'when choosing Continue' do
      let(:choice) { 'Continue' }

      it 'raises the original error' do
        allow(console).to receive(:choose) do |&block|
          with_menu_choice('Continue') do |menu|
            block.call(menu)
          end
        end

        expect { test_object.hammertime_raise(error) }.to raise_error(RuntimeError, 'test error')
      end
    end

    context 'when choosing Ignore' do
      let(:choice) { 'Ignore' }

      it 'proceeds without raising an exception' do
        allow(console).to receive(:choose) do |&block|
          with_menu_choice('Ignore') do |menu|
            block.call(menu)
          end
        end

        expect { test_object.hammertime_raise(error) }.not_to raise_error
      end
    end

    context 'when choosing Permit by type' do
      let(:choice) { 'Permit by type' }
      let(:original_errors) { Hammertime.ignored_errors.dup }

      before do
        expect(console).to receive(:say).with('Added RuntimeError to permitted error types')
      end

      after do
        Hammertime.ignored_errors.replace(original_errors)
      end

      xit 'adds error type to permitted errors' do
        allow(console).to receive(:choose) do |&block|
          # First, verify that RuntimeError is not in ignored_errors
          expect(Hammertime.ignored_errors).not_to include(RuntimeError)

          # Execute the menu choice
          with_menu_choice('Permit by type') do |menu|
            block.call(menu)
          end

          # Verify that RuntimeError was added to ignored_errors
          expect(Hammertime.ignored_errors).to include(RuntimeError)
        end

        # The error will still be raised, but that's expected
        expect { test_object.hammertime_raise(error) }.to raise_error(RuntimeError)
      end
    end

    context 'when choosing Permit by line' do
      let(:choice) { 'Permit by line' }
      let(:original_lines) { Hammertime.ignored_lines.dup }

      before do
        expect(console).to receive(:say).with('Added test.rb:1 to permitted error lines')
      end

      after do
        Hammertime.ignored_lines.replace(original_lines)
      end

      xit 'adds error line to permitted lines' do
        allow(console).to receive(:choose) do |&block|
          # First, verify that the line is not in ignored_lines
          expect(Hammertime.ignored_lines).not_to include(backtrace.first)

          # Configure and execute the menu choice
          with_menu_choice('Permit by line') do |menu|
            block.call(menu)
          end

          # Verify that the line was added to ignored_lines
          expect(Hammertime.ignored_lines).to include(backtrace.first)
        end

        # The error will still be raised, but that's expected
        expect { test_object.hammertime_raise(error) }.to raise_error(RuntimeError)
      end
    end

    context 'when choosing Backtrace' do
      let(:choice) { 'Backtrace' }

      xit 'shows the backtrace and continues' do
        # First call shows backtrace (returns false), second call continues (returns true)
        call_count = 0
        allow(console).to receive(:choose) do |&block|
          call_count += 1
          if call_count == 1
            expect(console).to receive(:say).with(backtrace.first)
            with_menu_choice('Backtrace') do |menu|
              block.call(menu)
            end
          else
            with_menu_choice('Continue') do |menu|
              block.call(menu)
            end
          end
        end

        expect { test_object.hammertime_raise(error) }.to raise_error(RuntimeError)
      end
    end

    context 'when choosing Debug' do
      let(:choice) { 'Debug' }

      before do
        allow(Hammertime).to receive(:debug_supported?).and_return(true)
        allow_any_instance_of(Binding).to receive(:break)
      end

      xit 'starts debugger and continues' do
        # First call starts debugger (returns false), second call continues (returns true)
        call_count = 0
        allow(console).to receive(:choose) do |&block|
          call_count += 1
          if call_count == 1
            with_menu_choice('Debug') do |menu|
              block.call(menu)
            end
          else
            with_menu_choice('Continue') do |menu|
              block.call(menu)
            end
          end
        end

        expect { test_object.hammertime_raise(error) }.to raise_error(RuntimeError)
      end
    end

    context 'when choosing Console' do
      let(:choice) { 'Console' }

      before do
        allow(IRB).to receive(:start)
      end

      xit 'starts IRB and continues' do
        # First call starts IRB (returns false), second call continues (returns true)
        call_count = 0
        allow(console).to receive(:choose) do |&block|
          call_count += 1
          if call_count == 1
            with_menu_choice('Console') do |menu|
              block.call(menu)
            end
          else
            with_menu_choice('Continue') do |menu|
              block.call(menu)
            end
          end
        end

        expect { test_object.hammertime_raise(error) }.to raise_error(RuntimeError)
      end
    end
  end

  describe '#exclusive_and_non_reentrant' do
    let(:mutex) { instance_double(Mutex) }

    before do
      allow(Hammertime).to receive(:mutex).and_return(mutex)
    end

    it 'executes block when lock is acquired' do
      allow(mutex).to receive(:try_lock).and_return(true)
      allow(mutex).to receive(:unlock)

      executed = false
      exclusive_and_non_reentrant(-> { raise 'should not execute' }) do
        executed = true
      end
      expect(executed).to be true
    end

    it 'executes fallback when lock is not acquired' do
      allow(mutex).to receive(:try_lock).and_return(false)

      executed = false
      exclusive_and_non_reentrant(-> { executed = true }) do
        raise 'should not execute'
      end
      expect(executed).to be true
    end
  end
end
