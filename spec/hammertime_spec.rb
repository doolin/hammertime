require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

RSpec.describe Hammertime do
  describe ".ignored_errors" do
    it "defaults to including LoadError" do
      expect(Hammertime.ignored_errors).to include(LoadError)
    end
  end

  describe ".ignored_lines" do
    it "defaults to an empty array" do
      expect(Hammertime.ignored_lines).to be_empty
    end
  end

  describe ".stopped" do
    it "defaults to false" do
      expect(Hammertime.stopped).to be false
    end
  end

  describe ".debug_supported?" do
    it "returns true when debug gem is available" do
      expect(Hammertime.debug_supported?).to be true
    end
  end

  describe "#hammertime_raise" do
    it "raises the original error when ignored" do
      error = RuntimeError.new("test error")
      allow(Hammertime).to receive(:ignored_errors).and_return([RuntimeError])
      expect { hammertime_raise(error) }.to raise_error(RuntimeError, "test error")
    end
  end
end
