# yasnippet-multiple-key

Parse multiple "# key :" for JIT yasnippet

This package heavily uses the code in [yasnippet](https://github.com/joaotavora/yasnippet), and includes some patches to that.

The implementation is simple: loop the `#key:` keywords in the head of snippet, and parse the snippet to several records with different keys in the yas table.

For example, the template below will be parsed as two snippets with key of choose and choosevalue.

```
# name: choose
# key: choose
# key: choosevalue
# --
\\\"\${${1:1}:$$(yas-choose-value '("$0"))}\\\"
```

I always forget the exact key for snippet and I use it together with ivy-yasnippet. It may not improve the coding speed but it makes the life easy.

# USAGE

```
(add-to-list 'load-path
                "~/path-to-yasnippet-multiple-key")
(require 'yasnippet-multiple-key)
```

In your snippet directory
```
M-x yasnippet-multiple-key-compile-directory
M-x yas-reload-all
```

or 
```
M-x yasnippet-multiple-key-recompile-directory
M-x yas-reload-all
```

You can define alias or key-bindings
```
(defalias 'yasmk-compile-directory #'yasnippet-multiple-key-compile-directory)
(defalias 'yasmk-recompile-all #'yasnippet-multiple-key-recompile-all)
```

# ISSUES

Not test for snippet save and menus, etc..

I submitted a pull request to [yasnippet](https://github.com/joaotavora/yasnippet). However, [yasnippet](https://github.com/joaotavora/yasnippet) is a much popular and matured package, and those patches may introduce new bugs to it, that is why I have a separate package. Once those functions are implemented in [yasnippet](https://github.com/joaotavora/yasnippet), this package can be retired.
