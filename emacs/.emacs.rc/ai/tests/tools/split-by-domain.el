;;; split-by-domain.el --- One-shot test splitter by :tags domain -*- lexical-binding: t; -*-

;; Walks every `(ert-deftest ...)' form in
;;   tests/ai-action-runtime-test.el
;; reads its `:tags', and moves it to a per-domain test file under
;;   tests/complete/   (for domain/complete-*)
;;   tests/            (for domain/action-request → ai-action-request-test.el)
;;   tests/ask/        (for domain/ask)
;;   tests/rewrite/    (for domain/rewrite)
;;   tests/ui/         (for domain/ui-* / describe / replay)
;;
;; Tests with domains that are NOT in `rc/test-split--routing-table'
;; (toggle / meta) stay in the main file.
;;
;; Usage:
;;
;;   emacs --batch -Q \
;;     -l tests/tools/split-by-domain.el \
;;     -f rc/test-split-by-domain
;;
;; Idempotent: re-running on an already-split file is a no-op for tests
;; whose form is no longer present.

;;; Code:

(require 'cl-lib)
(require 'subr-x)


;;;; Configuration -----------------------------------------------------------

(defconst rc/test-split--main-file
  "/home/seeback/.emacs.rc/ai/tests/ai-action-runtime-test.el")

(defconst rc/test-split--ai-root
  "/home/seeback/.emacs.rc/ai")

(defconst rc/test-split--routing-table
  '((domain/complete-state          . "complete/ai-complete-state-test.el")
    (domain/complete-trigger        . "complete/ai-complete-trigger-test.el")
    (domain/complete-cooldown       . "complete/ai-complete-cooldown-test.el")
    (domain/complete-followup       . "complete/ai-complete-followup-test.el")
    (domain/complete-context        . "complete/ai-complete-context-test.el")
    (domain/complete-language-rules . "complete/ai-complete-language-rules-test.el")
    (domain/complete-observe        . "complete/ai-complete-observe-test.el")
    (domain/complete-coordination   . "complete/ai-complete-coordination-test.el")
    (domain/action-request          . "ai-action-request-test.el")
    (domain/ask                     . "ask/ai-ask-runtime-test.el")
    (domain/rewrite                 . "rewrite/ai-rewrite-runtime-test.el")
    (domain/ui-panel                . "ui/ai-ui-panel-inspector-test.el")
    (domain/ui-inspector            . "ui/ai-ui-panel-inspector-test.el")
    (domain/describe                . "ui/ai-ui-panel-inspector-test.el")
    (domain/replay                  . "ui/ai-ui-panel-inspector-test.el"))
  "Map domain tag -> target file relative to `tests/'.
Domains absent here stay in the main test file.")


;;;; Form parsing ------------------------------------------------------------

