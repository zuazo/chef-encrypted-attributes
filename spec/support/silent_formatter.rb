require 'rspec/core/formatters/base_text_formatter'

class SilentFormatter < RSpec::Core::Formatters::BaseTextFormatter

  def initialize(output)
    super(output)
  end

  def example_passed(example)
    # super(example)
  end

  def example_pending(example)
    super(example)
  end

  def example_started(example)
  end

  def example_failed(example)
    super(example)
    output.puts failure_color('FAILED!')
  end

  def start_dump
    super
  end

  def dump_summary(*args)
    super(*args)
  end

end
