;;; ai-action-runtime-test.el --- Shared AI runtime tests -*- lexical-binding: t; -*-

;;; Code:

;; Residual file after Phase 05 split.
;; Intentionally keeps only cross-cutting tests that do not yet merit their
;; own per-domain file:
;; - domain/toggle
;; - domain/meta (lint / tag hygiene)

(require 'ert)
(require 'cl-lib)

(load "/home/seeback/.emacs.rc/ai-rc.el" nil t)
(load "/home/seeback/.emacs.rc/ai/tests/helpers/ai-test-helpers.el" nil t)


(ert-deftest rc/gptel-toggle-complete-auto-trigger-enables-runtime ()
  
  :tags '(domain/toggle prio/2)(with-temp-buffer
    (let (setup-called prepare-called)
      (cl-letf (((symbol-function 'rc/gptel-autocomplete-setup)
                 (lambda () (setq setup-called t)))
                ((symbol-function 'rc/gptel-prepare-inline-complete-buffer)
                 (lambda (&optional _extra) (setq prepare-called t))))
        (rc/gptel-toggle-complete-auto-trigger))
      (should setup-called)
      (should prepare-called)
      (should rc/gptel-complete-auto-trigger-enabled)
      (should (eq rc/gptel-complete-auto-trigger-mode 'on))
      (should (bound-and-true-p gptel-autocomplete-mode)))))

(ert-deftest rc/gptel-toggle-complete-auto-trigger-cycles-modes ()
  
  :tags '(domain/toggle prio/2)(with-temp-buffer
    (cl-letf (((symbol-function 'rc/gptel-autocomplete-setup) #'ignore)
              ((symbol-function 'rc/gptel-prepare-inline-complete-buffer)
               (lambda (&optional _extra) nil)))
      (rc/gptel-toggle-complete-auto-trigger)
      (should (eq rc/gptel-complete-auto-trigger-mode 'on))
      (should rc/gptel-complete-auto-trigger-enabled)
      (rc/gptel-toggle-complete-auto-trigger)
      (should (eq rc/gptel-complete-auto-trigger-mode 'diagnose))
      (should rc/gptel-complete-auto-trigger-enabled)
      (rc/gptel-toggle-complete-auto-trigger)
      (should (eq rc/gptel-complete-auto-trigger-mode 'off))
      (should-not rc/gptel-complete-auto-trigger-enabled))))






















;;;; Lint --------------------------------------------------------------------
;; Tag hygiene: every ert-deftest must carry valid :tags. See
;; tests/exec-plans/active/01-inventory-and-coverage-map.md for vocabulary.

(load "/home/seeback/.emacs.rc/ai/tests/tools/coverage-extract.el" nil t)

(ert-deftest rc/lint-all-tests-have-tags ()
  "Every ert-deftest must carry a domain/* + prio/N (and optional risk/*) tag."
  :tags '(domain/meta prio/3)
  (let ((errors (rc/test-lint-collect-errors)))
    (when errors
      (ert-fail
       (format "%d tests have invalid or missing tags:\n%s"
               (length errors)
               (rc/test-lint-format-errors errors))))))

(provide 'ai-action-runtime-test)
;;; ai-action-runtime-test.el ends here
