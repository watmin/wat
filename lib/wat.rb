# frozen_string_literal: true

require_relative "wat/version"

class Wat
  CORE = {
    add: proc { |x, y| x + y },
    sub: proc { |x, y| x - y },  # New: subtraction
    mul: proc { |x, y| x * y },  # New: multiplication
    eq: proc { |x, y| x == y }   # New: equality
  }

  def initialize
    @env = CORE
  end

  def eval(program)
    ast = parse(program)
    evaluate(ast[0])
  end

  private

  def parse(str)
    tokens = str.gsub(/[()]/, ' \0 ').split.map(&:strip)
    read_expressions(tokens)
  end

  def read_expressions(tokens, acc = [], depth = 0)
    raise "Syntax error: unclosed parenthesis" if tokens.empty? && depth > 0
    return acc if tokens.empty? && depth == 0
    token = tokens.shift
    case token
    when '('
      exp = read_expressions(tokens, [], depth + 1)
      acc << exp
      read_expressions(tokens, acc, depth)
    when ')'
      raise "Syntax error: unexpected closing parenthesis" if depth == 0
      acc
    else
      acc << (integer?(token) ? token.to_i : token.to_sym)
      read_expressions(tokens, acc, depth)
    end
  end

  def integer?(str)
    str =~ /^\d+$/
  end

  def evaluate(exp)
    return exp if exp.is_a?(Integer)
    return @env[exp].call if @env.key?(exp)
    fn_name, *args = exp
    fn = @env[fn_name] || raise("Unknown function: #{fn_name}")
    expected_arity = fn.arity
    actual_arity = args.size
    raise "Arity error: #{fn_name} expects #{expected_arity} args, got #{actual_arity}" unless expected_arity == actual_arity
    fn.call(*args.map { |a| evaluate(a) })
  end
end
