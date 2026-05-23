;;; treesit-rc.el --- Tree-sitter runtime setup -*- lexical-binding: t; -*-

;;; Code:

(require 'cl-lib)

(defvar rc/treesit-grammar-dir
  (expand-file-name "~/.emacs.d/tree-sitter/")
  "Directory that stores local tree-sitter grammar libraries.")

(defvar rc/treesit-language-source-alist
  '((c . ("https://github.com/tree-sitter/tree-sitter-c"))
    (cpp . ("https://github.com/tree-sitter/tree-sitter-cpp"))
    (java . ("https://github.com/tree-sitter/tree-sitter-java"))
    (python . ("https://github.com/tree-sitter/tree-sitter-python")))
  "Language grammar sources used by local tree-sitter setup.")

(defvar rc/treesit-major-mode-remaps
  '((c-mode . c-ts-mode)
    (c++-mode . c++-ts-mode)
    (java-mode . java-ts-mode)
    (python-mode . python-ts-mode))
  "Major mode remaps preferred when the matching grammar is available.")

(defun rc/treesit-installed-language-status ()
  "Return an alist of configured tree-sitter grammar availability."
  (mapcar
   (lambda (entry)
     (let ((lang (car entry)))
       (cons lang
             (and (fboundp 'treesit-language-available-p)
                  (treesit-language-available-p lang)))))
   rc/treesit-language-source-alist))

(defun rc/treesit-missing-languages ()
  "Return configured tree-sitter languages missing from current machine."
  (mapcar #'car
          (seq-filter (lambda (entry) (not (cdr entry)))
                      (rc/treesit-installed-language-status))))

(defun rc/treesit-mode-language (mode)
  "Return the tree-sitter language symbols needed by MODE."
  (pcase mode
    ('c-ts-mode '(c))
    ('c++-ts-mode '(c cpp))
    ('java-ts-mode '(java))
    ('python-ts-mode '(python))
    (_ nil)))

(defun rc/treesit-remap-ready-p (target-mode)
  "Return non-nil when TARGET-MODE can be safely used as a remap target."
  (and (fboundp 'treesit-available-p)
       (treesit-available-p)
       (fboundp target-mode)
       (let ((langs (rc/treesit-mode-language target-mode)))
         (and langs
              (fboundp 'treesit-language-available-p)
              (cl-every #'treesit-language-available-p langs)))))

(defun rc/treesit-apply-major-mode-remaps ()
  "Install major mode remaps for available tree-sitter grammars."
  (dolist (entry rc/treesit-major-mode-remaps)
    (let ((source (car entry))
          (target (cdr entry)))
      (when (rc/treesit-remap-ready-p target)
        (setf (alist-get source major-mode-remap-alist) target)))))

(defun rc/treesit-describe-status ()
  "Echo configured tree-sitter grammar and remap status."
  (interactive)
  (message
   "treesit grammars: %s | remaps: c=%s c++=%s java=%s python=%s"
   (mapconcat
    (lambda (entry)
      (format "%s=%s" (car entry) (if (cdr entry) "ok" "missing")))
    (rc/treesit-installed-language-status)
    ", ")
   (alist-get 'c-mode major-mode-remap-alist)
   (alist-get 'c++-mode major-mode-remap-alist)
   (alist-get 'java-mode major-mode-remap-alist)
   (alist-get 'python-mode major-mode-remap-alist)))

(defun rc/treesit-install-missing-grammars ()
  "Install all configured missing tree-sitter grammars."
  (interactive)
  (unless (fboundp 'treesit-install-language-grammar)
    (user-error "treesit install API is unavailable in this Emacs"))
  (let ((missing (rc/treesit-missing-languages)))
    (if (null missing)
        (rc/treesit-describe-status)
      (dolist (lang missing)
        (message "Installing tree-sitter grammar: %s" lang)
        (treesit-install-language-grammar lang))
      (rc/treesit-apply-major-mode-remaps)
      (rc/treesit-describe-status))))

(when (fboundp 'treesit-available-p)
  (setq treesit-extra-load-path
        (delete-dups
         (cons rc/treesit-grammar-dir
               (copy-sequence (or treesit-extra-load-path nil)))))
  (setq treesit-language-source-alist rc/treesit-language-source-alist)
  (rc/treesit-apply-major-mode-remaps))

(provide 'treesit-rc)
;;; treesit-rc.el ends here
