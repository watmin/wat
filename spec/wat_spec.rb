# frozen_string_literal: true

require 'pry'
require 'spec_helper'

RSpec.describe Wat do
  let(:wat) { Wat.new }

  it 'raises on unclosed parenthesis' do
    expect { wat.evaluate('(entity Noun "dog"') }.to raise_error('Unclosed parenthesis')
  end

  it 'ignores semicolon comments until newline' do
    input = <<~WAT
      (entity Noun "dog") ; this is a comment
      (entity Integer 5)
    WAT
    result = wat.evaluate(input)
    expect(result).to be_a(Wat::Entity)
    expect(result.type).to eq(:Integer)
    expect(result.value).to eq(5)
    expect(result.attrs).to eq({})
  end

  it 'handles semicolon within quotes correctly' do
    input = '(entity String "dog;cat") ; this is a comment'
    result = wat.evaluate(input)
    expect(result).to be_a(Wat::Entity)
    expect(result.type).to eq(:String)
    expect(result.value).to eq('dog;cat')
    expect(result.attrs).to eq({})
  end

  it 'handles single expression correctly' do
    input = '(entity Noun "dog")'
    result = wat.evaluate(input)
    expect(result).to be_a(Wat::Entity)
    expect(result.type).to eq(:Noun)
    expect(result.value).to eq('dog')
    expect(result.attrs).to eq({})
  end

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

    it 'creates an Integer entity' do
      input = '(entity Integer 5)'
      result = wat.evaluate(input)
      expect(result).to be_a(Wat::Entity)
      expect(result.type).to eq(:Integer)
      expect(result.value).to eq(5)
      expect(result.attrs).to eq({})
    end

    it 'supports Noun sugar' do
      input = '(entity Noun "dog")'
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
      expect(result.attrs).to eq({})
    end

    it 'creates a Verb entity' do
      result = wat.evaluate('(entity Verb "chases")')
      expect(result.type).to eq(:Verb)
      expect(result.value).to eq('chases')
    end

    it 'rejects single-quoted strings' do
      input = "(entity Noun 'dog')"
      expect { wat.evaluate(input) }.to raise_error('Single quotes not allowed; use double quotes')
    end

    it 'raises on unclosed parenthesis' do
      expect { wat.evaluate('(entity Noun "dog"') }.to raise_error('Unclosed parenthesis')
    end

    it 'raises on unclosed quote' do
      expect { wat.evaluate('(entity Noun "dog)') }.to raise_error('Unclosed quote')
    end

    it 'raises on unclosed parenthesis' do
      expect { wat.evaluate('(entity Noun "dog"') }.to raise_error('Unclosed parenthesis')
    end

    it 'errors on unpaired map keys in Subject sugar' do
      input = '(Subject "dog" :adjective)'
      result = wat.evaluate(input)
      expect(result).to be_a(Wat::Entity)
      expect(result.type).to eq(:Error)
      expect(result.value).to include('unpaired map key: :adjective')
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
      input = '(let ((x 5)) (add x 1))'
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
      expect(wat.env[:traits][:Noun]).to eq([:Numeric])
    end

    it 'defines a trait globally outside let' do
      wat.evaluate('(impl Relatable for Noun)')
      expect(wat.env[:traits][:Noun]).to include(:Relatable)
    end

    it 'allows multiple traits for the same type' do
      result = wat.evaluate('(let ((x be (impl Relatable for Noun)) (y be (impl Numeric for Noun))) y)')
      expect(result.type).to eq(:Boolean)
      expect(result.value).to eq(true)
      expect(wat.env[:traits][:Noun]).to be_nil
    end

    it 'prevents duplicate traits in same scope' do
      result = wat.evaluate('(let ((x be (impl Relatable for Noun)) (y be (impl Relatable for Noun))) y)')
      expect(result.type).to eq(:Boolean)
      expect(result.value).to eq(true)
      expect(wat.env[:traits][:Noun]).to be_nil
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

  describe 'lambda' do
    it 'creates a simple lambda and applies it' do
      input = '(let ((inc be (lambda ((x as Integer)) returns Integer (add x 1)))) (inc 5))'
      result = wat.evaluate(input)
      expect(result).to be_a(Wat::Entity)
      expect(result.type).to eq(:Integer)
      expect(result.value).to eq(6)
      expect(result.attrs).to eq({})
    end

    it 'captures lexical scope correctly' do
      input = <<~WAT
        (let ((y be (entity Integer 10))
              (add-y be (lambda ((x as Integer)) returns Integer (add x y))))
          (add-y 5))
      WAT
      result = wat.evaluate(input)
      expect(result.type).to eq(:Integer)
      expect(result.value).to eq(15)
    end

    it 'errors on argument count mismatch' do
      input = '(let ((f be (lambda ((x as Integer)) returns Integer (add x 1)))) (f 5 3))'
      result = wat.evaluate(input)
      expect(result.type).to eq(:Error)
      expect(result.value).to include('argument count mismatch')
    end

    it 'errors on argument type mismatch' do
      input = '(let ((f be (lambda ((x as Integer)) returns Integer (add x 1)))) (f (entity Noun "dog")))'
      result = wat.evaluate(input)
      expect(result.type).to eq(:Error)
      expect(result.value).to include('type mismatch')
    end

    it 'errors on return type mismatch' do
      input = '(let ((f be (lambda ((x as Integer)) returns Boolean (add x 1)))) (f 5))'
      result = wat.evaluate(input)
      expect(result.type).to eq(:Error)
      expect(result.value).to include('return type mismatch')
    end

    it 'errors on invalid syntax' do
      input = '(lambda (x as Integer) returns Integer (add x 1))'
      result = wat.evaluate(input)
      expect(result.type).to eq(:Error)
      expect(result.value).to include('invalid lambda syntax')
    end

    it 'handles empty parameter list' do
      input = <<~WAT
        (let ((f be (lambda () returns Integer 42)))
          (f))
      WAT
      result = wat.evaluate(input)
      expect(result.type).to eq(:Integer)
      expect(result.value).to eq(42)
    end

    it 'handles multiple parameters' do
      input = <<~WAT
        (let ((add-xy be (lambda ((x as Integer) (y as Integer)) returns Integer (add x y))))
          (add-xy 3 4))
      WAT
      result = wat.evaluate(input)
      expect(result.type).to eq(:Integer)
      expect(result.value).to eq(7)
    end

    it 'errors on missing body' do
      input = '(lambda ((x as Integer)) returns Integer)'
      result = wat.evaluate(input)
      expect(result.type).to eq(:Error)
      expect(result.value).to include('invalid lambda syntax')
    end

    it 'errors on extra args after body' do
      input = '(lambda ((x as Integer)) returns Integer (add x 1) junk)'
      result = wat.evaluate(input)
      expect(result.type).to eq(:Error)
      expect(result.value).to include('invalid lambda syntax')
    end

    it 'handles mixed argument types' do
      input = <<~WAT
        (let ((add-float be (lambda ((x as Integer) (y as Float)) returns Float (add x y))))
          (add-float 3 2.5))
      WAT
      result = wat.evaluate(input)
      expect(result.type).to eq(:Float)
      expect(result.value).to eq(5.5)
    end

    it 'errors on non-coercible argument' do
      input = <<~WAT
        (let ((f be (lambda ((x as Integer)) returns Integer x)))
          (f "string"))
      WAT
      result = wat.evaluate(input)
      expect(result.type).to eq(:Error)
      expect(result.value).to include('type mismatch')
    end

    it 'handles nested entity argument' do
      input = <<~WAT
        (let ((f be (lambda ((x as Integer)) returns Integer x)))
          (f (entity Integer 5)))
      WAT
      result = wat.evaluate(input)
      expect(result.type).to eq(:Integer)
      expect(result.value).to eq(5)
    end

    it 'captures outer scope in nested let' do
      input = <<~WAT
        (let ((x be (entity Integer 1)))
          (let ((f be (lambda () returns Integer x)))
            (f)))
      WAT
      result = wat.evaluate(input)
      expect(result.type).to eq(:Integer)
      expect(result.value).to eq(1)
    end

    it 'respects parameter shadowing over outer scope' do
      input = <<~WAT
        (let ((x be (entity Integer 1))
              (f be (lambda ((x as Integer)) returns Integer x)))
          (f 5))
      WAT
      result = wat.evaluate(input)
      expect(result.type).to eq(:Integer)
      expect(result.value).to eq(5)
    end

    it 'errors on unbound variable in body' do
      input = <<~WAT
        (let ((f be (lambda ((x as Integer)) returns Integer (add x y))))
          (f 5))
      WAT
      result = wat.evaluate(input)
      expect(result.type).to eq(:Error)
      expect(result.value).to include('Unbound variable: y')
    end

    it 'errors on extra arguments with no-param lambda' do
      input = <<~WAT
        (let ((f be (lambda () returns Integer 42)))
          (f 5))
      WAT
      result = wat.evaluate(input)
      expect(result.type).to eq(:Error)
      expect(result.value).to include('argument count mismatch')
    end

    it 'errors on partial parameter spec' do
      input = '(lambda ((x as Integer) (y)) returns Integer (add x y))'
      result = wat.evaluate(input)
      expect(result.type).to eq(:Error)
      expect(result.value).to include('invalid lambda syntax')
    end

    it 'errors on duplicate parameter names' do
      input = '(lambda ((x as Integer) (x as Integer)) returns Integer (add x x))'
      result = wat.evaluate(input)
      expect(result.type).to eq(:Error)
      expect(result.value).to include('invalid lambda syntax')
    end

    it 'handles non-coercible type with entity argument' do
      input = <<~WAT
        (let ((f be (lambda ((x as Noun)) returns Noun x)))
          (f (entity Noun "dog")))
      WAT
      result = wat.evaluate(input)
      expect(result.type).to eq(:Noun)
      expect(result.value).to eq('dog')
    end

    it 'coerces integer to float argument' do
      input = <<~WAT
        (let ((f be (lambda ((x as Float)) returns Float (add x 1))))
          (f 5))
      WAT
      result = wat.evaluate(input)
      expect(result.type).to eq(:Float)
      expect(result.value).to eq(6.0)
    end

    it 'preserves outer scope across nested let' do
      input = <<~WAT
        (let ((x be (entity Integer 1)))
          (let ((f be (lambda () returns Integer x)))
            (let ((x be (entity Integer 2)))
              (f))))
      WAT
      result = wat.evaluate(input)
      expect(result.type).to eq(:Integer)
      expect(result.value).to eq(1)
    end

    it 'handles lambda returning lambda' do
      input = <<~WAT
        (let ((f be (lambda () returns Lambda  ; Change return type
                      (lambda ((x as Integer)) returns Integer (add x 1)))))
          ((f) 5))
      WAT
      result = wat.evaluate(input)
      expect(result.type).to eq(:Integer)
      expect(result.value).to eq(6)
    end

    it 'errors on self-reference without binding' do
      input = '(lambda ((x as Integer)) returns Integer (self x))'
      result = wat.evaluate(input)
      expect(result.type).to eq(:Error)
      expect(result.value).to include('invalid lambda syntax')
    end

    it 'handles nested unbound variables' do
      input = <<~WAT
        (let ((f be (lambda ((x as Integer)) returns Integer (add x (add y z)))))
          (f 5))
      WAT
      result = wat.evaluate(input)
      expect(result.type).to eq(:Error)
      expect(result.value).to include('Unbound variable: y')
    end

    it 'errors on nested malformed parameters' do
      input = '(lambda (((x as Integer))) returns Integer x)'
      result = wat.evaluate(input)
      expect(result.type).to eq(:Error)
      expect(result.value).to include('invalid lambda syntax')
    end

    it 'errors on case-sensitive returns keyword' do
      input = '(lambda ((x as Integer)) Returns Integer x)'
      result = wat.evaluate(input)
      expect(result.type).to eq(:Error)
      expect(result.value).to include('expected \'returns\'')
    end

    it 'handles ambiguous coercion with integer for float' do
      input = <<~WAT
        (let ((f be (lambda ((x as Float)) returns Float x)))
          (f 5))
      WAT
      result = wat.evaluate(input)
      expect(result.type).to eq(:Float)
      expect(result.value).to eq(5.0)
    end

    it 'errors on nil argument' do
      input = <<~WAT
        (let ((f be (lambda ((x as Integer)) returns Integer x)))
          (f nil))
      WAT
      result = wat.evaluate(input)
      expect(result.type).to eq(:Error)
      expect(result.value).to include('nil argument not allowed')
    end

    it 'preserves outer scope over inner binding' do
      input = <<~WAT
        (let ((f be (lambda () returns Integer x))
              (x be (entity Integer 1)))
          (let ((x be (entity Integer 2)))
            (f)))
      WAT
      result = wat.evaluate(input)
      expect(result.type).to eq(:Integer)
      expect(result.value).to eq(1)
    end

    it 'handles deeply nested lambdas' do
      input = <<~WAT
        (let ((f be (lambda () returns Lambda
                      (lambda () returns Lambda
                        (lambda ((x as Integer)) returns Integer (add x 1))))))
          (((f)) 5))
      WAT
      result = wat.evaluate(input)
      expect(result.type).to eq(:Integer)
      expect(result.value).to eq(6)
    end

    it 'handles chained applications' do
      input = <<~WAT
        (let ((f be (lambda ((x as Integer)) returns Lambda
                      (lambda ((y as Integer)) returns Integer (add x y)))))
          ((f 3) 4))
      WAT
      result = wat.evaluate(input)
      expect(result.type).to eq(:Integer)
      expect(result.value).to eq(7)
    end

    it 'handles lambda as argument' do
      input = <<~WAT
        (let ((g be (lambda ((h as Lambda)) returns Integer (h 5)))
              (id be (lambda ((x as Integer)) returns Integer x)))
          (g id))
      WAT
      result = wat.evaluate(input)
      expect(result.type).to eq(:Integer)
      expect(result.value).to eq(5)
    end

    it 'errors gracefully on recursive application' do
      input = <<~WAT
        (let ((f be (lambda ((x as Integer)) returns Integer (f (add x -1)))))
          (f 5))
      WAT
      result = wat.evaluate(input)
      expect(result.type).to eq(:Error)
      expect(result.value).to include('Unbound variable: f')
    end

    it 'handles nested errors in body' do
      input = <<~WAT
        (let ((f be (lambda () returns Integer (add (add x y) z))))
          (f))
      WAT
      result = wat.evaluate(input)
      expect(result.type).to eq(:Error)
      expect(result.value).to include('Unbound variable: x')
    end
  end
end
