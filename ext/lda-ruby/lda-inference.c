// (C) Copyright 2004, David M. Blei (blei [at] cs [dot] cmu [dot] edu)

// This file is part of LDA-C.

// LDA-C is free software; you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free
// Software Foundation; either version 2 of the License, or (at your
// option) any later version.

// LDA-C is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
// for more details.

// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307
// USA

#include <stdlib.h>
#include <stdio.h>
#include <math.h>
#include <float.h>
#include <string.h>
#include <time.h>

#include "lda.h"
#include "lda-data.h"
#include "lda-inference.h"
#include "lda-model.h"
#include "utils.h"
#include "cokus.h"

#ifdef USE_RUBY
#include "ruby.h"

VALUE rb_cLdaModule;
VALUE rb_cLda;
VALUE rb_cLdaCorpus;
VALUE rb_cLdaDocument;
#endif



/*
 * variational inference
 */

double lda_inference(document* doc, lda_model* model, double* var_gamma, double** phi, short* errors) {
	double converged = 1;
	double phisum = 0, likelihood = 0;
	double likelihood_old = 0, oldphi[model->num_topics];
	int k = 0, n = 0, var_iter = 0, index = 0;
	double digamma_gam[model->num_topics];

  /* zero'em out */
  memset(digamma_gam,0.0,sizeof(digamma_gam));
  memset(oldphi,0.0,sizeof(oldphi));

		// compute posterior dirichlet

	for (k = 0; k < model->num_topics; k++)
	{
		var_gamma[k] = model->alpha + (doc->total/((double) model->num_topics));
		digamma_gam[k] = digamma(var_gamma[k]);
		for (n = 0; n < doc->length; n++)
			phi[n][k] = 1.0/model->num_topics;
	}
	var_iter = 0;

	while ((converged > VAR_CONVERGED) &&
		((var_iter < VAR_MAX_ITER) || (VAR_MAX_ITER == -1)))
	{
		var_iter++;
		for (n = 0; n < doc->length; n++)
		{
			phisum = 0;
			for (k = 0; k < model->num_topics; k++)
			{
				oldphi[k] = phi[n][k];
        index = doc->words[n];
        if( index < 0 || index > model->num_terms ) {
          printf("phi for term: %d of %d\n", index, model->num_terms);
				  phi[n][k] = 0.0;
        }
        else {
				  phi[n][k] =
				  	digamma_gam[k] +
				  	model->log_prob_w[k][index];
        }

				if (k > 0)
					phisum = log_sum(phisum, phi[n][k]);
				else
					phisum = phi[n][k]; // note, phi is in log space
			}

			for (k = 0; k < model->num_topics; k++)
			{
				phi[n][k] = exp(phi[n][k] - phisum);
				var_gamma[k] =
					var_gamma[k] + doc->counts[n]*(phi[n][k] - oldphi[k]);
								// !!! a lot of extra digamma's here because of how we're computing it
								// !!! but its more automatically updated too.
				digamma_gam[k] = digamma(var_gamma[k]);
			}
		}

		likelihood = compute_likelihood(doc, model, phi, var_gamma);
		//assert(!isnan(likelihood));
    if( isnan(likelihood) ) { *errors = 1; }
		converged = (likelihood_old - likelihood) / likelihood_old;
		likelihood_old = likelihood;

				// printf("[LDA INF] %8.5f %1.3e\n", likelihood, converged);
	}
	return(likelihood);
}


/*
 * compute likelihood bound
 */

