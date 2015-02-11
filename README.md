# Latent Dirichlet Allocation – Ruby Wrapper

## What is LDA-Ruby?

This wrapper is based on C-code by David M. Blei. In a nutshell, it can be used to automatically cluster documents into topics. The number of topics are chosen beforehand and the topics found are usually fairly intuitive. Details of the implementation can be found in the paper by Blei, Ng, and Jordan.

The original C code relied on files for the input and output. We felt it was necessary to depart from that model and use Ruby objects for these steps instead. The only file necessary will be the data file (in a format similar to that used by [SVMlight][svmlight]). Optionally you may need a vocabulary file to be able to extract the words belonging to topics.

### Example usage:

    require 'lda-ruby'
    corpus = Lda::DataCorpus.new("data/data_file.dat")
    lda = Lda::Lda.new(corpus)    # create an Lda object for training
    lda.em("random")              # run EM algorithm using random starting points
    lda.load_vocabulary("data/vocab.txt")
    lda.print_topics(20)          # print all topics with up to 20 words per topic

If you have general questions about Latent Dirichlet Allocation, I urge you to use the [topic models mailing list][topic-models], since the people who monitor that are very knowledgeable.  If you encounter bugs specific to lda-ruby, please post an issue on the Github project.

## Resources

+ [Blog post about LDA-Ruby][lda-ruby]
+ [David Blei's lda-c code][blei]
+ [Wikipedia article on LDA][wikipedia]
+ [Sample AP data][ap-data]

## References

Blei, David M., Ng, Andrew Y., and Jordan, Michael I. 2003. Latent dirichlet allocation. Journal of Machine Learning Research. 3 (Mar. 2003), 993-1022 [[pdf][pdf]].

[svmlight]: http://svmlight.joachims.org
[lda-ruby]: http://mendicantbug.com/2008/11/17/lda-in-ruby/
[blei]: http://www.cs.princeton.edu/~blei/lda-c/
[wikipedia]: http://en.wikipedia.org/wiki/Latent_Dirichlet_allocation
[ap-data]: http://www.cs.princeton.edu/~blei/lda-c/ap.tgz
[pdf]: http://www.cs.princeton.edu/picasso/mats/BleiNgJordan2003_blei.pdf
[topic-models]: https://lists.cs.princeton.edu/mailman/listinfo/topic-models
