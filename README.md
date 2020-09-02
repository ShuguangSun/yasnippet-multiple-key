# yasnippet-multiple-key

Parse multiple "# key :" for JIT yasnippet

This package heavely uses the code in [yasnippet](https://github.com/joaotavora/yasnippet), and includes some patches to that.

The implementation is simple: loop the `#key:` keywords in the head of snippet, and parse the snippet to several records whith different keys in the yas table.

For example, the template below will be parsed as two snippets with key of choose and choosevalue.

```
# name: choose
# key: choose
# key: choosevalue
# --
\\\"\${${1:1}:$$(yas-choose-value '("$0"))}\\\"
```

I always forget the exact key for snippet and I use it together with ivy-yasnippet. It may not improve the coding speed but it makes the life easy.

# ISSUE

Not test for snippet save and menus, etc..