double compute_likelihood(document* doc, lda_model* model, double** phi, double* var_gamma) {
	double likelihood = 0, digsum = 0, var_gamma_sum = 0, dig[model->num_topics];
	int k = 0, n = 0, index = 0;
  memset(dig,0.0,sizeof(dig));

	for (k = 0; k < model->num_topics; k++)
	{
		dig[k] = digamma(var_gamma[k]);
		var_gamma_sum += var_gamma[k];
	}
	digsum = digamma(var_gamma_sum);

	likelihood = lgamma(model->alpha * model->num_topics) -
               model->num_topics *
               lgamma(model->alpha) -
               lgamma(var_gamma_sum);

	for (k = 0; k < model->num_topics; k++)
	{
		likelihood += (model->alpha - 1)*(dig[k] - digsum) + lgamma(var_gamma[k]) - (var_gamma[k] - 1)*(dig[k] - digsum);

		for (n = 0; n < doc->length; n++)
		{
			if (phi[n][k] > 0)
			{
        index = doc->words[n];
				likelihood += doc->counts[n]*
					(phi[n][k]*((dig[k] - digsum) - log(phi[n][k])
					+ model->log_prob_w[k][index]));
			}
		}
	}
	return(likelihood);
}


double doc_e_step(document* doc, double* gamma, double** phi, lda_model* model, lda_suffstats* ss) {
	double likelihood;
	int n, k;
  short error = 0;

  // posterior inference

	likelihood = lda_inference(doc, model, gamma, phi, &error);
  if (error) { likelihood = 0.0; }


		// update sufficient statistics

	double gamma_sum = 0;
	for (k = 0; k < model->num_topics; k++)
	{
		gamma_sum += gamma[k];
		ss->alpha_suffstats += digamma(gamma[k]);
	}
	ss->alpha_suffstats -= model->num_topics * digamma(gamma_sum);

	for (n = 0; n < doc->length; n++)
	{
		for (k = 0; k < model->num_topics; k++)
		{
			ss->class_word[k][doc->words[n]] += doc->counts[n]*phi[n][k];
			ss->class_total[k] += doc->counts[n]*phi[n][k];
		}
	}

	ss->num_docs = ss->num_docs + 1;

	return(likelihood);
}


/*
 * writes the word assignments line for a document to a file
 */

void write_word_assignment(FILE* f, document* doc, double** phi, lda_model* model) {
	int n;

	fprintf(f, "%03d", doc->length);
	for (n = 0; n < doc->length; n++) {
		fprintf(f, " %04d:%02d", doc->words[n], argmax(phi[n], model->num_topics));
	}
	fprintf(f, "\n");
	fflush(f);
}


/*
 * saves the gamma parameters of the current dataset
 */

void save_gamma(char* filename, double** gamma, int num_docs, int num_topics) {
	FILE* fileptr;
	int d, k;
	fileptr = fopen(filename, "w");

	for (d = 0; d < num_docs; d++) {
		fprintf(fileptr, "%5.10f", gamma[d][0]);
		for (k = 1; k < num_topics; k++) {
			fprintf(fileptr, " %5.10f", gamma[d][k]);
		}
		fprintf(fileptr, "\n");
	}
	fclose(fileptr);
}


