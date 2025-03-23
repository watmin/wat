# frozen_string_literal: true

def reload
  load(File.join(__dir__, 'wat.rb'))
end

require_relative 'wat/version'

module Wat # rubocop:disable Metrics/ModuleLength
  Entity = Struct.new(:type, :value, :attrs)

  VALID_TYPES = %i[Noun Verb Time Adverb String Integer Float Boolean
                   Pronoun Preposition Adjective Error].freeze
  VALID_FUNCTIONS = %i[entity list add let].freeze
  LISTABLE_TYPES = %i[Noun Time Verb Integer Float].freeze
  NUMERIC_TYPES = %i[Integer Float].freeze

  def self.evaluate(input)
    sexp = if input.is_a?(String)
             parse(tokenize(input))
           else
             input
           end
    case sexp[0]
    when :entity then evaluate_entity(sexp)
    when :list then evaluate_list(sexp)
    when :add then evaluate_add(sexp)
    when :let then evaluate_let(sexp, {})
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
        nested = parse(tokens)
        result << if nested.length == 2 && VALID_TYPES.include?(nested[0])
                    [:entity, nested[0], nested[1]]
                  else
                    nested
                  end
      else
        token = tokens.shift
        result << case token
                  when /^"/ then token[1..].delete_suffix('"')
                  when /^\d+\.\d+$/ then token.to_f
                  when /^\d+$/ then token.to_i
                  when /^:/ then token[1..].to_sym
                  when /^'/ then raise 'Single quotes not allowed; use double quotes'
                  else token.to_sym
                  end
      end
    end

    raise 'Unclosed parenthesis' if tokens.empty?

    tokens.shift # Remove ")"

    if VALID_FUNCTIONS.include?(result[0]) && result[0] != :entity
      result[1..] = result[1..].map do |elem|
        case elem
        when Integer then [:entity, :Integer, elem]
        when Float then [:entity, :Float, elem]
        else elem
        end
      end
    end

    if result[0] == :entity && result.length > 3 && !result[3].is_a?(Array)
      map_pairs = result[3..].each_slice(2).to_a
      result = result[0..2] + [[:map] + map_pairs.flatten]
    end
    result
  end

  def self.evaluate_entity(sexp) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
    raise "Expected 'entity'" unless sexp[0] == :entity

    type = sexp[1]
    value = sexp[2]
    map_expr = sexp[3] || [:map]

    return Entity.new(:Error, "invalid type: #{type}", {}) unless VALID_TYPES.include?(type)

    case type
    when :Noun, :Verb, :Time, :Adverb, :String, :Pronoun, :Preposition, :Adjective, :Error
      return Entity.new(:Error, "expected string for #{type}, got #{value}", {}) unless value.is_a?(String)
    when :Integer
      return Entity.new(:Error, "expected integer for Integer, got #{value}", {}) unless value.is_a?(Integer)
    when :Float
      return Entity.new(:Error, "expected float for Float, got #{value}", {}) unless value.is_a?(Float)
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

  def self.evaluate_let(sexp, env) # rubocop:disable Metrics/AbcSize
    raise "Expected 'let'" unless sexp[0] == :let

    bindings = sexp[1]  # Array of [label, :be, value]
    body = sexp[2..]    # Array of expressions

    new_env = env.dup
    bindings.each do |binding|
      raise "Invalid binding: #{binding}" unless binding[1] == :be && binding.length == 3

      label = binding[0]
      value = eval_expr(binding[2], new_env)
      new_env[label] = value
    end

    body.map { |expr| eval_expr(expr, new_env) }.last
  end

  def self.eval_expr(expr, env) # rubocop:disable Metrics/CyclomaticComplexity
    if expr.is_a?(Symbol) && env.key?(expr)
      env[expr]
    elsif expr.is_a?(Entity)
      expr  # Already evaluated, pass through
    elsif expr.is_a?(Array)
      case expr[0]
      when :entity then evaluate_entity(expr)
      when :list then evaluate_list(expr)
      when :add then evaluate_add(expr, env)
      when :let then evaluate_let(expr, env)
      else raise "Unknown function: #{expr[0]}"
      end
    else
      expr  # Literals like numbers or strings
    end
  end

  def self.evaluate_add(sexp, env = {}) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
    raise "Expected 'add'" unless sexp[0] == :add

    args = sexp[1..].map { |sub_sexp| eval_expr(sub_sexp, env) }
    args.each do |arg|
      unless arg.is_a?(Entity) && NUMERIC_TYPES.include?(arg.type)
        return Entity.new(:Error, "expected Numeric argument, got #{arg}", {})
      end
    end
    sum = args.map(&:value).reduce(:+)
    type = args.any? { |arg| arg.type == :Float } ? :Float : :Integer
    Entity.new(type, sum, {})
  end
end
