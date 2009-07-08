require 'mkmf'

$CFLAGS << ' -Wall -g'

dir_config("lda_ext")
create_makefile("lda_ext")