void run_em(char* start, char* directory, corpus* corpus) {
	int d, n;
	lda_model *model = NULL;
	double **var_gamma, **phi;

	// allocate variational parameters


	var_gamma = malloc(sizeof(double*)*(corpus->num_docs));
	for (d = 0; d < corpus->num_docs; d++)
		var_gamma[d] = malloc(sizeof(double) * NTOPICS);

	int max_length = max_corpus_length(corpus);
	phi = malloc(sizeof(double*)*max_length);
	for (n = 0; n < max_length; n++)
		phi[n] = malloc(sizeof(double) * NTOPICS);

	// initialize model

	char filename[100];

	lda_suffstats* ss = NULL;
	if (strcmp(start, "seeded")==0) {
		model = new_lda_model(corpus->num_terms, NTOPICS);
		ss = new_lda_suffstats(model);
		corpus_initialize_ss(ss, model, corpus);
		if (VERBOSE) {
		    lda_mle(model, ss, 0);
	    } else {
            quiet_lda_mle(model, ss, 0);
	    }

		model->alpha = INITIAL_ALPHA;
	} else if (strcmp(start, "random")==0) {
		model = new_lda_model(corpus->num_terms, NTOPICS);
		ss = new_lda_suffstats(model);
		random_initialize_ss(ss, model);
		if (VERBOSE) {
		    lda_mle(model, ss, 0);
	    } else {
	        quiet_lda_mle(model, ss, 0);
	    }
		model->alpha = INITIAL_ALPHA;
	} else {
		model = load_lda_model(start);
		ss = new_lda_suffstats(model);
	}

	sprintf(filename,"%s/000",directory);
	save_lda_model(model, filename);

	// run expectation maximization

	int i = 0;
	double likelihood, likelihood_old = 0, converged = 1;
	sprintf(filename, "%s/likelihood.dat", directory);
	FILE* likelihood_file = fopen(filename, "w");

	while (((converged < 0) || (converged > EM_CONVERGED) || (i <= 2)) && (i <= EM_MAX_ITER)) {
		i++;
		if (VERBOSE)
		    printf("**** em iteration %d ****\n", i);
		likelihood = 0;
		zero_initialize_ss(ss, model);

		// e-step
    printf("e-step\n");

		for (d = 0; d < corpus->num_docs; d++) {
			if ((d % 1000) == 0 && VERBOSE) printf("document %d\n",d);
			likelihood += doc_e_step(&(corpus->docs[d]), var_gamma[d], phi, model, ss);
		}
    printf("m-step\n");

		// m-step
    if (VERBOSE) {
      lda_mle(model, ss, ESTIMATE_ALPHA);
    } else {
      quiet_lda_mle(model, ss, ESTIMATE_ALPHA);
    }

		// check for convergence
		converged = (likelihood_old - likelihood) / (likelihood_old);
		if (converged < 0) VAR_MAX_ITER = VAR_MAX_ITER * 2;
		likelihood_old = likelihood;

		// output model and likelihood

		fprintf(likelihood_file, "%10.10f\t%5.5e\n", likelihood, converged);
		fflush(likelihood_file);
		if ((i % LAG) == 0)
		{
			sprintf(filename,"%s/%03d",directory, i);
			save_lda_model(model, filename);
			sprintf(filename,"%s/%03d.gamma",directory, i);
			save_gamma(filename, var_gamma, corpus->num_docs, model->num_topics);
		}
	}

		// output the final model

	sprintf(filename,"%s/final",directory);
	save_lda_model(model, filename);
	sprintf(filename,"%s/final.gamma",directory);
	save_gamma(filename, var_gamma, corpus->num_docs, model->num_topics);

		// output the word assignments (for visualization)

	sprintf(filename, "%s/word-assignments.dat", directory);
	FILE* w_asgn_file = fopen(filename, "w");
  short error = 0;
  double tl = 0.0;
	for (d = 0; d < corpus->num_docs; d++)
	{
		if ((d % 100) == 0 && VERBOSE) printf("final e step document %d\n",d);
    error = 0;
    tl = lda_inference(&(corpus->docs[d]), model, var_gamma[d], phi,&error);
    if( error ) { continue; }
		likelihood += tl;
		write_word_assignment(w_asgn_file, &(corpus->docs[d]), phi, model);
	}
	fclose(w_asgn_file);
	fclose(likelihood_file);
}


/*
 * read settings.
 */

void read_settings(char* filename) {
	FILE* fileptr;
	char alpha_action[100];
	fileptr = fopen(filename, "r");
	fscanf(fileptr, "var max iter %d\n", &VAR_MAX_ITER);
	fscanf(fileptr, "var convergence %f\n", &VAR_CONVERGED);
	fscanf(fileptr, "em max iter %d\n", &EM_MAX_ITER);
	fscanf(fileptr, "em convergence %f\n", &EM_CONVERGED);
	fscanf(fileptr, "alpha %s", alpha_action);
	if (strcmp(alpha_action, "fixed")==0)
	{
		ESTIMATE_ALPHA = 0;
	}
	else
	{
		ESTIMATE_ALPHA = 1;
	}
	fclose(fileptr);
}




/*
* inference only
	*
*/

