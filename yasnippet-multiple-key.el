;;; yasnippet-multiple-key.el --- Multiple key yasnippet  -*- lexical-binding: t; -*-

;; Copyright (C) 2020  Shuguang Sun

;; Author: Shuguang Sun <shuguang79@qq.com>
;; Created: 2020/09/02
;; Version: 1.0
;; URL: https://github.com/ShuguangSun/yasnippet-multiple-key
;; Package-Requires: ((emacs "26.1") (yasnippet "0.14.0"))
;; Keywords: convenience, emulation

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Parse multiple "# key :" for yasnippet

;; This package heavily uses the code in
;; [yasnippet](https://github.com/joaotavora/yasnippet), and includes some
;; patches to that.

;; The implementation is simple: loop the `#key:` keywords in the head of
;; snippet, and parse the snippet to several records with different keys in the
;; yas table.

;; (add-to-list 'load-path
;;                 "~/path-to-yasnippet-multiple-key")
;; (require 'yasnippet-multiple-key)

;; In your snippet directory
;; M-x yasmk-compile-directory
;; M-x yas-reload-all

;; M-x yasmk-recompile-directory
;; M-x yas-reload-all

;; Once those functions are implemented in yasnippet, this package can be
;; retired.

;;; Code:

(eval-when-compile (require 'cl-lib))
(require 'yasnippet)

(defgroup yasnippet-multiple-key nil
  "Parse multiple keys for yasnippet"
  :prefix "yasmk-"
  :group 'editing)


;; It modifies yas--parse-template from yasnippet
(defun yasmk--parse-template-for-compile (&optional file)
  "Parse the template in the current buffer.

This is fork of `yas--parse-template' in yasnippet, and patched for multiple key.

Optional FILE is the absolute file name of the file being
parsed.

Optional GROUP is the group where the template is to go,
otherwise we attempt to calculate it from FILE.

Return a snippet-definition, i.e. a list

 (KEY TEMPLATE NAME CONDITION GROUP VARS LOAD-FILE KEYBINDING UUID)

If the buffer contains a line of \"# --\" then the contents above
this line are ignored. Directives can set most of these with the syntax:

# directive-name : directive-value

Here's a list of currently recognized directives:

 * type
 * name
 * contributor
 * condition
 * group
 * key
 * expand-env
 * binding
 * uuid"
  (goto-char (point-min))
  (let* ((type 'snippet)
         (name (and file
                    (file-name-nondirectory file)))
         (key nil)
         template
         bound
         condition
         (group (and file
                     (yas--calculate-group file)))
         expand-env
         binding
         uuid
         results)
    (if (re-search-forward "^# --\\s-*\n" nil t)
        (progn (setq template
                     (buffer-substring-no-properties (point)
                                                     (point-max)))
               (setq bound (point))
               (goto-char (point-min))
               (while (re-search-forward "^# *\\([^ ]+?\\) *: *\\(.*?\\)[[:space:]]*$" bound t)
                 (when (string= "uuid" (match-string-no-properties 1))
                   (setq uuid (match-string-no-properties 2)))
                 (when (string= "type" (match-string-no-properties 1))
                   (setq type (if (string= "command" (match-string-no-properties 2))
                                  'command
                                'snippet)))
                 (when (string= "key" (match-string-no-properties 1))
                   (cl-pushnew (match-string-no-properties 2) key))
                 (when (string= "name" (match-string-no-properties 1))
                   (setq name (match-string-no-properties 2)))
                 (when (string= "condition" (match-string-no-properties 1))
                   (setq condition (yas--read-lisp (match-string-no-properties 2))))
                 (when (string= "group" (match-string-no-properties 1))
                   (setq group (match-string-no-properties 2)))
                 (when (string= "expand-env" (match-string-no-properties 1))
                   (setq expand-env (yas--read-lisp (match-string-no-properties 2)
                                                   'nil-on-error)))
                 (when (string= "binding" (match-string-no-properties 1))
                   (setq binding (match-string-no-properties 2)))))
      (setq template
            (buffer-substring-no-properties (point-min) (point-max))))
    (unless (or key binding)
      (cl-pushnew (and file (file-name-nondirectory file)) key))
    (when (eq type 'command)
      (setq template (yas--read-lisp (concat "(progn" template ")"))))
    (when group
      (setq group (split-string group "\\.")))
    (if key
        (dolist (k key results)
          ;; (push (list k template name condition group expand-env file binding uuid) results))
          (push (list k template (format "%s (%s)" name k) condition group expand-env file binding uuid) results))
      (setq results (list (list key template name condition group expand-env file binding uuid))))
    results))


;; It modifies yas-define-snippets from yasnippet
(defun yasmk-define-snippets-for-compile (mode snippets)
  "Define SNIPPETS for MODE.

This is fork of yas-define-snippets in yasnippet, and patched for mutlple key.

SNIPPETS is a list of snippet definitions, each taking the
following form

 (KEY TEMPLATE NAME CONDITION GROUP EXPAND-ENV LOAD-FILE KEYBINDING UUID SAVE-FILE)

Within these, only KEY and TEMPLATE are actually mandatory.

TEMPLATE might be a Lisp form or a string, depending on whether
this is a snippet or a snippet-command.

CONDITION, EXPAND-ENV and KEYBINDING are Lisp forms, they have
been `yas--read-lisp'-ed and will eventually be
`yas--eval-for-string'-ed.

The remaining elements are strings.

FILE is probably of very little use if you're programatically
defining snippets.

UUID is the snippet's \"unique-id\". Loading a second snippet
file with the same uuid would replace the previous snippet.

You can use `yas--parse-template' to return such lists based on
the current buffers contents."
  (if yas--creating-compiled-snippets
      (let ((print-length nil))
        (insert ";;; Snippet definitions:\n;;;\n")
        (dolist (snippet snippets)
          ;; Fill in missing elements with nil.
          (setq snippet (append snippet (make-list (- 10 (length snippet)) nil)))
          ;; Move LOAD-FILE to SAVE-FILE because we will load from the
          ;; compiled file, not LOAD-FILE.
          (let ((load-file (nth 6 snippet)))
            (setcar (nthcdr 6 snippet) nil)
            (setcar (nthcdr 9 snippet) load-file)))
        (insert (pp-to-string
                 `(yas-define-snippets ',mode ',snippets)))
        (insert "\n\n"))
    ;; Normal case.
    (let ((snippet-table (yas--table-get-create mode))
          (template nil))
      (dolist (snippet snippets)
        (setq template (yas--define-snippets-1 snippet
                                               snippet-table)))
      template)))

;; It modifies yas--load-directory-2 from yasnippet
(defun yasmk--load-directory-2-for-compile (directory mode-sym)
  ;; Load .yas-setup.el files wherever we find them
  ;;
  (yas--load-yas-setup-file (expand-file-name ".yas-setup" directory))
  (let* ((default-directory directory)
         (snippet-defs nil)
         parsed)
    ;; load the snippet files
    ;;
    (with-temp-buffer
      (dolist (file (yas--subdirs directory 'no-subdirs-just-files))
        (when (file-readable-p file)
          ;; Erase the buffer instead of passing non-nil REPLACE to
          ;; `insert-file-contents' (avoids Emacs bug #23659).
          (erase-buffer)
          (insert-file-contents file)
          ;; (append (yas--parse-template-for-compile file)
          ;;         snippet-defs)
          (setq parsed (yasmk--parse-template-for-compile file))
          (if (listp (car parsed)) ;; If car is a list
              (dolist (sp parsed)
                (push sp snippet-defs))
            (push parsed snippet-defs)))))
    (when snippet-defs
      (yasmk-define-snippets-for-compile mode-sym
                           snippet-defs))
    ;; now recurse to a lower level
    ;;
    (dolist (subdir (yas--subdirs directory))
      (yasmk--load-directory-2-for-compile subdir
                            mode-sym))))


;; It modifies yas--load-directory-1 from yasnippet
(defun yasmk--load-directory-1-for-compile (directory mode-sym)
  "Recursively load snippet templates from DIRECTORY.

This is fork of yas--load-directory-1 in yasnippet, and patched for mutlple key."
  (if yas--creating-compiled-snippets
      (let ((output-file (expand-file-name ".yas-compiled-snippets.el"
                                           directory)))
        (with-temp-file output-file
          (insert (format ";;; Compiled snippets and support files for `%s'\n"
                          mode-sym))
          (yasmk--load-directory-2-for-compile directory mode-sym)
          (insert (format ";;; Do not edit! File generated at %s\n"
                          (current-time-string)))))
    ;; Normal case.
    (unless (file-exists-p (expand-file-name ".yas-skip" directory))
      (unless (and (load (expand-file-name ".yas-compiled-snippets" directory) 'noerror (<= yas-verbosity 3))
                   (progn (yas--message 4 "Loaded compiled snippets from %s" directory) t))
        (yas--message 4 "Loading snippet files from %s" directory)
        (yas--load-directory-2 directory mode-sym)))))


;; It modifies yas-load-directory from yasnippet
(defun yasmk-load-directory-for-compile (top-level-dir &optional use-jit interactive)
  "Load snippets in directory hierarchy TOP-LEVEL-DIR.

This is fork of yas-load-directory in yasnippet, and patched for mutlple key.

Below TOP-LEVEL-DIR each directory should be a mode name.

With prefix argument USE-JIT do jit-loading of snippets."
  (interactive
   (list (read-directory-name "Select the root directory: " nil nil t)
         current-prefix-arg t))
  (unless yas-snippet-dirs
    (setq yas-snippet-dirs top-level-dir))
  (let ((impatient-buffers))
    (dolist (dir (yas--subdirs top-level-dir))
      (let* ((major-mode-and-parents (yas--compute-major-mode-and-parents
                                      (concat dir "/dummy")))
             (mode-sym (car major-mode-and-parents))
             (parents (cdr major-mode-and-parents)))
        ;; Attention: The parents and the menus are already defined
        ;; here, even if the snippets are later jit-loaded.
        ;;
        ;; * We need to know the parents at this point since entering a
        ;;   given mode should jit load for its parents
        ;;   immediately. This could be reviewed, the parents could be
        ;;   discovered just-in-time-as well
        ;;
        ;; * We need to create the menus here to support the `full'
        ;;   option to `yas-use-menu' (all known snippet menus are shown to the user)
        ;;
        (yas--define-parents mode-sym parents)
        (yas--menu-keymap-get-create mode-sym)
        (let ((fun (apply-partially #'yasmk--load-directory-1-for-compile dir mode-sym)))
          (if use-jit
              (yas--schedule-jit mode-sym fun)
            (funcall fun)))
        ;; Look for buffers that are already in `mode-sym', and so
        ;; need the new snippets immediately...
        ;;
        (when use-jit
          (cl-loop for buffer in (buffer-list)
                   do (with-current-buffer buffer
                        (when (eq major-mode mode-sym)
                          (yas--message 4 "Discovered there was already %s in %s" buffer mode-sym)
                          (push buffer impatient-buffers)))))))
    ;; ...after TOP-LEVEL-DIR has been completely loaded, call
    ;; `yas--load-pending-jits' in these impatient buffers.
    ;;
    (cl-loop for buffer in impatient-buffers
             do (with-current-buffer buffer (yas--load-pending-jits))))
  (when interactive
    (yas--message 3 "Loaded snippets from %s." top-level-dir)))


;;;###autoload
(defun yasmk-compile-directory (top-level-dir)
  "Create .yas-compiled-snippets.el files under subdirs of TOP-LEVEL-DIR.

This is fork of `yas-compile-directory' in yasnippet, and patched for mutlple key.

This works by stubbing a few functions, then calling
`yas-load-directory'."
  (interactive "DTop level snippet directory?")
  (let ((yas--creating-compiled-snippets t))
    (yasmk-load-directory-for-compile top-level-dir nil)))

;;;###autoload
(defun yasmk-recompile-all ()
  "Compile every dir in `yas-snippet-dirs'."
  (interactive)
  (mapc #'yasmk-compile-directory (yas-snippet-dirs)))


(provide 'yasnippet-multiple-key)
;;; yasnippet-multiple-key.el ends here
