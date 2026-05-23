;;; run-all-tests.el --- Aggregator for the full AI runtime test suite -*- lexical-binding: t; -*-

;; Load order is significant:
;;   1. helpers (shared fixtures, no test bodies)
;;   2. main file (residual toggle / meta lint tests)
;;   3. per-domain split files (action-request / ask / complete-* / rewrite / ui)
;;
;; Each split file already loads helpers + ai-rc, but Emacs `load' is
;; idempotent so the duplicate cost is one hash lookup per file.

;;; Code:

(require 'ert)
(require 'cl-lib)

(load "/home/seeback/.emacs.rc/ai-rc.el" nil t)
(load "/home/seeback/.emacs.rc/ai/tests/helpers/ai-test-helpers.el" nil t)

;; Main file: residual tests intentionally kept in one place for now.
(load "/home/seeback/.emacs.rc/ai/tests/ai-action-runtime-test.el" nil t)

;; Cross-domain action-request layer.
(load "/home/seeback/.emacs.rc/ai/tests/ai-action-request-test.el" nil t)

;; Ask / rewrite / shared UI panel+inspector layers.
(dolist (rel '("ask/ai-ask-runtime-test.el"
               "rewrite/ai-rewrite-runtime-test.el"
               "ui/ai-ui-panel-inspector-test.el"
               "tools/ai-calibration-tools-test.el"
               "tools/ai-calibration-summarizer-test.el"))
  (load (expand-file-name rel "/home/seeback/.emacs.rc/ai/tests/") nil t))

;; Per-domain complete-* split files.
(dolist (rel '("complete/ai-complete-state-test.el"
               "complete/ai-complete-trigger-test.el"
               "complete/ai-complete-cooldown-test.el"
               "complete/ai-complete-followup-test.el"
               "complete/ai-complete-context-test.el"
               "complete/ai-complete-language-rules-test.el"
               "complete/ai-complete-observe-test.el"
               "complete/ai-complete-coordination-test.el"))
  (load (expand-file-name rel "/home/seeback/.emacs.rc/ai/tests/") nil t))

(provide 'run-all-tests)
;;; run-all-tests.el ends here