void infer(char* model_root, char* save, corpus* corpus) {
	FILE* fileptr;
	char filename[100];
	int i, d, n;
	lda_model *model;
	double **var_gamma, likelihood, **phi;
	document* doc;

	model = load_lda_model(model_root);
	var_gamma = malloc(sizeof(double*)*(corpus->num_docs));
	for (i = 0; i < corpus->num_docs; i++)
		var_gamma[i] = malloc(sizeof(double)*model->num_topics);
	sprintf(filename, "%s-lda-lhood.dat", save);
	fileptr = fopen(filename, "w");
	for (d = 0; d < corpus->num_docs; d++) {
		if (((d % 100) == 0) && (d>0) && VERBOSE) printf("document %d\n",d);

		doc = &(corpus->docs[d]);
		phi = (double**) malloc(sizeof(double*) * doc->length);
		for (n = 0; n < doc->length; n++)
			phi[n] = (double*) malloc(sizeof(double) * model->num_topics);
    short error = 0;
		likelihood = lda_inference(doc, model, var_gamma[d], phi, &error);

		fprintf(fileptr, "%5.5f\n", likelihood);
	}
	fclose(fileptr);
	sprintf(filename, "%s-gamma.dat", save);
	save_gamma(filename, var_gamma, corpus->num_docs, model->num_topics);
}


/*
 * update sufficient statistics
 *
 */



/*
 * main
 *
 */

int main(int argc, char* argv[]) {
	corpus* corpus;

	long t1;
	(void) time(&t1);
	seedMT(t1);
		// seedMT(4357U);

	if (argc > 1)
	{
		if (strcmp(argv[1], "est")==0)
		{
			INITIAL_ALPHA = atof(argv[2]);
			NTOPICS = atoi(argv[3]);
			read_settings(argv[4]);
			corpus = read_data(argv[5]);
			make_directory(argv[7]);
			run_em(argv[6], argv[7], corpus);
		}
		if (strcmp(argv[1], "inf")==0)
		{
			read_settings(argv[2]);
			corpus = read_data(argv[4]);
			infer(argv[3], argv[5], corpus);
		}
	}
	else
	{
		printf("usage : lda est [initial alpha] [k] [settings] [data] [random/seeded/*] [directory]\n");
		printf("        lda inf [settings] [model] [data] [name]\n");
	}
	return(0);
}

#ifdef USE_RUBY