(defun rc/test-split--read-tags-of-form ()
  "Read tags of the `(ert-deftest ...)' form starting at point.
Returns the list following the :tags keyword, or nil."
  (save-excursion
    (let* ((form (read (current-buffer))))
      (when (and (consp form) (eq (car form) 'ert-deftest))
        ;; form = (ert-deftest NAME (ARGLIST) DOCSTRING-OR-NIL ... :tags QUOTED-LIST ... BODY)
        (let ((tail (cdddr form)))
          ;; Skip optional docstring
          (when (stringp (car tail))
            (setq tail (cdr tail)))
          (cl-loop while tail
                   when (eq (car tail) :tags)
                   return (let ((v (cadr tail)))
                            (cond
                             ((and (consp v) (eq (car v) 'quote)) (cadr v))
                             (t v)))
                   do (setq tail (cdr tail))))))))

(defun rc/test-split--read-name-of-form ()
  "Read NAME of the `(ert-deftest NAME ...)' form starting at point."
  (save-excursion
    (let* ((form (read (current-buffer))))
      (when (and (consp form) (eq (car form) 'ert-deftest))
        (cadr form)))))

(defun rc/test-split--first-domain (tags)
  "Return the first `domain/*' symbol in TAGS, or nil."
  (cl-find-if (lambda (tag)
                (string-prefix-p "domain/" (symbol-name tag)))
              tags))


;;;; Target-file boilerplate -------------------------------------------------

(defun rc/test-split--target-header (rel-path)
  "Return file header string for the target test file at REL-PATH."
  (let ((base (file-name-base rel-path)))
    (format
     "\
;;; %s.el --- AI runtime tests, split by domain -*- lexical-binding: t; -*-

;; Auto-extracted from ai-action-runtime-test.el by tests/tools/split-by-domain.el.
;; Do not append new tests here by hand without first updating the splitter.

;;; Code:

(require 'ert)
(require 'cl-lib)

(load \"/home/seeback/.emacs.rc/ai-rc.el\" nil t)
(load \"/home/seeback/.emacs.rc/ai/tests/helpers/ai-test-helpers.el\" nil t)

"
     base)))

(defun rc/test-split--target-footer (rel-path)
  "Return file footer string for the target test file at REL-PATH."
  (let ((base (file-name-base rel-path)))
    (format "
(provide '%s)
;;; %s.el ends here
"
            base base)))


;;;; Walker ------------------------------------------------------------------

(defun rc/test-split--ensure-target (abs-path rel-path)
  "Initialize ABS-PATH with header if it does not exist yet."
  (unless (file-exists-p abs-path)
    (make-directory (file-name-directory abs-path) t)
    (with-temp-file abs-path
      (insert (rc/test-split--target-header rel-path)))))

(defun rc/test-split--append-form (abs-path form-text)
  "Append FORM-TEXT (with trailing newlines) to ABS-PATH."
  (with-temp-buffer
    (insert-file-contents abs-path)
    (goto-char (point-max))
    ;; Strip any stray trailing newlines so files stay tidy.
    (skip-chars-backward " \t\n")
    (delete-region (point) (point-max))
    (insert "\n\n")
    (insert form-text)
    (insert "\n")
    (write-region (point-min) (point-max) abs-path nil 'silent)))

(defun rc/test-split--finalize-target (abs-path rel-path)
  "Append provide/footer if not yet present."
  (let* ((base    (file-name-base rel-path))
         (provide (format "(provide '%s)" base)))
    (with-temp-buffer
      (insert-file-contents abs-path)
      (goto-char (point-min))
      (unless (re-search-forward (regexp-quote provide) nil t)
        (goto-char (point-max))
        (skip-chars-backward " \t\n")
        (delete-region (point) (point-max))
        (insert (rc/test-split--target-footer rel-path))
        (write-region (point-min) (point-max) abs-path nil 'silent)))))

(defun rc/test-split-by-domain ()
  "Walk every `(ert-deftest ...)' in the main test file and route it.
Returns a stats plist."
  (interactive)
  (let ((main-buf (find-file-noselect rc/test-split--main-file))
        (touched-files (make-hash-table :test 'equal))
        (moved 0)
        (kept 0)
        (unknown-domain 0)
        (no-routing 0))
    (with-current-buffer main-buf
      (goto-char (point-min))
      (while (re-search-forward "^(ert-deftest \\([^ \t\n()]+\\) " nil t)
        (let* ((form-start (line-beginning-position))
               (name (intern (match-string 1)))
               (tags (save-excursion
                       (goto-char form-start)
                       (rc/test-split--read-tags-of-form)))
               (domain (rc/test-split--first-domain tags))
               (rel-path (and domain
                              (alist-get domain rc/test-split--routing-table))))
          (cond
           ((null tags)
            (cl-incf no-routing))
           ((null domain)
            (cl-incf unknown-domain))
           ((null rel-path)
            (cl-incf kept))
           (t
            (let* ((abs-path (expand-file-name (concat "tests/" rel-path)
                                                rc/test-split--ai-root))
                   (form-end (save-excursion
                               (goto-char form-start)
                               (forward-sexp 1)
                               (point)))
                   (form-text (buffer-substring-no-properties
                               form-start form-end)))
              (rc/test-split--ensure-target abs-path rel-path)
              (rc/test-split--append-form abs-path form-text)
              (puthash rel-path t touched-files)
              ;; Delete the form (plus any trailing blank line) from main.
              (delete-region form-start form-end)
              ;; Eat a single blank line if it remains.
              (when (looking-at "\n\n")
                (delete-char 1))
              (cl-incf moved))))))
      (save-buffer))
    ;; Append provide/footer to each touched target.
    (cl-loop for rel-path being the hash-keys of touched-files do
             (let ((abs (expand-file-name (concat "tests/" rel-path)
                                          rc/test-split--ai-root)))
               (rc/test-split--finalize-target abs rel-path)))
    (message "[split] moved=%d kept-domain=%d unknown-domain=%d no-tags=%d files=%d"
             moved kept unknown-domain no-routing
             (hash-table-count touched-files))
    (list :moved moved
          :kept-domain kept
          :unknown-domain unknown-domain
          :no-tags no-routing
          :files (hash-table-count touched-files))))

(provide 'rc/test-split-by-domain)
;;; split-by-domain.el ends here
