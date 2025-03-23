# frozen_string_literal: true

def reload
  load(File.join(__dir__, 'wat.rb'))
end

require_relative 'wat/version'

module Wat
  Entity = Struct.new(:type, :value, :attrs)

  VALID_TYPES = %i[Noun Verb Time Adverb String Integer Float Boolean
                   Pronoun Preposition Adjective Error].freeze

  def self.evaluate(input)
    sexp = parse(tokenize(input))
    evaluate_entity(sexp)
  end

  def self.tokenize(input) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
    tokens = []
    buffer = String.new
    in_quotes = false

    input.chars.each do |char|
      if char == '"'
        in_quotes = !in_quotes
        buffer << char
      elsif in_quotes
        buffer << char
      elsif char =~ /\s/ && buffer != ''
        tokens << buffer
        buffer = String.new
      elsif %w[( )].include?(char)
        tokens << buffer if buffer != ''
        tokens << char
        buffer = String.new
      else
        buffer << char
      end
    end
    tokens << buffer if buffer != ''
    tokens
  end

  def self.parse(tokens) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
    raise "Expected '('" unless tokens[0] == '('

    result = []
    tokens.shift # Remove "("
    until tokens.empty? || tokens[0] == ')'
      token = tokens.shift
      result << case token
                when /^"/ then token[1..].delete_suffix('"')
                when /^\d+$/ then token.to_i
                when /^:/ then token[1..].to_sym
                when /^'/ then raise 'Single quotes not allowed; use double quotes'
                else token.to_sym # Symbolize function and type names
                end
    end

    raise 'Unclosed parenthesis' if tokens.empty?

    tokens.shift # Remove ")"

    if result[0] == :entity && result.length > 3
      map_pairs = result[3..].each_slice(2).to_a
      result = result[0..2] + [[:map] + map_pairs.flatten]
    end

    result
  end

  def self.evaluate_entity(sexp) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity
    raise "Expected 'entity'" unless sexp[0] == :entity

    type, value = sexp[1..2]
    map_expr = sexp[3] || [:map]
    return Entity.new(:Error, "invalid type: #{type}", {}) unless VALID_TYPES.include?(type)

    case type
    when :Noun
      return Entity.new(:Error, "expected string for Noun, got #{value}", {}) unless value.is_a?(String)
    end

    attrs = {}
    if map_expr[0] == :map
      map_expr[1..].each_slice(2) do |key, val|
        attrs[key] = val
      end
    end
    Entity.new(type, value, attrs)
  end
end