/* */
void run_quiet_em(char* start, corpus* corpus) {
	int d = 0, n = 0;
	lda_model *model = NULL;
	double **var_gamma = NULL, **phi = NULL;
	// last_gamma is a double[num_docs][num_topics]

	// allocate variational parameters


	var_gamma = (double**)malloc(sizeof(double*)*(corpus->num_docs));
  memset(var_gamma, 0.0, corpus->num_docs);

	for (d = 0; d < corpus->num_docs; ++d) {
		var_gamma[d] = (double*)malloc(sizeof(double) * NTOPICS);
    memset(var_gamma[d], 0.0, sizeof(double)*NTOPICS);
  }

	int max_length = max_corpus_length(corpus);

	phi = (double**)malloc(sizeof(double*)*max_length);
  memset(phi, 0.0, max_length);
	for (n = 0; n < max_length; ++n) {
		phi[n] = (double*)malloc(sizeof(double) * NTOPICS);
    memset(phi[n], 0.0, sizeof(double)*NTOPICS);
  }

	// initialize model

	lda_suffstats* ss = NULL;
	if (strncmp(start, "seeded",6)==0) {
		model = quiet_new_lda_model(corpus->num_terms, NTOPICS);
		model->alpha = INITIAL_ALPHA;
		ss = new_lda_suffstats(model);
		if (VERBOSE) {
      corpus_initialize_ss(ss, model, corpus);
    } else {
      quiet_corpus_initialize_ss(ss, model, corpus);
    }
		if (VERBOSE) {
      lda_mle(model, ss, 0);
		} else {
      quiet_lda_mle(model, ss, 0);
		}
	} else if (strncmp(start, "fixed",5)==0) {
	  model = quiet_new_lda_model(corpus->num_terms, NTOPICS);
    model->alpha = INITIAL_ALPHA;
	  ss = new_lda_suffstats(model);
	  corpus_initialize_fixed_ss(ss, model, corpus);
    if (VERBOSE) {
      lda_mle(model, ss, 0);
    } else {
      quiet_lda_mle(model, ss, 0);
    }
	} else if (strncmp(start, "random",6)==0) {
		model = quiet_new_lda_model(corpus->num_terms, NTOPICS);
		model->alpha = INITIAL_ALPHA;
		ss = new_lda_suffstats(model);
		random_initialize_ss(ss, model);
		if (VERBOSE) {
      lda_mle(model, ss, 0);
		} else {
      quiet_lda_mle(model, ss, 0);
		}
	} else {
		model = load_lda_model(start);
		ss = new_lda_suffstats(model);
	}

	// save the model in the last_model global
	last_model = model;
	model_loaded = TRUE;

	// run expectation maximization

	int i = 0;
	double likelihood = 0.0, likelihood_old = 0, converged = 1;

	while (((converged < 0) || (converged > EM_CONVERGED) || (i <= 2)) && (i <= EM_MAX_ITER)) {
		i++;
		if (VERBOSE) printf("**** em iteration %d ****\n", i);
		likelihood = 0;
		zero_initialize_ss(ss, model);

		// e-step

		for (d = 0; d < corpus->num_docs; d++) {
			if ((d % 1000) == 0 && VERBOSE) printf("document %d\n",d);
			likelihood += doc_e_step(&(corpus->docs[d]), var_gamma[d], phi, model, ss);
		}

		// m-step
    if (VERBOSE) {
      lda_mle(model, ss, ESTIMATE_ALPHA);
    } else {
      quiet_lda_mle(model, ss, ESTIMATE_ALPHA);
    }

		// check for convergence

		converged = (likelihood_old - likelihood) / (likelihood_old);
		if (converged < 0) VAR_MAX_ITER = VAR_MAX_ITER * 2;
		likelihood_old = likelihood;

		// store model and likelihood

		last_model = model;
		last_gamma = var_gamma;
    last_phi = phi;
	}

	// output the final model

	last_model = model;
	last_gamma = var_gamma;
  last_phi = phi;

  free_lda_suffstats(model,ss);

	// output the word assignments (for visualization)
	/*
	char filename[100];
	sprintf(filename, "%s/word-assignments.dat", directory);
	FILE* w_asgn_file = fopen(filename, "w");
	for (d = 0; d < corpus->num_docs; d++) {
		if ((d % 100) == 0)
			printf("final e step document %d\n",d);
		likelihood += lda_inference(&(corpus->docs[d]), model, var_gamma[d], phi);
		write_word_assignment(w_asgn_file, &(corpus->docs[d]), phi, model);
	}
	fclose(w_asgn_file);
	*/
}


/*
 * Set all of the settings in one command:
 *
 *  * init_alpha
 *  * num_topics
 *  * max_iter
 *  * convergence
 *  * em_max_iter
 *  * em_convergence
 *  * est_alpha
 */
static VALUE wrap_set_config(VALUE self, VALUE init_alpha, VALUE num_topics, VALUE max_iter, VALUE convergence, VALUE em_max_iter, VALUE em_convergence, VALUE est_alpha) {
	INITIAL_ALPHA = NUM2DBL(init_alpha);
	NTOPICS = NUM2INT(num_topics);
  if( NTOPICS < 0 ) { rb_raise(rb_eRuntimeError, "NTOPICS must be greater than 0 - %d", NTOPICS); }
	VAR_MAX_ITER = NUM2INT(max_iter);
	VAR_CONVERGED = (float)NUM2DBL(convergence);
	EM_MAX_ITER = NUM2INT(em_max_iter);
	EM_CONVERGED = (float)NUM2DBL(em_convergence);
	ESTIMATE_ALPHA = NUM2INT(est_alpha);

	return Qtrue;
}

/*
 * Get the maximum iterations.
 */
static VALUE wrap_get_max_iter(VALUE self) {
	return rb_int_new(VAR_MAX_ITER);
}

/*
 * Set the maximum iterations.
 */
