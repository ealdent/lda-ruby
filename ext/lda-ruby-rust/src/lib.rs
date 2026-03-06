use magnus::{define_module, function, Error, Module, Object};
use std::collections::HashMap;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex, OnceLock};

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

#[derive(Clone, PartialEq)]
struct SessionConfig {
    topics: usize,
    max_iter: i64,
    convergence: f64,
    em_max_iter: i64,
    em_convergence: f64,
    init_alpha: f64,
    min_probability: f64,
}

struct CorpusSessionData {
    document_words: Vec<Vec<usize>>,
    document_counts: Vec<Vec<f64>>,
    terms: usize,
}

struct CorpusSession {
    data: Arc<CorpusSessionData>,
    config: Option<SessionConfig>,
}

static CORPUS_SESSIONS: OnceLock<Mutex<HashMap<u64, CorpusSession>>> = OnceLock::new();
static NEXT_CORPUS_SESSION_ID: AtomicU64 = AtomicU64::new(1);

fn corpus_sessions() -> &'static Mutex<HashMap<u64, CorpusSession>> {
    CORPUS_SESSIONS.get_or_init(|| Mutex::new(HashMap::new()))
}

fn corpus_session_count() -> i64 {
    match corpus_sessions().lock() {
        Ok(sessions) => sessions.len() as i64,
        Err(_) => 0,
    }
}

fn corpus_session_exists(session_id: i64) -> bool {
    if session_id <= 0 {
        return false;
    }

    let session_key = session_id as u64;
    match corpus_sessions().lock() {
        Ok(sessions) => sessions.contains_key(&session_key),
        Err(_) => false,
    }
}

fn empty_em_output() -> (Vec<Vec<f64>>, Vec<Vec<f64>>, Vec<Vec<f64>>, Vec<Vec<Vec<f64>>>) {
    (Vec::new(), Vec::new(), Vec::new(), Vec::new())
}

fn empty_managed_session_em_output(
) -> (
    i64,
    Vec<Vec<f64>>,
    Vec<Vec<f64>>,
    Vec<Vec<f64>>,
    Vec<Vec<Vec<f64>>>,
) {
    (0, Vec::new(), Vec::new(), Vec::new(), Vec::new())
}

struct XorShift64 {
    state: u64,
}

impl XorShift64 {
    fn new(seed: i64) -> Self {
        let mut state = seed as u64;
        if state == 0 {
            state = 0x9E37_79B9_7F4A_7C15;
        }

        Self { state }
    }

    fn next_u64(&mut self) -> u64 {
        let mut x = self.state;
        x ^= x >> 12;
        x ^= x << 25;
        x ^= x >> 27;
        self.state = x;
        x.wrapping_mul(0x2545_F491_4F6C_DD1D)
    }

