# frozen_string_literal: true

require 'pry'
require 'spec_helper'

RSpec.describe Wat do
  let(:wat) { Wat.new }

  describe 'entity' do
    it 'creates a basic Noun entity' do
      input = '(entity Noun "dog")'
      result = wat.evaluate(input)
      expect(result).to be_a(Wat::Entity)
      expect(result.type).to eq(:Noun)
      expect(result.value).to eq('dog')
      expect(result.attrs).to eq({})
    end

    it 'returns an Error entity for invalid value type' do
      input = '(entity Noun 5)'
      result = wat.evaluate(input)
      expect(result).to be_a(Wat::Entity)
      expect(result.type).to eq(:Error)
      expect(result.value).to include('expected string')
      expect(result.attrs).to eq({})
    end

    it 'creates a Noun entity with role attribute' do
      input = '(entity Noun "dog" :role Subject)'
      result = wat.evaluate(input)
      expect(result).to be_a(Wat::Entity)
      expect(result.type).to eq(:Noun)
      expect(result.value).to eq('dog')
      expect(result.attrs).to eq({ role: :Subject })
    end

    it 'rejects single-quoted strings' do
      input = "(entity Noun 'dog')"
      expect { wat.evaluate(input) }.to raise_error('Single quotes not allowed; use double quotes')
    end

    it 'creates an Integer entity' do
      input = '(entity Integer 5)'
      result = wat.evaluate(input)
      expect(result).to be_a(Wat::Entity)
      expect(result.type).to eq(:Integer)
      expect(result.value).to eq(5)
      expect(result.attrs).to eq({})
    end

    it 'supports Noun sugar' do
      input = '(entity Noun "dog")' # Could test (Noun "dog") if we extend sugar
      result = wat.evaluate(input)
      expect(result.type).to eq(:Noun)
      expect(result.value).to eq('dog')
    end

    it 'creates a Boolean entity with true' do
      input = '(entity Boolean true)'
      result = wat.evaluate(input)
      expect(result).to be_a(Wat::Entity)
      expect(result.type).to eq(:Boolean)
      expect(result.value).to eq(true)
      expect(result.attrs).to eq({})
    end

    it 'returns an Error for invalid Boolean value' do
      input = '(entity Boolean "dog")'
      result = wat.evaluate(input)
      expect(result.type).to eq(:Error)
      expect(result.value).to include('expected boolean')
    end

    it 'supports Noun sugar' do
      input = '(Noun "dog")'
      result = wat.evaluate(input)
      expect(result.type).to eq(:Noun)
      expect(result.value).to eq('dog')
      expect(result.attrs).to eq({})
    end

    it 'supports Subject sugar with adjective' do
      input = '(Subject "dog" :adjective (Adjective "big"))'
      result = wat.evaluate(input)
      expect(result.type).to eq(:Noun)
      expect(result.value).to eq('dog')
      expect(result.attrs[:role]).to eq(:Subject)
      expect(result.attrs[:adjective]).to be_a(Wat::Entity)
      expect(result.attrs[:adjective].type).to eq(:Adjective)
      expect(result.attrs[:adjective].value).to eq('big')
    end

    it 'evaluates raw sexp input' do
      result = wat.evaluate([:entity, :Noun, 'dog', [:map]])
      expect(result.type).to eq(:Noun)
      expect(result.value).to eq('dog')
    end

    it 'raises on unclosed parenthesis' do
      expect { wat.evaluate('(entity Noun "dog"') }.to raise_error('Unclosed parenthesis')
    end

    it 'creates a Verb entity' do
      result = wat.evaluate('(entity Verb "chases")')
      expect(result.type).to eq(:Verb)
      expect(result.value).to eq('chases')
    end
  end

  describe 'list' do
    it 'creates a list of Integer entities' do
      input = '(list (entity Integer 1) (entity Integer 2))'
      result = wat.evaluate(input)
      expect(result).to be_an(Array)
      expect(result.length).to eq(2)
      expect(result[0]).to be_a(Wat::Entity)
      expect(result[0].type).to eq(:Integer)
      expect(result[0].value).to eq(1)
      expect(result[0].attrs).to eq({})
      expect(result[1]).to be_a(Wat::Entity)
      expect(result[1].type).to eq(:Integer)
      expect(result[1].value).to eq(2)
      expect(result[1].attrs).to eq({})
    end

    it 'rejects non-Listable elements' do
      input = '(list (entity Noun "dog") (list (entity Integer 1)))'
      result = wat.evaluate(input)
      expect(result).to be_a(Wat::Entity)
      expect(result.type).to eq(:Error)
      expect(result.value).to include('not Listable')
    end

    it 'returns empty array for no elements' do
      input = '(list)'
      result = wat.evaluate(input)
      expect(result).to be_an(Array)
      expect(result).to be_empty
    end

    it 'returns empty array for no elements' do
      input = '(list)'
      result = wat.evaluate(input)
      expect(result).to be_an(Array)
      expect(result).to be_empty
    end
  end

  describe 'add' do
    it 'adds two Integer entities' do
      input = '(add (entity Integer 3) (entity Integer 2))'
      result = wat.evaluate(input)
      expect(result).to be_a(Wat::Entity)
      expect(result.type).to eq(:Integer)
      expect(result.value).to eq(5)
      expect(result.attrs).to eq({})
    end

    it 'adds a Float and an Integer entity, promoting to Float' do
      input = '(add (entity Float 2.5) (entity Integer 3))'
      result = wat.evaluate(input)
      expect(result).to be_a(Wat::Entity)
      expect(result.type).to eq(:Float)
      expect(result.value).to eq(5.5)
      expect(result.attrs).to eq({})
    end

    it 'rejects non-Numeric arguments' do
      input = '(add (entity Noun "dog") 2)'
      result = wat.evaluate(input)
      expect(result).to be_a(Wat::Entity)
      expect(result.type).to eq(:Error)
      expect(result.value).to include('expected Numeric')
    end

    it 'adds multiple Integer arguments' do
      input = '(add 1 2 3)'
      result = wat.evaluate(input)
      expect(result).to be_a(Wat::Entity)
      expect(result.type).to eq(:Integer)
      expect(result.value).to eq(6)
      expect(result.attrs).to eq({})
    end

    it 'errors on insufficient arguments' do
      input = '(add)'
      result = wat.evaluate(input)
      expect(result).to be_a(Wat::Entity)
      expect(result.type).to eq(:Error)
      expect(result.value).to include('insufficient arguments')
    end
  end

  describe 'let' do
    it 'binds a variable and evaluates an expression' do
      input = '(let ((x be (entity Integer 5))) (add x 3))'
      result = wat.evaluate(input)
      expect(result).to be_a(Wat::Entity)
      expect(result.type).to eq(:Integer)
      expect(result.value).to eq(8)
      expect(result.attrs).to eq({})
    end

    it 'binds multiple variables and evaluates an expression' do
      input = '(let ((x be (entity Integer 5)) (y be (entity Integer 3))) (add x y))'
      result = wat.evaluate(input)
      expect(result).to be_a(Wat::Entity)
      expect(result.type).to eq(:Integer)
      expect(result.value).to eq(8)
      expect(result.attrs).to eq({})
    end

    it 'evaluates multiple body expressions, returning the last' do
      input = '(let ((x be (entity Integer 5))) (add x 1) (add x 2))'
      result = wat.evaluate(input)
      expect(result).to be_a(Wat::Entity)
      expect(result.type).to eq(:Integer)
      expect(result.value).to eq(7)
      expect(result.attrs).to eq({})
    end

    it 'binds multiple variables and evaluates an expression with sugar' do
      input = '(let ((x be (entity Integer 5)) (y be (Integer 3))) (add x y))'
      result = wat.evaluate(input)
      expect(result).to be_a(Wat::Entity)
      expect(result.type).to eq(:Integer)
      expect(result.value).to eq(8)
      expect(result.attrs).to eq({})
    end

    it 'errors on unbound variables' do
      input = '(let () (add x 1))'
      expect { wat.evaluate(input) }.to raise_error(/Unbound variable: x/)
    end

    it 'errors on invalid binding syntax' do
      input = '(let ((x 5)) (add x 1))' # Missing 'be'
      result = wat.evaluate(input)
      expect(result.type).to eq(:Error)
      expect(result.value).to match(/invalid binding/)
    end

    it 'returns nil for empty body' do
      input = '(let ((x be (entity Integer 5))))'
      result = wat.evaluate(input)
      expect(result).to be_nil
    end
  end

  describe 'impl' do
    it 'defines a trait locally in a let scope' do
      result = wat.evaluate('(let ((x be (impl Relatable for Noun))) x)')
      expect(result.type).to eq(:Boolean)
      expect(result.value).to eq(true)
    end

    it 'isolates traits to let scope' do
      wat.evaluate('(impl Numeric for Noun)')
      inner_result = wat.evaluate('(let ((x be (impl Relatable for Noun))) x)')
      expect(inner_result.type).to eq(:Boolean)
      expect(inner_result.value).to eq(true)
      expect(wat.env[:traits][:Noun]).to eq([:Numeric]) # No Relatable leakage
    end

    it 'defines a trait globally outside let' do
      wat.evaluate('(impl Relatable for Noun)')
      expect(wat.env[:traits][:Noun]).to include(:Relatable)
    end

    it 'allows multiple traits for the same type' do
      result = wat.evaluate('(let ((x be (impl Relatable for Noun)) (y be (impl Numeric for Noun))) y)')
      expect(result.type).to eq(:Boolean)
      expect(result.value).to eq(true)
      expect(wat.env[:traits][:Noun]).to be_nil # Local scope—global env unchanged
    end

    it 'prevents duplicate traits in same scope' do
      result = wat.evaluate('(let ((x be (impl Relatable for Noun)) (y be (impl Relatable for Noun))) y)')
      expect(result.type).to eq(:Boolean)
      expect(result.value).to eq(true)
      expect(wat.env[:traits][:Noun]).to be_nil # Local scope—global env unchanged
    end

    it 'errors on invalid trait' do
      result = wat.evaluate('(impl Foo for Noun)')
      expect(result.type).to eq(:Error)
      expect(result.value).to include('invalid trait: Foo')
    end

    it 'errors on invalid type' do
      result = wat.evaluate('(impl Relatable for Foo)')
      expect(result.type).to eq(:Error)
      expect(result.value).to include('invalid type: Foo')
    end

    it 'errors on invalid syntax' do
      result = wat.evaluate('(impl Relatable Noun)')
      expect(result.type).to eq(:Error)
      expect(result.value).to eq('invalid impl syntax: expected (impl Trait for Type)')
    end
  end
end