static VALUE wrap_set_max_iter(VALUE self, VALUE max_iter) {
	VAR_MAX_ITER = NUM2INT(max_iter);

	return max_iter;
}

/*
 * Get the convergence setting.
 */
static VALUE wrap_get_converged(VALUE self) {
	return rb_float_new(VAR_CONVERGED);
}

/*
 * Set the convergence setting.
 */
static VALUE wrap_set_converged(VALUE self, VALUE converged) {
	VAR_CONVERGED = (float)NUM2DBL(converged);

	return converged;
}

/*
 * Get the max iterations for the EM algorithm.
 */
static VALUE wrap_get_em_max_iter(VALUE self) {
	return rb_int_new(EM_MAX_ITER);
}

/*
 * Set the max iterations for the EM algorithm.
 */
static VALUE wrap_set_em_max_iter(VALUE self, VALUE em_max_iter) {
	EM_MAX_ITER = NUM2INT(em_max_iter);

	return em_max_iter;
}

/*
 * Get the convergence value for EM.
 */
static VALUE wrap_get_em_converged(VALUE self) {
	return rb_float_new(EM_CONVERGED);
}

/*
 * Set the convergence value for EM.
 */
static VALUE wrap_set_em_converged(VALUE self, VALUE em_converged) {
	EM_CONVERGED = (float)NUM2DBL(em_converged);

	return em_converged;
}

/*
 * Get the initial alpha value.
 */
static VALUE wrap_get_initial_alpha(VALUE self) {
	return rb_float_new(INITIAL_ALPHA);
}

/*
 * Get the number of topics being clustered.
 */
static VALUE wrap_get_num_topics(VALUE self) {
	return rb_int_new(NTOPICS);
}

/*
 * Set the initial value of alpha.
 */
static VALUE wrap_set_initial_alpha(VALUE self, VALUE initial_alpha) {
	INITIAL_ALPHA = (float)NUM2DBL(initial_alpha);

	return initial_alpha;
}

/*
 * Set the number of topics to be clustered.
 */
static VALUE wrap_set_num_topics(VALUE self, VALUE ntopics) {
	NTOPICS = NUM2INT(ntopics);

	return ntopics;
}

/*
 * Get the estimate alpha value (fixed = 0).
 */
static VALUE wrap_get_estimate_alpha(VALUE self) {
	return rb_int_new(ESTIMATE_ALPHA);
}

/*
 * Set the estimate alpha value (fixed = 0).
 */
static VALUE wrap_set_estimate_alpha(VALUE self, VALUE est_alpha) {
	ESTIMATE_ALPHA = NUM2INT(est_alpha);

	return est_alpha;
}

/*
 * Get the verbosity setting.
 */
static VALUE wrap_get_verbosity(VALUE self) {
    if (VERBOSE) {
        return Qtrue;
    } else {
        return Qfalse;
    }
}


/*
 * Set the verbosity level (true, false).
 */
static VALUE wrap_set_verbosity(VALUE self, VALUE verbosity) {
    if (verbosity == Qtrue) {
        VERBOSE = TRUE;
    } else {
        VERBOSE = FALSE;
    }

    return verbosity;
}



/*
 * Run the EM algorithm with the loaded corpus and using the current
 * configuration settings.  The +start+ parameter can take the following
 * values:
 *  * random - starting alpha are randomized
 *  * seeded - loaded based on the corpus values
 *  * <filename> - path to the file containing the model
 */
static VALUE wrap_em(VALUE self, VALUE start) {
	if (!corpus_loaded)
		return Qnil;

	run_quiet_em(StringValuePtr(start), last_corpus);

	return Qnil;
}


/*
 * Load settings from the given file.
 */
static VALUE wrap_load_settings(VALUE self, VALUE settings_file) {
	read_settings(StringValuePtr(settings_file));

	return Qtrue;
}

/*
 * Load the corpus from the given file.  This will not create
 * a +Corpus+ object that is accessible, but it will load the corpus
 * much faster.
 */
