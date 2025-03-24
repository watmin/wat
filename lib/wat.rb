# frozen_string_literal: true

def reload
  load(File.join(__dir__, 'wat.rb'))
end

require_relative 'wat/version'

class Wat # rubocop:disable Metrics/ClassLength
  attr_reader :env

  Entity = Struct.new(:type, :value, :attrs)
  Lambda = Struct.new(:params, :return_type, :body, :env, :frozen_env) do
    def initialize(params, return_type, body, env)
      super(params, return_type, body, env, false)
    end
  end

  VALID_TYPES = %i[Noun Verb Time Adverb String Integer Float Boolean
                   Pronoun Preposition Adjective Error Lambda].freeze
  SUGAR_TYPES = %i[Noun Verb Time Adverb Pronoun Preposition Adjective
                   Subject Object Integer Float Boolean].freeze
  VALID_FUNCTIONS = %i[entity list add let impl lambda Noun Verb Time Adverb
                       Pronoun Preposition Adjective Subject Object
                       Integer Float Boolean].freeze
  LISTABLE_TYPES = %i[Noun Time Verb Integer Float].freeze
  NUMERIC_TYPES = %i[Integer Float].freeze
  VALID_TRAITS = %i[Relatable RelatableVerb Adverbial Timeable
                    StringValued Numeric Assertable Listable Mappable Describable].freeze

  def initialize
    @env = {
      bindings: {
        add: :add,
        list: :list,
        entity: :entity,
        let: :let,
        impl: :impl,
        lambda: :lambda
      },
      traits: {}
    }
  end

  def evaluate(input, env = @env) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
    tokens = tokenize(input) if input.is_a?(String)
    sexp = if input.is_a?(String)
             sexps = []
             sexps << parse(tokens) until tokens.empty?
             sexps
           else
             [input]
           end
    return nil if sexp.empty?

    last_result = nil
    sexp.each do |s|
      if SUGAR_TYPES.include?(s[0])
        type = s[0]
        value = s[1]

        if %i[Subject Object].include?(type)
          role = type
          type = :Noun
          attrs = [:map, :role, role]
          map_args = s[2..]

          return Entity.new(:Error, "unpaired map key: :#{map_args.last}", {}) if map_args.length.odd?

          map_args.each_slice(2) { |k, v| attrs << k << evaluate(v, env) }
        else
          attrs = s[2] || [:map]
        end
        s = [:entity, type, value, attrs]
      end

      last_result = case s[0]
                    when :entity then evaluate_entity(s)
                    when :list then evaluate_list(s)
                    when :add then evaluate_add(s, env)
                    when :let then evaluate_let(s, env)
                    when :impl then evaluate_impl(s, env)
                    when :lambda then evaluate_lambda(s, env)
                    else
                      raise "Unknown function: #{s[0]}"
                    end
    end

    last_result
  end

  private

  def tokenize(input) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
    tokens = []
    buffer = String.new
    in_quotes = false
    in_comment = false

    input.chars.each do |char|
      if in_comment
        in_comment = false if char == "\n"
        next
      end
      if char == ';' && !in_quotes
        in_comment = true
        tokens << buffer if buffer != ''
        buffer = String.new
        next
      end
      if char == '"'
        in_quotes = !in_quotes
        buffer << char
      elsif in_quotes
        buffer << char
      elsif char =~ /\s/
        tokens << buffer if buffer != ''
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

    raise 'Unclosed quote' if in_quotes

    tokens
  end

  def parse(tokens) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
    raise "Expected '('" unless tokens[0] == '('

    result = []
    tokens.shift
    until tokens.empty? || tokens[0] == ')'
      if tokens[0] == '('
        result << parse(tokens)
      else
        token = tokens.shift
        result << case token
                  when 'true' then true
                  when 'false' then false
                  when 'nil' then nil
                  when /^"/ then token[1..].delete_suffix('"')
                  when /^-?\d+\.\d+$/ then token.to_f
                  when /^-?\d+$/ then token.to_i
                  when /^:/ then token[1..].to_sym
                  when /^'/ then raise 'Single quotes not allowed; use double quotes'
                  else token.to_sym
                  end
      end
    end

    raise 'Unclosed parenthesis' if tokens.empty?

    tokens.shift

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

  def evaluate_entity(sexp) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
    return Entity.new(:Error, "expected 'entity' as first argument", {}) unless sexp[0] == :entity

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
          attrs[key] = val
        end
      end
    end

    Entity.new(type, value, attrs)
  end

  def evaluate_list(sexp)
    return Entity.new(:Error, "expected 'list' as first argument", {}) unless sexp[0] == :list

    sexp[1..].map do |sub_sexp|
      result = evaluate(sub_sexp)

      unless result.is_a?(Entity) && LISTABLE_TYPES.include?(result.type)
        return Entity.new(:Error, "expression not Listable: #{sub_sexp}", {})
      end

      result
    end
  end

  def evaluate_add(sexp, env) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
    args = sexp[1..].map { |arg| eval_expr(arg, env) }
    return Entity.new(:Error, 'insufficient arguments for add, expected at least one', {}) if args.empty?

    unless args.all? { |arg| arg.is_a?(Entity) && %i[Integer Float].include?(arg.type) }
      return Entity.new(:Error, "expected Numeric arguments for add, got #{args}", {})
    end

    result = args.reduce(0) do |sum, arg|
      sum + (arg.type == :Float || sum.is_a?(Float) ? arg.value.to_f : arg.value)
    end
    type = result.is_a?(Float) ? :Float : :Integer
    Entity.new(type, result, {})
  end

  def deep_dup(env)
    { bindings: env[:bindings].dup, traits: env[:traits].transform_values(&:dup) }
  end

  def evaluate_let(sexp, env) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
    return Entity.new(:Error, "expected 'let' as first argument", {}) unless sexp[0] == :let

    bindings = sexp[1]
    body = sexp[2..]
    new_env = deep_dup(env)

    bindings.each do |binding|
      return Entity.new(:Error, "invalid binding: #{binding}", {}) unless binding[1] == :be && binding.length == 3

      label = binding[0]
      value = evaluate(binding[2], new_env)
      new_env[:bindings][label] = value
    end

    new_env[:bindings].each_value do |value|
      next unless value.is_a?(Wat::Lambda) && !value.frozen_env

      value.env = deep_dup(new_env)
      value.frozen_env = true
    end

    return nil if body.empty?

    result = body.map { |expr| eval_expr(expr, new_env) }
    result.length == 1 ? result.first : result.last
  end

  def eval_expr(expr, env) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
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
        fn = if expr[0].is_a?(Array)
               evaluate_lambda_application([eval_expr(expr[0][0], env)] + expr[0][1..], env)
             else
               eval_expr(expr[0], env)
             end
        if fn.is_a?(Wat::Lambda)
          evaluate_lambda_application([fn] + expr[1..], env)
        elsif env[:bindings].key?(fn) && env[:bindings][fn].is_a?(Wat::Lambda)
          evaluate_lambda_application([env[:bindings][fn]] + expr[1..], env)
        elsif fn.is_a?(Entity)
          fn
        elsif VALID_FUNCTIONS.include?(fn)
          case fn # rubocop:disable Metrics/BlockNesting
          when :add then evaluate_add([fn] + expr[1..], env)
          when :list then evaluate_list([fn] + expr[1..])
          when :entity then evaluate_entity([fn] + expr[1..])
          when :let then evaluate_let([fn] + expr[1..], env)
          when :impl then evaluate_impl([fn] + expr[1..], env)
          when :lambda then evaluate_lambda([fn] + expr[1..], env)
          else raise "Unknown built-in function: #{fn}"
          end
        elsif fn.is_a?(Entity) && fn.type == :Error
          fn
        else
          case fn # rubocop:disable Metrics/BlockNesting
          when :entity then evaluate_entity(expr)
          when :list then evaluate_list(expr)
          when :add then evaluate_add(expr, env)
          when :let then evaluate_let(expr, env)
          when :impl then evaluate_impl(expr, env)
          when :lambda then evaluate_lambda(expr, env)
          else raise "Unknown function: #{fn}"
          end
        end
      end
    else
      expr
    end
  end

  def evaluate_impl(sexp, env) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity
    return Entity.new(:Error, "expected 'impl' as first argument", {}) unless sexp[0] == :impl

    unless sexp.length == 4 && sexp[2] == :for
      return Entity.new(:Error, 'invalid impl syntax: expected (impl Trait for Type)', {})
    end

    trait = sexp[1]
    type = sexp[3]

    return Entity.new(:Error, "invalid trait: #{trait}", {}) unless VALID_TRAITS.include?(trait)
    return Entity.new(:Error, "invalid type: #{type}", {}) unless VALID_TYPES.include?(type)

    env[:traits][type] ||= []
    env[:traits][type] << trait unless env[:traits][type].include?(trait)

    Entity.new(:Boolean, true, {})
  end

  def evaluate_lambda(sexp, env) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity,Metrics/MethodLength
    return Entity.new(:Error, "expected 'lambda' as first argument", {}) unless sexp[0] == :lambda

    unless sexp.length == 5
      return Entity.new(
        :Error,
        'invalid lambda syntax: expected (lambda ((arg as Type) ...) returns ReturnType body)',
        {}
      )
    end

    params_sexp = sexp[1]
    return_keyword = sexp[2]
    return_type = sexp[3]
    body = sexp[4]

    unless return_keyword == :returns && VALID_TYPES.include?(return_type)
      return Entity.new(
        :Error,
        "expected 'returns' followed by valid ReturnType, got #{return_keyword} #{return_type}",
        {}
      )
    end

    unless params_sexp.is_a?(Array) &&
           params_sexp.all? { |p| p.is_a?(Array) && p.length == 3 && p[1] == :as && VALID_TYPES.include?(p[2]) }
      return Entity.new(
        :Error,
        "invalid lambda syntax: expected parameter list ((arg as Type) ...), got #{params_sexp}",
        {}
      )
    end

    param_names = params_sexp.map { |p| p[0] }
    if param_names.uniq.length != param_names.length
      return Entity.new(
        :Error,
        "invalid lambda syntax: duplicate parameter names in #{params_sexp}",
        {}
      )
    end

    if body.is_a?(Array) && body[0] == :self
      return Entity.new(
        :Error,
        'invalid lambda syntax: self-reference not allowed without binding',
        {}
      )
    end

    params = params_sexp.map { |param| [param[0], param[2]] }
    Lambda.new(params, return_type, body, deep_dup(env))
  end

  def evaluate_lambda_application(sexp, env) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
    fn = sexp[0]
    args = sexp[1..]
    return Entity.new(:Error, 'expected lambda as first argument in application', {}) unless fn.is_a?(Wat::Lambda)
    unless fn.params.length == args.length
      return Entity.new(:Error, "argument count mismatch: expected #{fn.params.length}, got #{args.length}", {})
    end

    new_env = deep_dup(fn.env)
    new_env[:bindings] = env[:bindings].merge(new_env[:bindings]) { |_key, _old_val, new_val| new_val }
    new_env[:traits] = env[:traits].merge(new_env[:traits]) { |_key, _old_val, new_val| new_val }

    fn.params.zip(args).each do |(param_name, param_type), arg_sexp|
      arg = eval_expr(arg_sexp, new_env)
      return Entity.new(:Error, "nil argument not allowed for #{param_name}", {}) if arg.nil?

      unless arg.is_a?(Entity)
        case param_type
        when :Integer
          arg = Entity.new(:Integer, arg, {}) if arg.is_a?(Integer)
        when :Float
          if arg.is_a?(Integer)
            arg = Entity.new(:Float, arg.to_f, {})
          elsif arg.is_a?(Float)
            arg = Entity.new(:Float, arg, {})
          end
        when :Boolean
          arg = Entity.new(:Boolean, arg, {}) if [true, false].include?(arg)
        when :String
          arg = Entity.new(:String, arg, {}) if arg.is_a?(String)
        end
      end

      unless (param_type == :Lambda && arg.is_a?(Wat::Lambda)) || (arg.is_a?(Entity) && arg.type == param_type)
        return Entity.new(:Error, "type mismatch for #{param_name}: expected #{param_type}, got #{arg}", {})
      end

      new_env[:bindings][param_name] = arg
    end

    begin
      if fn.body.is_a?(Array) && fn.body[0] == :lambda
        params = fn.body[1].map { |param| [param[0], param[2]] }
        return_type = fn.body[3]
        body = fn.body[4]
        Lambda.new(params, return_type, body, deep_dup(new_env))
      else
        eval_env = deep_dup(new_env)
        eval_env[:bindings].delete_if { |_k, v| v.equal?(fn) }
        result = eval_expr(fn.body, eval_env)

        unless result.is_a?(Wat::Lambda) || (result.is_a?(Entity) && result.type == fn.return_type)
          return Entity.new(:Error, "return type mismatch: expected #{fn.return_type}, got #{result}", {})
        end

        result
      end
    rescue RuntimeError => e
      Entity.new(:Error, e.message, {})
    end
  end
end
