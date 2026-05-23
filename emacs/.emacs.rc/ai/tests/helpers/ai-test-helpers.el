;;; ai-test-helpers.el --- Shared fixtures for ai runtime tests -*- lexical-binding: t; -*-

;; Common setup, reset, and stub helpers reused across every test module
;; under tests/. Kept independent from any specific test file so that
;; future split test modules can `(require 'ai-test-helpers)' once.
;;
;; Pre-condition: the AI runtime (~/.emacs.rc/ai-rc.el) must already be
;; loaded before the helpers are called. This file does not load runtime
;; itself — see ai-action-runtime-test.el or sub-files for the load order.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'subr-x)


;;;; Setup --------------------------------------------------------------------

(defun rc/test-gptel-ensure-autocomplete ()
  "Ensure gptel-autocomplete is available for runtime tests."
  (unless (featurep 'gptel)
    (defvar gptel-prompt-transform-functions nil)
    (defvar gptel-use-curl nil)
    (defvar gptel-temperature nil)
    (defvar gptel-backend nil)
    (defvar gptel-model nil)
    (provide 'gptel))
  (unless (featurep 'gptel-autocomplete)
    (load "/home/seeback/myCode/Emacs/plugin/gptel-autocomplete/gptel-autocomplete.el" nil t))
  (setq-local gptel-autocomplete-mode t)
  (setq-local gptel-autocomplete-idle-delay nil))


;;;; Reset --------------------------------------------------------------------

(defun rc/test-gptel-reset-runtime ()
  "Reset local gptel-autocomplete runtime state for one temp buffer."
  (setq-local gptel--completion-overlay nil
              gptel--completion-overlays nil
              gptel--completion-keymap-overlay nil
              gptel--completion-lifecycle-history nil
              gptel--completion-state-history nil
              gptel--completion-stats nil
              gptel--completion-request-id 0
              gptel--current-suggestion nil
              gptel--autocomplete-runtime-state nil)
  (when (fboundp 'rc/gptel-complete-observe-reset-buffer)
    (rc/gptel-complete-observe-reset-buffer))
  (remove-hook 'post-command-hook #'gptel--post-command-clear t))

(defun rc/test-gptel-reset-observe-global ()
  "Reset global observability state for inline completion tests."
  (when (fboundp 'rc/gptel-complete-observe-reset-global)
    (rc/gptel-complete-observe-reset-global)))


;;;; Fixtures -----------------------------------------------------------------

(defun rc/test-gptel-visible-completion (text &optional request-id)
  "Install visible completion TEXT with REQUEST-ID in current buffer."
  (rc/test-gptel-ensure-autocomplete)
  (rc/test-gptel-reset-runtime)
  (setq-local gptel--current-suggestion
              (gptel--make-suggestion
               :request-id (or request-id 1)
               :request-source 'manual
               :candidate-index 0
               :candidate-count 1))
  (gptel--display-completion text (point)))


;;;; Inspection ---------------------------------------------------------------

(defun rc/test-gptel-last-lifecycle-event ()
  "Return latest completion lifecycle event in current buffer."
  (plist-get (car gptel--completion-lifecycle-history) :event))

(defun rc/test-gptel-last-end-reason ()
  "Return latest completion end reason in current buffer."
  (plist-get (car gptel--completion-lifecycle-history) :end-reason))


;;;; Stubs --------------------------------------------------------------------

(defun rc/test-gptel-stub-request-context ()
  "Return deterministic request context for completion tests."
  (list :before ""
        :after ""
        :prompt "prompt"
        :target-point (point)))

(provide 'ai-test-helpers)
;;; ai-test-helpers.el ends here
