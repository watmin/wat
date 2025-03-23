# frozen_string_literal: true

def reload
  load(File.join(__dir__, 'wat.rb'))
end

require_relative 'wat/version'

module Wat # rubocop:disable Metrics/ModuleLength
  Entity = Struct.new(:type, :value, :attrs)

  VALID_TYPES = %i[Noun Verb Time Adverb String Integer Float Boolean
                   Pronoun Preposition Adjective Error].freeze
  SUGAR_TYPES = %i[Noun Verb Time Adverb Pronoun Preposition Adjective
                   Subject Object Integer Float Boolean].freeze
  VALID_FUNCTIONS = %i[entity list add let impl Noun Verb Time Adverb
                       Pronoun Preposition Adjective Subject Object
                       Integer Float Boolean].freeze
  LISTABLE_TYPES = %i[Noun Time Verb Integer Float].freeze
  NUMERIC_TYPES = %i[Integer Float].freeze
  VALID_TRAITS = %i[Relatable RelatableVerb Adverbial Timeable
                    StringValued Numeric Assertable Listable Mappable Describable].freeze

  def self.evaluate(input) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
    sexp = if input.is_a?(String)
             parse(tokenize(input))
           else
             input
           end
    if SUGAR_TYPES.include?(sexp[0])
      type = sexp[0]
      value = sexp[1]
      if %i[Subject Object].include?(type)
        role = type
        type = :Noun
        attrs = [:map, :role, role]
        sexp[2..].each_slice(2) { |k, v| attrs << k << evaluate(v) } unless sexp[2..].empty?
      else
        attrs = sexp[2] || [:map]
      end
      sexp = [:entity, type, value, attrs]
    end
    case sexp[0]
    when :entity then evaluate_entity(sexp)
    when :list then evaluate_list(sexp)
    when :add then evaluate_add(sexp)
    when :let then evaluate_let(sexp, { bindings: {}, traits: {} })
    when :impl then evaluate_impl(sexp, { bindings: {}, traits: {} })
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

  def self.parse(tokens) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
    raise "Expected '('" unless tokens[0] == '('

    result = []
    tokens.shift # Remove "("
    until tokens.empty? || tokens[0] == ')'
      if tokens[0] == '('
        result << parse(tokens)
      else
        token = tokens.shift
        result << case token
                  when 'true' then true
                  when 'false' then false
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

    if VALID_FUNCTIONS.include?(result[0]) && result[0] != :entity && !SUGAR_TYPES.include?(result[0])
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

  def self.evaluate_entity(sexp) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
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
    when :Boolean
      return Entity.new(:Error, "expected boolean for Boolean, got #{value}", {}) unless [true, false].include?(value)
    end
    attrs = {}
    if map_expr[0] == :map
      map_expr[1..].each_slice(2) do |key, val|
        if key == :adjective
          evaluated_val = evaluate(val)
          error_msg = "expected Adjective entity for :adjective, got #{evaluated_val}"
          unless evaluated_val.is_a?(Entity) && evaluated_val.type == :Adjective
            return Entity.new(:Error, error_msg, {})
          end

          attrs[key] = evaluated_val
        else
          attrs[key] = val # Evaluated later if needed
        end
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

  def self.evaluate_add(sexp, env = {}) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
    raise "Expected 'add'" unless sexp[0] == :add

    args = sexp[1..].map { |sub_sexp| eval_expr(sub_sexp, env) }
    return Entity.new(:Error, 'insufficient arguments for add', {}) if args.empty?

    args.each do |arg|
      unless arg.is_a?(Entity) && NUMERIC_TYPES.include?(arg.type)
        return Entity.new(:Error, "expected Numeric argument, got #{arg}", {})
      end
    end

    sum = args.map(&:value).reduce(:+)
    type = args.any? { |arg| arg.type == :Float } ? :Float : :Integer
    Entity.new(type, sum, {})
  end

  def self.evaluate_let(sexp, env) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity
    raise "Expected 'let'" unless sexp[0] == :let

    bindings = sexp[1]
    body = sexp[2..]

    new_env = { bindings: env[:bindings].dup, traits: env[:traits].dup }
    bindings.each do |binding|
      raise "Invalid binding: #{binding}" unless binding[1] == :be && binding.length == 3

      label = binding[0]
      value = eval_expr(binding[2], new_env)
      new_env[:bindings][label] = value
    end

    return nil if body.empty?

    result = body.map { |expr| eval_expr(expr, new_env) }
    result.length == 1 ? result.first : result.last
  end

  def self.eval_expr(expr, env) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
    case expr
    when Symbol
      raise "Unbound variable: #{expr}" unless env[:bindings].key?(expr)

      env[:bindings][expr]
    when Entity
      expr
    when Array
      if SUGAR_TYPES.include?(expr[0])
        type = expr[0]
        value = expr[1]
        attrs = [:map]
        if %i[Subject Object].include?(type)
          role = type
          type = :Noun
          attrs = [:map, :role, role]
        end
        evaluate_entity([:entity, type, value, attrs])
      else
        case expr[0]
        when :entity then evaluate_entity(expr)
        when :list then evaluate_list(expr)
        when :add then evaluate_add(expr, env)
        when :let then evaluate_let(expr, env)
        when :impl then evaluate_impl(expr, env)
        else raise "Unknown function: #{expr[0]}"
        end
      end
    else
      expr
    end
  end

  def self.evaluate_impl(sexp, env) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity
    return Entity.new(:Error, "expected 'impl' as first argument", {}) unless sexp[0] == :impl

    unless sexp.length == 4 && sexp[2] == :for
      return Entity.new(:Error, 'invalid impl syntax: expected (impl Trait for Type)', {})
    end

    trait = sexp[1]
    type = sexp[3]

    return Entity.new(:Error, "invalid trait: #{trait}", {}) unless VALID_TRAITS.include?(trait)
    return Entity.new(:Error, "invalid type: #{type}", {}) unless VALID_TYPES.include?(type)

    env[:traits][type] ||= []
    env[:traits][type] << trait unless env[:traits][type].include?(trait) # Avoid duplicates
    Entity.new(:Boolean, true, {})
  end
end
