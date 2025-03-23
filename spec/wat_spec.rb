# frozen_string_literal: true

require 'pry'
require 'spec_helper'

RSpec.describe Wat do
  describe 'entity' do
    it 'creates a basic Noun entity' do
      input = '(entity Noun "dog")'
      result = Wat.evaluate(input)
      expect(result).to be_a(Wat::Entity)
      expect(result.type).to eq(:Noun)
      expect(result.value).to eq('dog')
      expect(result.attrs).to eq({})
    end

    it 'returns an Error entity for invalid value type' do
      input = '(entity Noun 5)'
      result = Wat.evaluate(input)
      expect(result).to be_a(Wat::Entity)
      expect(result.type).to eq(:Error)
      expect(result.value).to include('expected string')
      expect(result.attrs).to eq({})
    end

    it 'creates a Noun entity with role attribute' do
      input = '(entity Noun "dog" :role Subject)'
      result = Wat.evaluate(input)
      expect(result).to be_a(Wat::Entity)
      expect(result.type).to eq(:Noun)
      expect(result.value).to eq('dog')
      expect(result.attrs).to eq({ role: :Subject })
    end

    it 'rejects single-quoted strings' do
      input = "(entity Noun 'dog')"
      expect { Wat.evaluate(input) }.to raise_error('Single quotes not allowed; use double quotes')
    end

    it 'creates an Integer entity' do
      input = '(entity Integer 5)'
      result = Wat.evaluate(input)
      expect(result).to be_a(Wat::Entity)
      expect(result.type).to eq(:Integer)
      expect(result.value).to eq(5)
      expect(result.attrs).to eq({})
    end
  end

  describe 'list' do
    it 'creates a list of Integer entities' do
      input = '(list (entity Integer 1) (entity Integer 2))'
      result = Wat.evaluate(input)
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
      result = Wat.evaluate(input)
      expect(result).to be_a(Wat::Entity)
      expect(result.type).to eq(:Error)
      expect(result.value).to include('not Listable')
    end
  end
end
