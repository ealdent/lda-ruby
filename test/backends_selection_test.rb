require_relative "test_helper"

class BackendsSelectionTest < Test::Unit::TestCase
  RUST_ALIAS = :__test_original_rust_available__
  NATIVE_ALIAS = :__test_original_native_available__

  setup do
    @host = Object.new
    @rust_singleton = Lda::Backends::Rust.singleton_class
    @native_singleton = Lda::Backends::Native.singleton_class

    @rust_singleton.send(:alias_method, RUST_ALIAS, :available?)
    @native_singleton.send(:alias_method, NATIVE_ALIAS, :available?)
    @previous_env_backend = ENV["LDA_RUBY_BACKEND"]
  end

  teardown do
    restore_availability_stubs
    ENV["LDA_RUBY_BACKEND"] = @previous_env_backend
  end

  should "prefer rust over native in auto mode when both are available" do
    stub_rust_available(true)
    stub_native_available(true)

    backend = Lda::Backends.build(host: @host, requested: :auto)
    assert_instance_of Lda::Backends::Rust, backend
  end

  should "fall back to native in auto mode when rust is unavailable" do
    stub_rust_available(false)
    stub_native_available(true)

    backend = Lda::Backends.build(host: @host, requested: :auto)
    assert_instance_of Lda::Backends::Native, backend
  end

  should "fall back to pure in auto mode when rust and native are unavailable" do
    stub_rust_available(false)
    stub_native_available(false)

    backend = Lda::Backends.build(host: @host, requested: :auto)
    assert_instance_of Lda::Backends::PureRuby, backend
  end

  should "respect LDA_RUBY_BACKEND env override when requested mode is nil" do
    stub_rust_available(true)
    stub_native_available(true)
    ENV["LDA_RUBY_BACKEND"] = "pure_ruby"

    backend = Lda::Backends.build(host: @host, requested: nil)
    assert_instance_of Lda::Backends::PureRuby, backend
  end

  should "raise for unknown backend mode" do
    stub_rust_available(false)
    stub_native_available(false)

    error = assert_raise(ArgumentError) do
      Lda::Backends.build(host: @host, requested: :unknown_backend)
    end

    assert_match(/Unknown backend mode/i, error.message)
  end

  private

  def stub_rust_available(value)
    silence_redefinition_warnings do
      @rust_singleton.send(:define_method, :available?) do
        value
      end
    end
  end

  def stub_native_available(value)
    silence_redefinition_warnings do
      @native_singleton.send(:define_method, :available?) do |_host|
        value
      end
    end
  end

  def restore_availability_stubs
    silence_redefinition_warnings do
      @rust_singleton.send(:alias_method, :available?, RUST_ALIAS)
      @native_singleton.send(:alias_method, :available?, NATIVE_ALIAS)
    end
    @rust_singleton.send(:remove_method, RUST_ALIAS)
    @native_singleton.send(:remove_method, NATIVE_ALIAS)
  end

  def silence_redefinition_warnings
    previous_verbose = $VERBOSE
    $VERBOSE = nil
    yield
  ensure
    $VERBOSE = previous_verbose
  end
end
