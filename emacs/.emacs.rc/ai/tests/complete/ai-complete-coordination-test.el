;;; ai-complete-coordination-test.el --- AI runtime tests, split by domain -*- lexical-binding: t; -*-

;; Auto-extracted from ai-action-runtime-test.el by tests/tools/split-by-domain.el.
;; Do not append new tests here by hand without first updating the splitter.

;;; Code:

(require 'ert)
(require 'cl-lib)

(load "/home/seeback/.emacs.rc/ai-rc.el" nil t)
(load "/home/seeback/.emacs.rc/ai/tests/helpers/ai-test-helpers.el" nil t)

(ert-deftest rc/gptel-complete-notify-signature-help-triggers-request ()
  
  :tags '(domain/complete-coordination risk/coordination prio/2)(with-temp-buffer
    (emacs-lisp-mode)
    (rc/test-gptel-ensure-autocomplete)
    (let (request-source)
      (setq-local gptel-autocomplete-mode t)
      (cl-letf (((symbol-function 'run-with-timer)
                 (lambda (_delay _repeat fn &rest args)
                   (apply fn args)
                   'source-timer))
                ((symbol-function 'gptel-complete)
                 (lambda (&optional source &rest _args)
                   (setq request-source source)
                   t)))
        (rc/gptel-complete-notify-signature-help '(:signature "(foo x y)"))
        (should (eq request-source 'signature-help))
        (should (eq (plist-get rc/gptel-complete-last-auto-trigger-check :trigger-source)
                    'signature-help))
        (should (plist-get rc/gptel-complete-last-auto-trigger-check :eligible))))))

(ert-deftest rc/gptel-complete-notify-lsp-suggestions-triggers-request ()
  
  :tags '(domain/complete-coordination risk/coordination prio/2)(with-temp-buffer
    (emacs-lisp-mode)
    (rc/test-gptel-ensure-autocomplete)
    (let (request-source)
      (setq-local gptel-autocomplete-mode t)
      (cl-letf (((symbol-function 'run-with-timer)
                 (lambda (_delay _repeat fn &rest args)
                   (apply fn args)
                   'source-timer))
                ((symbol-function 'gptel-complete)
                 (lambda (&optional source &rest _args)
                   (setq request-source source)
                   t)))
        (rc/gptel-complete-notify-lsp-suggestions '(:items 3))
        (should (eq request-source 'lsp-suggestions))
        (should (eq (plist-get rc/gptel-complete-last-auto-trigger-check :trigger-source)
                    'lsp-suggestions))
        (should (plist-get rc/gptel-complete-last-auto-trigger-check :eligible))))))

(ert-deftest rc/gptel-complete-notify-flymake-diagnostics-triggers-request ()
  
  :tags '(domain/complete-coordination risk/observability risk/coordination prio/2)(with-temp-buffer
    (emacs-lisp-mode)
    (rc/test-gptel-ensure-autocomplete)
    (let (request-source)
      (setq-local gptel-autocomplete-mode t)
      (cl-letf (((symbol-function 'run-with-timer)
                 (lambda (_delay _repeat fn &rest args)
                   (apply fn args)
                   'source-timer))
                ((symbol-function 'gptel-complete)
                 (lambda (&optional source &rest _args)
                   (setq request-source source)
                   t)))
        (rc/gptel-complete-notify-flymake-diagnostics '(:diagnostic-count 2))
        (should (eq request-source 'flymake-diagnostics))
        (should (eq (plist-get rc/gptel-complete-last-auto-trigger-check :trigger-source)
                    'flymake-diagnostics))
        (should (plist-get rc/gptel-complete-last-auto-trigger-check :eligible))))))

(ert-deftest rc/gptel-complete-company-started-bridges-lsp-suggestions ()
  
  :tags '(domain/complete-coordination risk/coordination prio/3)(with-temp-buffer
    (let (payload)
      (setq-local lsp-mode t)
      (setq-local company-candidates '("a" "b"))
      (setq-local company-prefix "he")
      (cl-letf (((symbol-function 'rc/gptel-complete-notify-lsp-suggestions)
                 (lambda (plist)
                   (setq payload plist)
                   t)))
        (rc/gptel-complete-company-started 'company-capf)
        (should (equal (plist-get payload :candidate-count) 2))
        (should (equal (plist-get payload :prefix) "he"))))))

(ert-deftest rc/gptel-complete-company-started-ignores-non-lsp-backend ()
  
  :tags '(domain/complete-coordination risk/coordination prio/3)(with-temp-buffer
    (let (called)
      (cl-letf (((symbol-function 'rc/gptel-complete-notify-lsp-suggestions)
                 (lambda (&rest _args)
                   (setq called t)
                   t)))
        (rc/gptel-complete-company-started 'company-dabbrev)
        (should-not called)))))

(ert-deftest rc/gptel-complete-company-started-aborts-when-ghost-visible ()
  
  :tags '(domain/complete-coordination risk/coordination prio/3)(with-temp-buffer
    (let (aborted notified)
      (cl-letf (((symbol-function 'rc/gptel-inline-completion-visible-p) (lambda () t))
                ((symbol-function 'company-abort)
                 (lambda ()
                   (setq aborted t)
                   t))
                ((symbol-function 'rc/gptel-complete-notify-lsp-suggestions)
                 (lambda (&rest _args)
                   (setq notified t)
                   t)))
        (setq-local company-candidates '("a"))
        (rc/gptel-complete-company-started 'company-capf)
        (should aborted)
        (should-not notified)))))

(ert-deftest rc/gptel-complete-environment-policy-blocks-yasnippet-auto-trigger ()
  
  :tags '(domain/complete-coordination risk/coordination prio/3)(with-temp-buffer
    (emacs-lisp-mode)
    (cl-letf (((symbol-function 'rc/gptel-complete-yasnippet-active-p) (lambda () t)))
      (let ((policy (rc/gptel-complete-environment-policy 'auto)))
        (should-not (plist-get policy :auto-allow))
        (should-not (plist-get policy :manual-allow))
        (should (eq (plist-get policy :blocked-reason) 'yasnippet-active))
        (should (eq (plist-get policy :yield-target) 'yasnippet))))))

(ert-deftest rc/gptel-complete-environment-policy-marks-org-src-context ()
  
  :tags '(domain/complete-coordination risk/coordination prio/3)(with-temp-buffer
    (emacs-lisp-mode)
    (cl-letf (((symbol-function 'rc/gptel-complete-org-src-buffer-p) (lambda () t)))
      (let ((policy (rc/gptel-complete-environment-policy 'auto)))
        (should (plist-get policy :org-src))
        (should (plist-get policy :auto-allow))))))

(ert-deftest rc/gptel-complete-environment-policy-denies-tramp-and-minibuffer ()
  
  :tags '(domain/complete-coordination risk/coordination prio/3)(with-temp-buffer
    (emacs-lisp-mode)
    (cl-letf (((symbol-function 'rc/gptel-complete-tramp-buffer-p) (lambda () t)))
      (let ((policy (rc/gptel-complete-environment-policy 'manual)))
        (should-not (plist-get policy :auto-allow))
        (should-not (plist-get policy :manual-allow))
        (should (eq (plist-get policy :blocked-reason) 'tramp)))))
  (with-temp-buffer
    (emacs-lisp-mode)
    (cl-letf (((symbol-function 'minibufferp) (lambda (&optional _buffer) t)))
      (let ((policy (rc/gptel-complete-environment-policy 'manual)))
        (should-not (plist-get policy :auto-allow))
        (should-not (plist-get policy :manual-allow))
        (should (eq (plist-get policy :blocked-reason) 'minibuffer))))))

(ert-deftest rc/gptel-complete-manual-complete-denies-read-only-buffer ()
  
  :tags '(domain/complete-coordination risk/coordination prio/2)(with-temp-buffer
    (emacs-lisp-mode)
    (rc/test-gptel-ensure-autocomplete)
    (setq buffer-read-only t)
    (let (requested)
      (cl-letf (((symbol-function 'rc/gptel-prepare-inline-complete-buffer) (lambda (&optional _extra) t))
                ((symbol-function 'gptel-complete)
                 (lambda (&rest _args)
                   (setq requested t)
                   t))
                ((symbol-function 'message) (lambda (&rest _args) nil)))
        (rc/gptel-manual-complete)
        (should-not requested)
        (should (eq (plist-get (car (rc/gptel-complete-recent-trace (current-buffer))) :reason)
                    'read-only))))))

(ert-deftest rc/gptel-complete-manual-complete-yields-company-when-allowed ()
  
  :tags '(domain/complete-coordination risk/coordination prio/2)(with-temp-buffer
    (emacs-lisp-mode)
    (rc/test-gptel-ensure-autocomplete)
    (let (aborted requested)
      (setq-local company-candidates '("a"))
      (cl-letf (((symbol-function 'rc/gptel-prepare-inline-complete-buffer) (lambda (&optional _extra) t))
                ((symbol-function 'company--active-p) (lambda () t))
                ((symbol-function 'company-abort)
                 (lambda ()
                   (setq aborted t)
                   t))
                ((symbol-function 'gptel-complete)
                 (lambda (&optional source &rest _args)
                   (setq requested source)
                   t)))
        (rc/gptel-manual-complete)
        (should aborted)
        (should (eq requested 'manual))))))

(ert-deftest rc/gptel-complete-maybe-abort-company-only-when-company-active ()
  
  :tags '(domain/complete-coordination risk/coordination prio/2)(with-temp-buffer
    (let (aborted)
      (cl-letf (((symbol-function 'rc/gptel-inline-completion-visible-p) (lambda () t))
                ((symbol-function 'company--active-p) (lambda () t))
                ((symbol-function 'company-abort)
                 (lambda ()
                   (setq aborted t)
                   t)))
        (rc/gptel-complete-maybe-abort-company)
        (should aborted)))
    (let (aborted)
      (cl-letf (((symbol-function 'rc/gptel-inline-completion-visible-p) (lambda () t))
                ((symbol-function 'company--active-p) (lambda () nil))
                ((symbol-function 'company-abort)
                 (lambda ()
                   (setq aborted t)
                   t)))
        (rc/gptel-complete-maybe-abort-company)
        (should-not aborted)))))

(ert-deftest rc/gptel-complete-lsp-signature-activated-bridges-source ()
  
  :tags '(domain/complete-coordination risk/coordination prio/2)(with-temp-buffer
    (let (payload)
      (setq-local lsp-mode t)
      (setq-local lsp-signature-mode t)
      (setq-local lsp--signature-last 'fake-signature)
      (cl-letf (((symbol-function 'lsp--signature->message)
                 (lambda (_sig) "fn(x, y)"))
                ((symbol-function 'rc/gptel-complete-notify-signature-help)
                 (lambda (plist)
                   (setq payload plist)
                   t)))
        (rc/gptel-complete-lsp-signature-activated)
        (should (equal (plist-get payload :source) 'lsp-signature))
        (should (equal (plist-get payload :signature) "fn(x, y)"))))))

(ert-deftest rc/gptel-complete-flymake-after-diagnostics-bridges-count ()
  
  :tags '(domain/complete-coordination risk/observability risk/coordination prio/2)(with-temp-buffer
    (let (payload)
      (setq-local flymake-mode t)
      (cl-letf (((symbol-function 'flymake-diagnostics)
                 (lambda () '(a b c)))
                ((symbol-function 'rc/gptel-complete-notify-flymake-diagnostics)
                 (lambda (plist)
                   (setq payload plist)
                   t)))
        (rc/gptel-complete-flymake-after-diagnostics)
        (should (= (plist-get payload :diagnostic-count) 3))
        (should (eq (plist-get payload :source) 'flymake))))))

(ert-deftest rc/gptel-complete-source-policy-can-disable-external-source ()
  
  :tags '(domain/complete-coordination risk/source-consistency prio/2)(with-temp-buffer
    (emacs-lisp-mode)
    (rc/test-gptel-ensure-autocomplete)
    (setq-local gptel-autocomplete-mode t)
    (cl-letf (((symbol-function 'rc/gptel-complete-mode-rule)
               (lambda ()
                 '(:source-rules ((signature-help :enabled nil :delay 0.01))))))
      (let ((diag (rc/gptel-complete-notify-signature-help '(:signature "(foo x y)"))))
        (should-not (plist-get diag :eligible))
        (should (eq (plist-get diag :blocked-reason) 'source-disabled))))))
(provide 'ai-complete-coordination-test)
;;; ai-complete-coordination-test.el ends here
