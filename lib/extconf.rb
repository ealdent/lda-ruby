require 'mkmf'

$CFLAGS << ' -Wall -ggdb -O0'
$defs.push( "-D USE_RUBY" )

dir_config("lda_ext")
create_makefile("lda_ext")
