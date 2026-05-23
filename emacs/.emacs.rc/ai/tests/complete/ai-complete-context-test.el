;;; ai-complete-context-test.el --- AI runtime tests, split by domain -*- lexical-binding: t; -*-

;; Auto-extracted from ai-action-runtime-test.el by tests/tools/split-by-domain.el.
;; Do not append new tests here by hand without first updating the splitter.

;;; Code:

(require 'ert)
(require 'cl-lib)

(load "/home/seeback/.emacs.rc/ai-rc.el" nil t)
(load "/home/seeback/.emacs.rc/ai/tests/helpers/ai-test-helpers.el" nil t)

(ert-deftest rc/gptel-complete-request-context-records-prompt-diagnostics ()
  
  :tags '(domain/complete-context risk/observability prio/2)(with-temp-buffer
    (rc/test-gptel-ensure-autocomplete)
    (insert "(defun demo ()\n  (message \"hi\"))\n")
    (goto-char (point-max))
    (let* ((context (gptel--request-context))
           (diag (plist-get context :diagnostics)))
      (should (listp diag))
      (should (= (plist-get diag :prefix-length) 0))
      (should (numberp (plist-get diag :context-length)))
      (should (seq-some (lambda (slice)
                          (eq (plist-get slice :kind) 'cursor-line))
                        (plist-get diag :slices)))
      (should (equal diag (gptel-autocomplete-last-prompt-diagnostics))))))

(ert-deftest rc/gptel-complete-request-context-detects-vertical-spacing-style ()
  
  :tags '(domain/complete-context risk/style prio/2)(with-temp-buffer
    (rc/test-gptel-ensure-autocomplete)
    (insert "int total = 0;\n\nfor (int i = 0; i < n; ++i) {\n  total += i;\n}\n")
    (goto-char (point-max))
    (let* ((context (gptel--request-context))
           (diag (plist-get context :diagnostics))
           (style (plist-get diag :vertical-spacing-style)))
      (should (plist-get style :preserve-blank-lines))
      (should (> (plist-get style :separated-block-count) 0))
      (should (string-match-p "Preserve blank lines"
                              (or (plist-get diag :vertical-spacing-instruction) "")))
      (should (string-match-p "Local formatting style:"
                              (plist-get context :prompt))))))

(ert-deftest rc/gptel-complete-request-context-respects-slice-toggles ()
  
  :tags '(domain/complete-context prio/2)(with-temp-buffer
    (rc/test-gptel-ensure-autocomplete)
    (insert "value")
    (goto-char (point-max))
    (setq-local gptel--completion-recent-edits
                (list '(:text "recent-edit" :point 3 :timestamp 1.0)))
    (cl-letf (((symbol-function 'gptel--same-file-symbol-snippets)
               (lambda () "Structured same-file symbol hints:\nfoo")))
      (let ((gptel-autocomplete-include-recent-edits nil)
            (gptel-autocomplete-include-same-file-symbols nil))
        (let* ((context (gptel--request-context))
               (diag (plist-get context :diagnostics)))
          (should-not (string-match-p "recent-edit" (plist-get context :prompt)))
          (should-not (string-match-p "Structured same-file symbol hints"
                                      (plist-get context :prompt)))
          (should (seq-some
                   (lambda (slice)
                     (and (eq (plist-get slice :kind) 'recent-edits)
                          (not (plist-get slice :included))))
                   (plist-get diag :slices)))
          (should (seq-some
                   (lambda (slice)
                     (and (eq (plist-get slice :kind) 'same-file-symbols)
                          (not (plist-get slice :included))))
                   (plist-get diag :slices))))))))

(ert-deftest rc/gptel-complete-request-context-budget-crops-tail-slices-first ()
  
  :tags '(domain/complete-context prio/2)(with-temp-buffer
    (rc/test-gptel-ensure-autocomplete)
    (insert "prefix context\n")
    (goto-char (point-max))
    (setq-local gptel--completion-recent-edits
                (list '(:text "recent-edit-block" :point 3 :timestamp 1.0)))
    (cl-letf (((symbol-function 'gptel--current-defun-context)
               (lambda () "defun-context-block"))
              ((symbol-function 'gptel--same-file-symbol-snippets)
               (lambda () "Structured same-file symbol hints:\nvery-long-symbol-block")))
      (let* ((gptel-autocomplete-context-char-budget 120)
             (context (gptel--request-context))
             (diag (plist-get context :diagnostics)))
        (should (plist-get diag :cropped))
        (should (seq-some
                 (lambda (entry)
                   (eq (plist-get entry :kind) 'same-file-symbols))
                 (plist-get diag :cropped)))
        (should (seq-some
                 (lambda (slice)
                   (and (eq (plist-get slice :kind) 'cursor-line)
                        (plist-get slice :included)))
                 (plist-get diag :slices)))))))

(ert-deftest rc/gptel-complete-context-rules-feature-loads ()
  
  :tags '(domain/complete-context prio/1)(should (featurep 'ai-complete-context-rules-rc))
  (should (featurep 'ai-complete-followup-rules-rc))
  (should (featurep 'ai-complete-policy-rules-rc)))
(provide 'ai-complete-context-test)
;;; ai-complete-context-test.el ends here
