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

fn topic_weights_for_word(
    beta_probabilities: Vec<Vec<f64>>,
    gamma: Vec<f64>,
    word_index: usize,
    min_probability: f64,
) -> Vec<f64> {
    let topics = gamma.len().min(beta_probabilities.len());
    if topics == 0 {
        return Vec::new();
    }

    let floor = if min_probability.is_finite() && min_probability > 0.0 {
        min_probability
    } else {
        1.0e-12
    };

    let mut weights = Vec::with_capacity(topics);
    let mut total = 0.0_f64;

    for topic_index in 0..topics {
        let beta_value = beta_probabilities[topic_index]
            .get(word_index)
            .copied()
            .unwrap_or(floor)
            .max(floor);
        let gamma_value = gamma[topic_index].max(floor);
        let value = beta_value * gamma_value;
        total += value;
        weights.push(value);
    }

    if total <= 0.0 || !total.is_finite() {
        let uniform = 1.0 / topics as f64;
        return vec![uniform; topics];
    }

    for weight in &mut weights {
        *weight /= total;
    }

    weights
}

#[magnus::init]
fn init() -> Result<(), Error> {
    let lda_module = define_module("Lda")?;
    let rust_backend_module = lda_module.define_module("RustBackend")?;

    rust_backend_module.define_singleton_method("available?", function!(available, 0))?;
    rust_backend_module.define_singleton_method("abi_version", function!(abi_version, 0))?;
    rust_backend_module.define_singleton_method("before_em", function!(before_em, 3))?;
    rust_backend_module.define_singleton_method(
        "topic_weights_for_word",
        function!(topic_weights_for_word, 4),
    )?;

    Ok(())
}