    fn next_f64_unit(&mut self) -> f64 {
        // Keep 53 random bits to map uniformly into [0, 1).
        let value = self.next_u64() >> 11;
        value as f64 / ((1_u64 << 53) as f64)
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

fn accumulate_topic_term_counts_in_place(
    topic_term_counts: &mut [Vec<f64>],
    phi_d: &[Vec<f64>],
    words: &[usize],
    counts: &[f64],
) {
    let topics = topic_term_counts.len();
    if topics == 0 {
        return;
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
}

fn accumulate_topic_term_counts(
    mut topic_term_counts: Vec<Vec<f64>>,
    phi_d: Vec<Vec<f64>>,
    words: Vec<usize>,
    counts: Vec<f64>,
) -> Vec<Vec<f64>> {
    accumulate_topic_term_counts_in_place(
        topic_term_counts.as_mut_slice(),
        phi_d.as_slice(),
        words.as_slice(),
        counts.as_slice(),
    );
    topic_term_counts
}

fn normalize_topic_term_counts(
    topic_term_counts: Vec<Vec<f64>>,
    min_probability: f64,
) -> (Vec<Vec<f64>>, Vec<Vec<f64>>) {
    let floor = floor_value(min_probability);

    let mut beta_probabilities = Vec::with_capacity(topic_term_counts.len());
    let mut beta_log = Vec::with_capacity(topic_term_counts.len());

    for topic_counts in topic_term_counts.iter() {
        let mut normalized = topic_counts
            .iter()
            .map(|value| {
                if value.is_finite() {
                    value.max(floor)
                } else {
                    floor
                }
            })
            .collect::<Vec<_>>();

        normalize_in_place(&mut normalized);

        let topic_log = normalized
            .iter()
            .map(|value| value.max(floor).ln())
            .collect::<Vec<_>>();

        beta_probabilities.push(normalized);
        beta_log.push(topic_log);
    }

    (beta_probabilities, beta_log)
}

fn average_gamma_shift_internal(previous_gamma: &[Vec<f64>], current_gamma: &[Vec<f64>]) -> f64 {
    let mut sum = 0.0_f64;
    let mut count = 0_usize;

    for (row_index, previous_row) in previous_gamma.iter().enumerate() {
        let current_row = current_gamma.get(row_index);

        for (col_index, previous_value) in previous_row.iter().enumerate() {
            let current_value = current_row
                .and_then(|row| row.get(col_index))
                .copied()
                .unwrap_or(*previous_value);

            sum += (previous_value - current_value).abs();
            count += 1;
        }
    }

    if count == 0 {
        0.0
    } else {
        sum / count as f64
    }
}

fn average_gamma_shift(previous_gamma: Vec<Vec<f64>>, current_gamma: Vec<Vec<f64>>) -> f64 {
    average_gamma_shift_internal(previous_gamma.as_slice(), current_gamma.as_slice())
}

fn topic_document_probability(
    phi_tensor: Vec<Vec<Vec<f64>>>,
    document_counts: Vec<Vec<f64>>,
    num_topics: usize,
    min_probability: f64,
) -> Vec<Vec<f64>> {
    let floor = floor_value(min_probability);
    let mut output = Vec::with_capacity(document_counts.len());

    for (doc_index, counts) in document_counts.iter().enumerate() {
        let mut tops = vec![0.0_f64; num_topics];
        let ttl: f64 = counts.iter().copied().sum();

        if let Some(doc_phi) = phi_tensor.get(doc_index) {
            for (word_index, word_dist) in doc_phi.iter().enumerate() {
                let count = counts.get(word_index).copied().unwrap_or(0.0);
                if count == 0.0 {
                    continue;
                }

                for topic_index in 0..num_topics {
                    let top_prob = word_dist.get(topic_index).copied().unwrap_or(floor).max(floor);
                    tops[topic_index] += top_prob.ln() * count;
                }
            }
        }

        if ttl.is_finite() && ttl > 0.0 {
            for value in tops.iter_mut() {
                *value /= ttl;
            }
        }

        output.push(tops);
    }

    output
}

fn seeded_topic_term_probabilities_internal(
    document_words: &[Vec<usize>],
    document_counts: &[Vec<f64>],
    topics: usize,
    terms: usize,
    min_probability: f64,
) -> Vec<Vec<f64>> {
    if topics == 0 || terms == 0 {
        return Vec::new();
    }

    let floor = floor_value(min_probability);
    let mut topic_term_counts = vec![vec![floor; terms]; topics];

    for (doc_index, words) in document_words.iter().enumerate() {
        let topic_index = doc_index % topics;
        let counts = document_counts.get(doc_index);

        for (word_offset, &word_index) in words.iter().enumerate() {
            if word_index >= terms {
                continue;
            }

            let count = counts
                .and_then(|row| row.get(word_offset))
                .copied()
                .unwrap_or(0.0);
            if !count.is_finite() || count == 0.0 {
                continue;
            }

            topic_term_counts[topic_index][word_index] += count;
        }
    }

    for row in topic_term_counts.iter_mut() {
        normalize_in_place(row);
    }

    topic_term_counts
}

fn seeded_topic_term_probabilities(
    document_words: Vec<Vec<usize>>,
    document_counts: Vec<Vec<f64>>,
    topics: usize,
    terms: usize,
    min_probability: f64,
) -> Vec<Vec<f64>> {
    seeded_topic_term_probabilities_internal(
        document_words.as_slice(),
        document_counts.as_slice(),
        topics,
        terms,
        min_probability,
    )
}

fn random_topic_term_probabilities(
    topics: usize,
    terms: usize,
    min_probability: f64,
    random_seed: i64,
) -> Vec<Vec<f64>> {
    if topics == 0 || terms == 0 {
        return Vec::new();
    }

    let floor = floor_value(min_probability);
    let mut rng = XorShift64::new(random_seed);
    let mut matrix = Vec::with_capacity(topics);

    for _ in 0..topics {
        let mut weights = Vec::with_capacity(terms);
        for _ in 0..terms {
            weights.push(rng.next_f64_unit() + floor);
        }
        normalize_in_place(&mut weights);
        matrix.push(weights);
    }

    matrix
}

fn corpus_session_data(
    document_words: &[Vec<usize>],
    document_counts: &[Vec<f64>],
    terms: usize,
) -> Arc<CorpusSessionData> {
    Arc::new(CorpusSessionData {
        document_words: document_words.to_vec(),
        document_counts: document_counts.to_vec(),
        terms,
    })
}

fn create_corpus_session_internal(
    document_words: &[Vec<usize>],
    document_counts: &[Vec<f64>],
    terms: usize,
) -> i64 {
    let session_id = NEXT_CORPUS_SESSION_ID.fetch_add(1, Ordering::Relaxed);
    let session = CorpusSession {
        data: corpus_session_data(document_words, document_counts, terms),
        config: None,
    };

    match corpus_sessions().lock() {
        Ok(mut sessions) => {
            sessions.insert(session_id, session);
            session_id as i64
        }
        Err(_) => 0,
    }
}

fn create_corpus_session(
    document_words: Vec<Vec<usize>>,
    document_counts: Vec<Vec<f64>>,
    terms: usize,
) -> i64 {
    create_corpus_session_internal(document_words.as_slice(), document_counts.as_slice(), terms)
}

fn replace_corpus_session_internal(
    session_id: i64,
    document_words: &[Vec<usize>],
    document_counts: &[Vec<f64>],
    terms: usize,
) -> i64 {
    if terms == 0 {
        return 0;
    }

    let replacement_data = corpus_session_data(document_words, document_counts, terms);
    match corpus_sessions().lock() {
        Ok(mut sessions) => {
            if session_id > 0 {
                let session_key = session_id as u64;
                if let Some(session) = sessions.get_mut(&session_key) {
                    session.data = replacement_data;
                    session.config = None;
                    return session_id;
                }
            }

            let new_session_id = NEXT_CORPUS_SESSION_ID.fetch_add(1, Ordering::Relaxed);
            sessions.insert(
                new_session_id,
                CorpusSession {
                    data: replacement_data,
                    config: None,
                },
            );
            new_session_id as i64
        }
        Err(_) => 0,
    }
}

fn replace_corpus_session(
    session_id: i64,
    document_words: Vec<Vec<usize>>,
    document_counts: Vec<Vec<f64>>,
    terms: usize,
) -> i64 {
    replace_corpus_session_internal(
        session_id,
        document_words.as_slice(),
        document_counts.as_slice(),
        terms,
    )
}

fn ensure_corpus_session(
    session_id: i64,
    document_words: &[Vec<usize>],
    document_counts: &[Vec<f64>],
    terms: usize,
) -> i64 {
    if terms == 0 {
        return 0;
    }

    if session_id > 0 && corpus_session_exists(session_id) {
        return session_id;
    }

    create_corpus_session_internal(document_words, document_counts, terms)
}

fn drop_corpus_session(session_id: i64) -> bool {
    if session_id <= 0 {
        return false;
    }

    let session_key = session_id as u64;
    match corpus_sessions().lock() {
        Ok(mut sessions) => sessions.remove(&session_key).is_some(),
        Err(_) => false,
    }
}

fn configure_corpus_session(
    session_id: i64,
    topics: usize,
    max_iter: i64,
    convergence: f64,
    em_max_iter: i64,
    em_convergence: f64,
    init_alpha: f64,
    min_probability: f64,
) -> bool {
    if session_id <= 0 || topics == 0 {
        return false;
    }

    let session_key = session_id as u64;
    match corpus_sessions().lock() {
        Ok(mut sessions) => {
            let Some(session) = sessions.get_mut(&session_key) else {
                return false;
            };

            session.config = Some(SessionConfig {
                topics,
                max_iter,
                convergence,
                em_max_iter,
                em_convergence,
                init_alpha,
                min_probability,
            });

            true
        }
        Err(_) => false,
    }
}

fn run_em_on_session_with_start_seed(
    session_id: i64,
    start: String,
    topics: usize,
    max_iter: i64,
    convergence: f64,
    em_max_iter: i64,
    em_convergence: f64,
    init_alpha: f64,
    min_probability: f64,
    random_seed: i64,
) -> (Vec<Vec<f64>>, Vec<Vec<f64>>, Vec<Vec<f64>>, Vec<Vec<Vec<f64>>>) {
    if session_id <= 0 {
        return empty_em_output();
    }

    let session_key = session_id as u64;
    let session_data = match corpus_sessions().lock() {
        Ok(sessions) => sessions
            .get(&session_key)
            .map(|session| Arc::clone(&session.data)),
        Err(_) => None,
    };

    let Some(session_data) = session_data else {
        return empty_em_output();
    };

    run_em_with_start_seed_internal(
        start.as_str(),
        session_data.document_words.as_slice(),
        session_data.document_counts.as_slice(),
        topics,
        session_data.terms,
        max_iter,
        convergence,
        em_max_iter,
        em_convergence,
        init_alpha,
        min_probability,
        random_seed,
    )
}

fn run_em_on_session(
    session_id: i64,
    start: String,
    topics: usize,
    max_iter: i64,
    convergence: f64,
    em_max_iter: i64,
    em_convergence: f64,
    init_alpha: f64,
    min_probability: f64,
    random_seed: i64,
) -> (Vec<Vec<f64>>, Vec<Vec<f64>>, Vec<Vec<f64>>, Vec<Vec<Vec<f64>>>) {
    if session_id <= 0 || topics == 0 {
        return empty_em_output();
    }

    let desired_config = SessionConfig {
        topics,
        max_iter,
        convergence,
        em_max_iter,
        em_convergence,
        init_alpha,
        min_probability,
    };

    let session_key = session_id as u64;
    let session_data = match corpus_sessions().lock() {
        Ok(mut sessions) => {
            let Some(session) = sessions.get_mut(&session_key) else {
                return empty_em_output();
            };

            if session.config.as_ref() != Some(&desired_config) {
                session.config = Some(desired_config.clone());
            }

            Arc::clone(&session.data)
        }
        Err(_) => return empty_em_output(),
    };

    run_em_with_start_seed_internal(
        start.as_str(),
        session_data.document_words.as_slice(),
        session_data.document_counts.as_slice(),
        desired_config.topics,
        session_data.terms,
        desired_config.max_iter,
        desired_config.convergence,
        desired_config.em_max_iter,
        desired_config.em_convergence,
        desired_config.init_alpha,
        desired_config.min_probability,
        random_seed,
    )
}

fn run_em_on_session_with_corpus(
    session_id: i64,
    document_words: Vec<Vec<usize>>,
    document_counts: Vec<Vec<f64>>,
    terms: usize,
    start: String,
    topics: usize,
    max_iter: i64,
    convergence: f64,
    em_max_iter: i64,
    em_convergence: f64,
    init_alpha: f64,
    min_probability: f64,
    random_seed: i64,
) -> (
    i64,
    Vec<Vec<f64>>,
    Vec<Vec<f64>>,
    Vec<Vec<f64>>,
    Vec<Vec<Vec<f64>>>,
) {
    if topics == 0 || terms == 0 {
        return empty_managed_session_em_output();
    }

    let active_session_id = ensure_corpus_session(
        session_id,
        document_words.as_slice(),
        document_counts.as_slice(),
        terms,
    );

    if active_session_id > 0 {
        let (beta_probabilities, beta_log, gamma, phi) = run_em_on_session(
            active_session_id,
            start.clone(),
            topics,
            max_iter,
            convergence,
            em_max_iter,
            em_convergence,
            init_alpha,
            min_probability,
            random_seed,
        );

        if !(beta_probabilities.is_empty()
            && beta_log.is_empty()
            && gamma.is_empty()
            && phi.is_empty())
        {
            return (active_session_id, beta_probabilities, beta_log, gamma, phi);
        }
    }

    let (beta_probabilities, beta_log, gamma, phi) = run_em_with_start_seed_internal(
        start.as_str(),
        document_words.as_slice(),
        document_counts.as_slice(),
        topics,
        terms,
        max_iter,
        convergence,
        em_max_iter,
        em_convergence,
        init_alpha,
        min_probability,
        random_seed,
    );

    if beta_probabilities.is_empty() && beta_log.is_empty() && gamma.is_empty() && phi.is_empty() {
        return empty_managed_session_em_output();
    }

    (active_session_id, beta_probabilities, beta_log, gamma, phi)
}

fn run_em_on_session_start(
    session_id: i64,
    start: String,
    random_seed: i64,
) -> (Vec<Vec<f64>>, Vec<Vec<f64>>, Vec<Vec<f64>>, Vec<Vec<Vec<f64>>>) {
    if session_id <= 0 {
        return empty_em_output();
    }

    let session_key = session_id as u64;
    let session_data = match corpus_sessions().lock() {
        Ok(sessions) => sessions.get(&session_key).map(|session| {
            (
                Arc::clone(&session.data),
                session.config.clone(),
            )
        }),
        Err(_) => None,
    };

    let Some((session_data, config)) = session_data else {
        return empty_em_output();
    };

    let Some(config) = config else {
        return empty_em_output();
    };

    run_em_with_start_seed_internal(
        start.as_str(),
        session_data.document_words.as_slice(),
        session_data.document_counts.as_slice(),
        config.topics,
        session_data.terms,
        config.max_iter,
        config.convergence,
        config.em_max_iter,
        config.em_convergence,
        config.init_alpha,
        config.min_probability,
        random_seed,
    )
}

fn infer_document_internal(
    beta_probabilities: &[Vec<f64>],
    gamma_initial: &[f64],
    words: &[usize],
    counts: &[f64],
    max_iter: i64,
    convergence: f64,
    min_probability: f64,
    init_alpha: f64,
) -> (Vec<f64>, Vec<Vec<f64>>) {
    let topics = gamma_initial.len().min(beta_probabilities.len());
    if topics == 0 {
        return (Vec::new(), Vec::new());
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

    let mut gamma_d = gamma_initial.iter().copied().take(topics).collect::<Vec<_>>();
    if gamma_d.len() < topics {
        gamma_d.resize(topics, init_alpha_value);
    }

    let mut phi_d = vec![vec![1.0 / topics as f64; topics]; words.len()];

    for _ in 0..max_iter_value {
        let mut gamma_next = vec![init_alpha_value; topics];

        for (word_offset, &word_index) in words.iter().enumerate() {
            let topic_weights = compute_topic_weights(beta_probabilities, &gamma_d, word_index, floor);
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

    (gamma_d, phi_d)
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
    let (gamma_d, phi_d) = infer_document_internal(
        beta_probabilities.as_slice(),
        gamma_initial.as_slice(),
        words.as_slice(),
        counts.as_slice(),
        max_iter,
        convergence,
        min_probability,
        init_alpha,
    );

    let mut output = Vec::with_capacity(phi_d.len() + 1);
    output.push(gamma_d);
    output.extend(phi_d);
    output
}

fn infer_corpus_iteration_internal(
    beta_probabilities: &[Vec<f64>],
    document_words: &[Vec<usize>],
    document_counts: &[Vec<f64>],
    max_iter: i64,
    convergence: f64,
    min_probability: f64,
    init_alpha: f64,
) -> (Vec<Vec<f64>>, Vec<Vec<Vec<f64>>>, Vec<Vec<f64>>) {
    let topics = beta_probabilities.len();
    if topics == 0 {
        return (Vec::new(), Vec::new(), Vec::new());
    }

    let terms = beta_probabilities
        .iter()
        .map(|row| row.len())
        .max()
        .unwrap_or(0);
    let floor = floor_value(min_probability);
    let init_alpha_value = if init_alpha.is_finite() { init_alpha } else { 0.3 };

    let mut topic_term_counts = vec![vec![floor; terms]; topics];
    let mut gamma_matrix = Vec::with_capacity(document_words.len());
    let mut phi_tensor = Vec::with_capacity(document_words.len());

    for (doc_index, words) in document_words.iter().enumerate() {
        let counts = document_counts.get(doc_index).cloned().unwrap_or_else(|| vec![0.0; words.len()]);
        let total: f64 = counts.iter().sum();
        let gamma_initial = vec![init_alpha_value + (total / topics as f64); topics];

        let (gamma_d, phi_d) = infer_document_internal(
            beta_probabilities,
            gamma_initial.as_slice(),
            words.as_slice(),
            counts.as_slice(),
            max_iter,
            convergence,
            min_probability,
            init_alpha,
        );

        accumulate_topic_term_counts_in_place(
            topic_term_counts.as_mut_slice(),
            phi_d.as_slice(),
            words.as_slice(),
            counts.as_slice(),
        );

        gamma_matrix.push(gamma_d);
        phi_tensor.push(phi_d);
    }

    (gamma_matrix, phi_tensor, topic_term_counts)
}

fn infer_corpus_iteration(
    beta_probabilities: Vec<Vec<f64>>,
    document_words: Vec<Vec<usize>>,
    document_counts: Vec<Vec<f64>>,
    max_iter: i64,
    convergence: f64,
    min_probability: f64,
    init_alpha: f64,
) -> (Vec<Vec<f64>>, Vec<Vec<Vec<f64>>>, Vec<Vec<f64>>) {
    infer_corpus_iteration_internal(
        beta_probabilities.as_slice(),
        document_words.as_slice(),
        document_counts.as_slice(),
        max_iter,
        convergence,
        min_probability,
        init_alpha,
    )
}

fn start_uses_seeded_initialization(start: &str) -> bool {
    let normalized = start.trim().to_ascii_lowercase();
    normalized == "seeded" || normalized == "deterministic"
}

fn start_uses_random_initialization(start: &str) -> bool {
    start.trim().eq_ignore_ascii_case("random")
}

fn run_em_internal(
    mut beta_probabilities: Vec<Vec<f64>>,
    document_words: &[Vec<usize>],
    document_counts: &[Vec<f64>],
    max_iter: i64,
    convergence: f64,
    em_max_iter: i64,
    em_convergence: f64,
    init_alpha: f64,
    min_probability: f64,
) -> (Vec<Vec<f64>>, Vec<Vec<f64>>, Vec<Vec<f64>>, Vec<Vec<Vec<f64>>>) {
    let em_max_iter_value = if em_max_iter <= 0 { 0 } else { em_max_iter as usize };
    let em_convergence_value = if em_convergence.is_finite() && em_convergence >= 0.0 {
        em_convergence
    } else {
        1.0e-4
    };

    let mut previous_gamma: Option<Vec<Vec<f64>>> = None;
    let mut beta_log: Vec<Vec<f64>> = Vec::new();
    let mut gamma: Vec<Vec<f64>> = Vec::new();
    let mut phi: Vec<Vec<Vec<f64>>> = Vec::new();

    for _ in 0..em_max_iter_value {
        let (current_gamma, current_phi, topic_term_counts) = infer_corpus_iteration_internal(
            beta_probabilities.as_slice(),
            document_words,
            document_counts,
            max_iter,
            convergence,
            min_probability,
            init_alpha,
        );

        let (next_beta_probabilities, next_beta_log) =
            normalize_topic_term_counts(topic_term_counts, min_probability);
        let should_stop = previous_gamma
            .as_ref()
            .map(|prev| {
                average_gamma_shift_internal(prev.as_slice(), current_gamma.as_slice())
                    <= em_convergence_value
            })
            .unwrap_or(false);

        beta_probabilities = next_beta_probabilities;
        beta_log = next_beta_log;
        gamma = current_gamma;
        phi = current_phi;

        if should_stop {
            break;
        }

        previous_gamma = Some(gamma.clone());
    }

    (beta_probabilities, beta_log, gamma, phi)
}

fn run_em(
    beta_probabilities: Vec<Vec<f64>>,
    document_words: Vec<Vec<usize>>,
    document_counts: Vec<Vec<f64>>,
    max_iter: i64,
    convergence: f64,
    em_max_iter: i64,
    em_convergence: f64,
    init_alpha: f64,
    min_probability: f64,
) -> (Vec<Vec<f64>>, Vec<Vec<f64>>, Vec<Vec<f64>>, Vec<Vec<Vec<f64>>>) {
    run_em_internal(
        beta_probabilities,
        document_words.as_slice(),
        document_counts.as_slice(),
        max_iter,
        convergence,
        em_max_iter,
        em_convergence,
        init_alpha,
        min_probability,
    )
}

fn run_em_with_start_internal(
    start: &str,
    document_words: &[Vec<usize>],
    document_counts: &[Vec<f64>],
    topics: usize,
    terms: usize,
    max_iter: i64,
    convergence: f64,
    em_max_iter: i64,
    em_convergence: f64,
    init_alpha: f64,
    min_probability: f64,
) -> (Vec<Vec<f64>>, Vec<Vec<f64>>, Vec<Vec<f64>>, Vec<Vec<Vec<f64>>>) {
    let initial_beta =
        if start_uses_seeded_initialization(start) || start_uses_random_initialization(start) {
            seeded_topic_term_probabilities_internal(
                document_words,
                document_counts,
                topics,
                terms,
                min_probability,
            )
        } else {
            // Unknown start modes default to seeded initialization for a stable fallback.
            seeded_topic_term_probabilities_internal(
                document_words,
                document_counts,
                topics,
                terms,
                min_probability,
            )
        };

    run_em_internal(
        initial_beta,
        document_words,
        document_counts,
        max_iter,
        convergence,
        em_max_iter,
        em_convergence,
        init_alpha,
        min_probability,
    )
}

fn run_em_with_start(
    start: String,
    document_words: Vec<Vec<usize>>,
    document_counts: Vec<Vec<f64>>,
    topics: usize,
    terms: usize,
    max_iter: i64,
    convergence: f64,
    em_max_iter: i64,
    em_convergence: f64,
    init_alpha: f64,
    min_probability: f64,
) -> (Vec<Vec<f64>>, Vec<Vec<f64>>, Vec<Vec<f64>>, Vec<Vec<Vec<f64>>>) {
    run_em_with_start_internal(
        start.as_str(),
        document_words.as_slice(),
        document_counts.as_slice(),
        topics,
        terms,
        max_iter,
        convergence,
        em_max_iter,
        em_convergence,
        init_alpha,
        min_probability,
    )
}

fn run_em_with_start_seed_internal(
    start: &str,
    document_words: &[Vec<usize>],
    document_counts: &[Vec<f64>],
    topics: usize,
    terms: usize,
    max_iter: i64,
    convergence: f64,
    em_max_iter: i64,
    em_convergence: f64,
    init_alpha: f64,
    min_probability: f64,
    random_seed: i64,
) -> (Vec<Vec<f64>>, Vec<Vec<f64>>, Vec<Vec<f64>>, Vec<Vec<Vec<f64>>>) {
    let initial_beta = if start_uses_seeded_initialization(start) {
        seeded_topic_term_probabilities_internal(
            document_words,
            document_counts,
            topics,
            terms,
            min_probability,
        )
    } else if start_uses_random_initialization(start) {
        random_topic_term_probabilities(topics, terms, min_probability, random_seed)
    } else {
        // Unknown start modes follow Ruby's non-seeded fallback behavior.
        random_topic_term_probabilities(topics, terms, min_probability, random_seed)
    };

    run_em_internal(
        initial_beta,
        document_words,
        document_counts,
        max_iter,
        convergence,
        em_max_iter,
        em_convergence,
        init_alpha,
        min_probability,
    )
}

fn run_em_with_start_seed(
    start: String,
    document_words: Vec<Vec<usize>>,
    document_counts: Vec<Vec<f64>>,
    topics: usize,
    terms: usize,
    max_iter: i64,
    convergence: f64,
    em_max_iter: i64,
    em_convergence: f64,
    init_alpha: f64,
    min_probability: f64,
    random_seed: i64,
) -> (Vec<Vec<f64>>, Vec<Vec<f64>>, Vec<Vec<f64>>, Vec<Vec<Vec<f64>>>) {
    run_em_with_start_seed_internal(
        start.as_str(),
        document_words.as_slice(),
        document_counts.as_slice(),
        topics,
        terms,
        max_iter,
        convergence,
        em_max_iter,
        em_convergence,
        init_alpha,
        min_probability,
        random_seed,
    )
}

#[magnus::init]
fn init() -> Result<(), Error> {
    let lda_module = define_module("Lda")?;
    let rust_backend_module = lda_module.define_module("RustBackend")?;

    rust_backend_module.define_singleton_method("available?", function!(available, 0))?;
    rust_backend_module.define_singleton_method("abi_version", function!(abi_version, 0))?;
    rust_backend_module.define_singleton_method("corpus_session_count", function!(corpus_session_count, 0))?;
    rust_backend_module.define_singleton_method("corpus_session_exists", function!(corpus_session_exists, 1))?;
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
    rust_backend_module.define_singleton_method(
        "infer_corpus_iteration",
        function!(infer_corpus_iteration, 7),
    )?;
    rust_backend_module.define_singleton_method(
        "normalize_topic_term_counts",
        function!(normalize_topic_term_counts, 2),
    )?;
    rust_backend_module
        .define_singleton_method("average_gamma_shift", function!(average_gamma_shift, 2))?;
    rust_backend_module.define_singleton_method(
        "topic_document_probability",
        function!(topic_document_probability, 4),
    )?;
    rust_backend_module.define_singleton_method(
        "seeded_topic_term_probabilities",
        function!(seeded_topic_term_probabilities, 5),
    )?;
    rust_backend_module.define_singleton_method(
        "random_topic_term_probabilities",
        function!(random_topic_term_probabilities, 4),
    )?;
    rust_backend_module
        .define_singleton_method("create_corpus_session", function!(create_corpus_session, 3))?;
    rust_backend_module
        .define_singleton_method("replace_corpus_session", function!(replace_corpus_session, 4))?;
    rust_backend_module
        .define_singleton_method("drop_corpus_session", function!(drop_corpus_session, 1))?;
    rust_backend_module
        .define_singleton_method("configure_corpus_session", function!(configure_corpus_session, 8))?;
    rust_backend_module.define_singleton_method("run_em", function!(run_em, 9))?;
    rust_backend_module
        .define_singleton_method("run_em_with_start", function!(run_em_with_start, 11))?;
    rust_backend_module
        .define_singleton_method("run_em_with_start_seed", function!(run_em_with_start_seed, 12))?;
    rust_backend_module.define_singleton_method(
        "run_em_on_session_with_start_seed",
        function!(run_em_on_session_with_start_seed, 10),
    )?;
    rust_backend_module.define_singleton_method("run_em_on_session", function!(run_em_on_session, 10))?;
    rust_backend_module
        .define_singleton_method("run_em_on_session_with_corpus", function!(run_em_on_session_with_corpus, 13))?;
    rust_backend_module
        .define_singleton_method("run_em_on_session_start", function!(run_em_on_session_start, 3))?;

    Ok(())
}
