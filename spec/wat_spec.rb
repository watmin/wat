# frozen_string_literal: true

require "spec_helper"

RSpec.describe Wat do
  let(:wat) { Wat.new }

  describe "#eval" do
    context "with basic addition" do
      it "evaluates (add 1 2) to 3" do
        expect(wat.eval("(add 1 2)")).to eq(3)
      end
    end

    context "with nested addition" do
      it "evaluates (add (add 1 2) 3) to 6" do
        expect(wat.eval("(add (add 1 2) 3)")).to eq(6)
      end
    end

    context "with invalid syntax" do
      it "raises an error for unclosed parentheses" do
        expect { wat.eval("(add 1") }.to raise_error(RuntimeError)
      end
    end

    context "with unknown functions" do
      it "raises an error for undefined functions" do
        expect { wat.eval("(foo 1 2)") }.to raise_error(RuntimeError, "Unknown function: foo")
      end
    end

    context "with invalid syntax" do
      it "raises an error for unclosed parentheses" do
        expect { wat.eval("(add 1") }.to raise_error("Syntax error: unclosed parenthesis")
      end
    end
  end
end
