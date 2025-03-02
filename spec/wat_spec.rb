# frozen_string_literal: true

require 'pry'
require "spec_helper"

RSpec.describe Wat do
  let(:wat) { Wat.new }

  describe "#eval" do
    context "with basic arithmetic" do
      it "evaluates (add 1 2) to 3" do
        expect(wat.eval("(add 1 2)")).to eq(3)
      end

      it "evaluates (sub 5 3) to 2" do
        expect(wat.eval("(sub 5 3)")).to eq(2)
      end

      it "evaluates (mul 4 3) to 12" do
        expect(wat.eval("(mul 4 3)")).to eq(12)
      end

      it "evaluates (eq 3 3) to true" do
        expect(wat.eval("(eq 3 3)")).to eq(true)
      end

      it "evaluates (eq 3 4) to false" do
        expect(wat.eval("(eq 3 4)")).to eq(false)
      end
    end

    context "with nested arithmetic" do
      it "evaluates (add (add 1 2) 3) to 6" do
        expect(wat.eval("(add (add 1 2) 3)")).to eq(6)
      end

      it "evaluates (mul (sub 5 2) 3) to 9" do
        expect(wat.eval("(mul (sub 5 2) 3)")).to eq(9)
      end
    end

    context "with user-defined functions" do
      it "defines and evaluates (defn foo [x : Int] [y : Int] : Int (add x y))" do
        program = "(defn foo [x : Int] [y : Int] : Int (add x y)) (foo 2 3)"
        expect(wat.eval(program)).to eq(5)
      end

      it "handles nested calls with defn" do
        program = "(defn foo [x : Int] [y : Int] : Int (add x y)) (foo (foo 1 2) 3)"
        expect(wat.eval(program)).to eq(6)
      end

      it "raises type error for mismatched return type" do
        program = "(defn foo [x : Int] [y : Int] : Bool (add x y))"
        expect { wat.eval(program) }.to raise_error("Type error: expected :bool, got :int in foo")
      end
    end

    context "with type errors" do
      it "raises an error when eq compares non-integers" do
        pending "Non-integer types not yet supported"
        expect { wat.eval("(eq 1 foo)") }.to raise_error("Type error: expected :int, got ??? in eq")
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
