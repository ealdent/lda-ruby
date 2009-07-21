ENV["ARCHFLAGS"] = "-arch #{`uname -p` =~ /powerpc/ ? 'ppc' : 'i386'}"

require 'mkmf'

$CFLAGS << ' -Wall -ggdb -O0'
$defs.push( "-D USE_RUBY" )

dir_config('lda-ruby/lda')
create_makefile("lda-ruby/lda")
