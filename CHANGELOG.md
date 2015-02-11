version 0.3.9
=============

- merge pull request from @rishabh-tripathi allowing text corpus objects to also be built with an array of strings
- couple minor code refinements

version 0.3.8
=============

- tokenization changes to support German (courtesy of @LeFnord)
- user defined stop word list (also via @LeFnord)

version 0.3.7
=============

- change stop word removal back (optimization)

version 0.3.6
=============

- added stopwords list and included downcasing to improve performance

version 0.3.5
=============

- Bug fix for text documents by Rio Akasaka

Version 0.3.4
=============

- Bug fix by Rio Akasaka, fixes issues with segfaults under Ruby 1.9.2

Version 0.3.1
=============

- top_words method now returns actual words if they exist in the vocabulary

Version 0.3.0
=============

- Completely broke backwards compatibility
- Reworked many classes to make functionality more reasonable
- Added ability to load documents from text files

Version 0.2.3
=============

- Bug fixes by Todd Foster

Version 0.2.2
=============

- First stable release
