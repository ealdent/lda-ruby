require 'mkmf'

$CFLAGS << ' -Wall -ggdb -O0'
$defs.push( "-D USE_RUBY" )

create_makefile("lda-ruby/lda")
