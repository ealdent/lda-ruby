use magnus::{define_module, function, Error, Module, Object};

fn available() -> bool {
    true
}

fn abi_version() -> i64 {
    1
}

fn before_em(_start: String, _num_docs: i64, _num_terms: i64) -> bool {
    true
}

#[magnus::init]
fn init() -> Result<(), Error> {
    let lda_module = define_module("Lda")?;
    let rust_backend_module = lda_module.define_module("RustBackend")?;

    rust_backend_module.define_singleton_method("available?", function!(available, 0))?;
    rust_backend_module.define_singleton_method("abi_version", function!(abi_version, 0))?;
    rust_backend_module.define_singleton_method("before_em", function!(before_em, 3))?;

    Ok(())
}