static VALUE wrap_load_corpus(VALUE self, VALUE filename) {
	if (!corpus_loaded) {
		last_corpus = read_data(StringValuePtr(filename));
		corpus_loaded = TRUE;
		return Qtrue;
	} else {
		return Qtrue;
	}
}

/*
 * Set the corpus.
 */
static VALUE wrap_ruby_corpus(VALUE self, VALUE rcorpus) {
	corpus* c;
	int i = 0;
	int j = 0;

	c = malloc(sizeof(corpus));
	c->num_terms = NUM2INT(rb_iv_get(rcorpus, "@num_terms"));
	c->num_docs = NUM2INT(rb_iv_get(rcorpus, "@num_docs"));
	c->docs = (document*) malloc(sizeof(document) * c->num_docs);
	VALUE doc_ary = rb_iv_get(rcorpus, "@documents");
	for (i = 0; i < c->num_docs; i++) {
		VALUE one_doc = rb_ary_entry(doc_ary, i);
		VALUE words = rb_iv_get(one_doc, "@words");
		VALUE counts = rb_iv_get(one_doc, "@counts");

		c->docs[i].length = NUM2INT(rb_iv_get(one_doc, "@length"));
		c->docs[i].total = NUM2INT(rb_iv_get(one_doc, "@total"));
		c->docs[i].words = malloc(sizeof(int) * c->docs[i].length);
		c->docs[i].counts = malloc(sizeof(int) * c->docs[i].length);
		for (j = 0; j < c->docs[i].length; j++) {
			int one_word = NUM2INT(rb_ary_entry(words, j));
			int one_count = NUM2INT(rb_ary_entry(counts, j));
      if( one_word > c->num_terms ) {
        rb_raise(rb_eRuntimeError, "error term count(%d) less than word index(%d)", c->num_terms, one_word);
      }
			c->docs[i].words[j] = one_word;
			c->docs[i].counts[j] = one_count;
		}
	}

	last_corpus = c;
	corpus_loaded = TRUE;

	rb_iv_set(self, "@corpus", rcorpus);

	return Qtrue;
}


/*
 * Get the gamma values after the model has been run.
 */
static VALUE wrap_get_gamma(VALUE self) {
	if (!model_loaded)
		return Qnil;

	// last_gamma is a double[num_docs][num_topics]
	VALUE arr;
	int i = 0, j = 0;

	arr = rb_ary_new2(last_corpus->num_docs);
	for (i = 0; i < last_corpus->num_docs; i++) {
		VALUE arr2 = rb_ary_new2(last_model->num_topics);
		for (j = 0; j < last_model->num_topics; j++) {
			rb_ary_store(arr2, j, rb_float_new(last_gamma[i][j]));
		}
		rb_ary_store(arr, i, arr2);
	}

	return arr;
}


/*
 * Compute the phi values by running inference after the initial EM run has been completed.
 *
 * Returns a 3D matrix:  <tt>num_docs x length x num_topics</tt>.
 */
static VALUE wrap_get_phi(VALUE self) {
    if (!model_loaded)
        return Qnil;

    VALUE arr = rb_ary_new2(last_corpus->num_docs);
    int i = 0, j = 0, k = 0;

    //int max_length = max_corpus_length(last_corpus);
    short error = 0;

    for (i = 0; i < last_corpus->num_docs; i++) {
        VALUE arr1 = rb_ary_new2(last_corpus->docs[i].length);

        lda_inference(&(last_corpus->docs[i]), last_model, last_gamma[i], last_phi, &error);

        for (j = 0; j < last_corpus->docs[i].length; j++) {
            VALUE arr2 = rb_ary_new2(last_model->num_topics);

            for (k = 0; k < last_model->num_topics; k++) {
                rb_ary_store(arr2, k, rb_float_new(last_phi[j][k]));
            }

            rb_ary_store(arr1, j, arr2);
        }

        rb_ary_store(arr, i, arr1);
    }

    return arr;
}



/*
 * Get the beta matrix after the model has been run.
 */
