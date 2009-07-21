require 'mkmf'

$CFLAGS << ' -Wall -ggdb -O0'
$defs.push( "-D USE_RUBY" )

dir_config("lda-ruby")
create_makefile("lda-ruby")
