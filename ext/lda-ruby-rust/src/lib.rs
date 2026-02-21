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

fn floor_value(min_probability: f64) -> f64 {
    if min_probability.is_finite() && min_probability > 0.0 {
        min_probability
    } else {
        1.0e-12
    }
}

fn normalize_in_place(weights: &mut [f64]) {
    let total: f64 = weights.iter().sum();

    if !total.is_finite() || total <= 0.0 {
        let uniform = if weights.is_empty() {
            0.0
        } else {
            1.0 / weights.len() as f64
        };
        for weight in weights {
            *weight = uniform;
        }
        return;
    }

    for weight in weights {
        *weight /= total;
    }
}

fn compute_topic_weights(
    beta_probabilities: &[Vec<f64>],
    gamma: &[f64],
    word_index: usize,
    floor: f64,
) -> Vec<f64> {
    let topics = gamma.len().min(beta_probabilities.len());
    if topics == 0 {
        return Vec::new();
    }

    let mut weights = Vec::with_capacity(topics);
    for topic_index in 0..topics {
        let beta_value = beta_probabilities[topic_index]
            .get(word_index)
            .copied()
            .unwrap_or(floor)
            .max(floor);
        let gamma_value = gamma[topic_index].max(floor);
        weights.push(beta_value * gamma_value);
    }

    normalize_in_place(&mut weights);
    weights
}

fn topic_weights_for_word(
    beta_probabilities: Vec<Vec<f64>>,
    gamma: Vec<f64>,
    word_index: usize,
    min_probability: f64,
) -> Vec<f64> {
    let floor = floor_value(min_probability);
    compute_topic_weights(&beta_probabilities, &gamma, word_index, floor)
}

fn accumulate_topic_term_counts(
    mut topic_term_counts: Vec<Vec<f64>>,
    phi_d: Vec<Vec<f64>>,
    words: Vec<usize>,
    counts: Vec<f64>,
) -> Vec<Vec<f64>> {
    let topics = topic_term_counts.len();
    if topics == 0 {
        return topic_term_counts;
    }

    for (word_offset, &word_index) in words.iter().enumerate() {
        let count = counts.get(word_offset).copied().unwrap_or(0.0);
        if count == 0.0 {
            continue;
        }

        let Some(phi_row) = phi_d.get(word_offset) else {
            continue;
        };

        for topic_index in 0..topics {
            let phi_value = phi_row.get(topic_index).copied().unwrap_or(0.0);
            if let Some(topic_terms) = topic_term_counts.get_mut(topic_index) {
                if word_index < topic_terms.len() {
                    topic_terms[word_index] += count * phi_value;
                }
            }
        }
    }

    topic_term_counts
}

fn infer_document(
    beta_probabilities: Vec<Vec<f64>>,
    gamma_initial: Vec<f64>,
    words: Vec<usize>,
    counts: Vec<f64>,
    max_iter: i64,
    convergence: f64,
    min_probability: f64,
    init_alpha: f64,
) -> Vec<Vec<f64>> {
    let topics = gamma_initial.len().min(beta_probabilities.len());
    if topics == 0 {
        return vec![Vec::new(), Vec::new()];
    }

    let floor = floor_value(min_probability);
    let init_alpha_value = if init_alpha.is_finite() {
        init_alpha
    } else {
        0.3
    };
    let convergence_value = if convergence.is_finite() && convergence >= 0.0 {
        convergence
    } else {
        1.0e-6
    };
    let max_iter_value = if max_iter <= 0 { 1 } else { max_iter as usize };

    let mut gamma_d = gamma_initial.into_iter().take(topics).collect::<Vec<_>>();
    if gamma_d.len() < topics {
        gamma_d.resize(topics, init_alpha_value);
    }

    let mut phi_d = vec![vec![1.0 / topics as f64; topics]; words.len()];

    for _ in 0..max_iter_value {
        let mut gamma_next = vec![init_alpha_value; topics];

        for (word_offset, &word_index) in words.iter().enumerate() {
            let topic_weights = compute_topic_weights(&beta_probabilities, &gamma_d, word_index, floor);
            phi_d[word_offset] = topic_weights.clone();

            let count = counts.get(word_offset).copied().unwrap_or(0.0);
            if count == 0.0 {
                continue;
            }

            for topic_index in 0..topics {
                gamma_next[topic_index] += count * topic_weights[topic_index];
            }
        }

        let mut gamma_shift = 0.0_f64;
        for topic_index in 0..topics {
            let delta = (gamma_d[topic_index] - gamma_next[topic_index]).abs();
            if delta > gamma_shift {
                gamma_shift = delta;
            }
        }

        gamma_d = gamma_next;
        if gamma_shift <= convergence_value {
            break;
        }
    }

    let mut output = Vec::with_capacity(phi_d.len() + 1);
    output.push(gamma_d);
    output.extend(phi_d);
    output
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
    rust_backend_module.define_singleton_method(
        "accumulate_topic_term_counts",
        function!(accumulate_topic_term_counts, 4),
    )?;
    rust_backend_module.define_singleton_method("infer_document", function!(infer_document, 8))?;

    Ok(())
}
