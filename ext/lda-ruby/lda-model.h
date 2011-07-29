#ifndef LDA_MODEL_H
#define LDA_MODEL

#include <stdlib.h>
#include <stdio.h>
#include <math.h>
#include "lda.h"
#include "lda-alpha.h"
#include "cokus.h"

#define myrand() (double) (((unsigned long) randomMT()) / 4294967296.)
#define NUM_INIT 1
#define MIN(A,B) (int)((A > B) ? (B) : (A))

void free_lda_model(lda_model*);
void save_lda_model(lda_model*, char*);
lda_model* new_lda_model(int, int);
lda_model* quiet_new_lda_model(int num_terms, int num_topics);
lda_model* new_lda_model(int num_terms, int num_topics);
lda_suffstats* new_lda_suffstats(lda_model* model);
void free_lda_suffstats(lda_model* model, lda_suffstats* ss);
void corpus_initialize_ss(lda_suffstats* ss, lda_model* model, corpus* c);
void quiet_corpus_initialize_ss(lda_suffstats* ss, lda_model* model, corpus* c);
void corpus_initialize_fixed_ss(lda_suffstats* ss, lda_model* model, corpus* c);
void random_initialize_ss(lda_suffstats* ss, lda_model* model);
void zero_initialize_ss(lda_suffstats* ss, lda_model* model);
void lda_mle(lda_model* model, lda_suffstats* ss, int estimate_alpha);
void quiet_lda_mle(lda_model* model, lda_suffstats* ss, int estimate_alpha);
lda_model* load_lda_model(char* model_root);

#endif
