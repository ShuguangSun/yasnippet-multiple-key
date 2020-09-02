# yasnippet-multiple-key
Parse multiple "# key :" for yasnippet

This package heavely uses the code in [yasnippet](https://github.com/joaotavora/yasnippet), and includes some patches to that.

The implementation is simple: loop the `#key:` keywords in the head of snippet, and parse the snippet to several records whith different keys in the yas table.

I always forget the exact key for snippet and I use it together with ivy-yasnippet. It may not improve the coding speed but it makes the life easy.