static VALUE wrap_get_model_beta(VALUE self) {
	if (!model_loaded)
		return Qnil;

	// beta is a double[num_topics][num_terms]
	VALUE arr;
	int i = 0, j = 0;

	arr = rb_ary_new2(last_model->num_topics);
	for (i = 0; i < last_model->num_topics; i++) {
		VALUE arr2 = rb_ary_new2(last_model->num_terms);
		for (j = 0; j < last_model->num_terms; j++) {
			rb_ary_store(arr2, j, rb_float_new(last_model->log_prob_w[i][j]));
		}
		rb_ary_store(arr, i, arr2);
	}

	return arr;
}


/*
 * Get the settings used for the model.
 */
static VALUE wrap_get_model_settings(VALUE self) {
	if (!model_loaded)
		return Qnil;

	VALUE arr;

	arr = rb_ary_new();
	rb_ary_push(arr, rb_int_new(last_model->num_topics));
	rb_ary_push(arr, rb_int_new(last_model->num_terms));
	rb_ary_push(arr, rb_float_new(last_model->alpha));

	return arr;		//	[num_topics, num_terms, alpha]
}


void Init_lda() {
  corpus_loaded = FALSE;
  model_loaded = FALSE;
  VERBOSE = TRUE;

  rb_require("lda-ruby");

  rb_cLdaModule   = rb_define_module("Lda");
  rb_cLda         = rb_define_class_under(rb_cLdaModule, "Lda", rb_cObject);
  rb_cLdaCorpus   = rb_define_class_under(rb_cLdaModule, "Corpus", rb_cObject);
  rb_cLdaDocument = rb_define_class_under(rb_cLdaModule, "Document", rb_cObject);

  // method to load the corpus
  rb_define_method(rb_cLda, "fast_load_corpus_from_file", wrap_load_corpus, 1);
  rb_define_method(rb_cLda, "corpus=", wrap_ruby_corpus, 1);

  // method to run em
  rb_define_method(rb_cLda, "em", wrap_em, 1);

  // method to load settings from file
  rb_define_method(rb_cLda, "load_settings", wrap_load_settings, 1);

  // method to set all the config options at once
  rb_define_method(rb_cLda, "set_config", wrap_set_config, 5);

  // accessor stuff for main settings
  rb_define_method(rb_cLda, "max_iter", wrap_get_max_iter, 0);
  rb_define_method(rb_cLda, "max_iter=", wrap_set_max_iter, 1);
  rb_define_method(rb_cLda, "convergence", wrap_get_converged, 0);
  rb_define_method(rb_cLda, "convergence=", wrap_set_converged, 1);
  rb_define_method(rb_cLda, "em_max_iter", wrap_get_em_max_iter, 0);
  rb_define_method(rb_cLda, "em_max_iter=", wrap_set_em_max_iter, 1);
  rb_define_method(rb_cLda, "em_convergence", wrap_get_em_converged, 0);
  rb_define_method(rb_cLda, "em_convergence=", wrap_set_em_converged, 1);
  rb_define_method(rb_cLda, "init_alpha=", wrap_set_initial_alpha, 1);
  rb_define_method(rb_cLda, "init_alpha", wrap_get_initial_alpha, 0);
  rb_define_method(rb_cLda, "est_alpha=", wrap_set_estimate_alpha, 1);
  rb_define_method(rb_cLda, "est_alpha", wrap_get_estimate_alpha, 0);
  rb_define_method(rb_cLda, "num_topics", wrap_get_num_topics, 0);
  rb_define_method(rb_cLda, "num_topics=", wrap_set_num_topics, 1);
  rb_define_method(rb_cLda, "verbose", wrap_get_verbosity, 0);
  rb_define_method(rb_cLda, "verbose=", wrap_set_verbosity, 1);

  // retrieve model and gamma
  rb_define_method(rb_cLda, "beta", wrap_get_model_beta, 0);
  rb_define_method(rb_cLda, "gamma", wrap_get_gamma, 0);
  rb_define_method(rb_cLda, "compute_phi", wrap_get_phi, 0);
  rb_define_method(rb_cLda, "model", wrap_get_model_settings, 0);
}

#endif
