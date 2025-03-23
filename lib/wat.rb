# frozen_string_literal: true

def reload
  load(File.join(__dir__, 'wat.rb'))
end

require_relative 'wat/version'

module Wat
  Entity = Struct.new(:type, :value, :attrs)

  VALID_TYPES = %i[Noun Verb Time Adverb String Integer Float Boolean
                   Pronoun Preposition Adjective Error].freeze
  VALID_FUNCTIONS = %i[entity list].freeze
  LISTABLE_TYPES = %i[Noun Time Verb Integer Float].freeze

  def self.evaluate(input)
    sexp = if input.is_a?(String)
             parse(tokenize(input))
           else
             input
           end
    case sexp[0]
    when :entity then evaluate_entity(sexp)
    when :list then evaluate_list(sexp)
    else raise "Unknown function: #{sexp[0]}"
    end
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
      elsif char =~ /\s/
        if buffer != ''
          tokens << buffer
          buffer = String.new
        end
        # Skip standalone whitespace
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

  def self.parse(tokens) # rubocop:disable Metrics/MethodLength,Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
    raise "Expected '('" unless tokens[0] == '('

    result = []
    tokens.shift # Remove "("
    until tokens.empty? || tokens[0] == ')'
      if tokens[0] == '('
        result << parse(tokens) # Recursively parse nested s-expression
      else
        token = tokens.shift
        result << case token
                  when /^"/ then token[1..].delete_suffix('"')
                  when /^\d+$/ then token.to_i
                  when /^:/ then token[1..].to_sym
                  when /^'/ then raise 'Single quotes not allowed; use double quotes'
                  else token.to_sym
                  end
      end
    end

    raise 'Unclosed parenthesis' if tokens.empty?

    tokens.shift # Remove ")"

    if result[0] == :entity && result.length > 3 && !result[3].is_a?(Array)
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

  def self.evaluate_list(sexp)
    raise "Expected 'list'" unless sexp[0] == :list

    sexp[1..].map do |sub_sexp|
      result = evaluate(sub_sexp)
      unless result.is_a?(Entity) && LISTABLE_TYPES.include?(result.type)
        return Entity.new(:Error, "expression not Listable: #{sub_sexp}", {})
      end

      result
    end
  end
end
