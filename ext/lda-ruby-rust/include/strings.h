#ifndef LDA_RUBY_BINDGEN_STRINGS_H
#define LDA_RUBY_BINDGEN_STRINGS_H

#include <string.h>

/*
 * RubyInstaller headers may include <strings.h> on Windows, but Clang-based
 * bindgen runs can miss that header in this environment. Provide compatibility
 * aliases for bindgen preprocessing.
 */
#if defined(_WIN32) && !defined(__MINGW32__)
#ifndef bzero
#define bzero(ptr, size) memset((ptr), 0, (size))
#endif
#ifndef bcmp
#define bcmp(a, b, n) memcmp((a), (b), (n))
#endif
#ifndef bcopy
#define bcopy(src, dst, n) memmove((dst), (src), (n))
#endif
#ifndef index
#define index strchr
#endif
#ifndef rindex
#define rindex strrchr
#endif
#ifndef strcasecmp
#define strcasecmp _stricmp
#endif
#ifndef strncasecmp
#define strncasecmp _strnicmp
#endif
#endif

#endif
