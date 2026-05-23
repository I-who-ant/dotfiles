;;; ai-complete-trigger-test.el --- AI runtime tests, split by domain -*- lexical-binding: t; -*-

;; Auto-extracted from ai-action-runtime-test.el by tests/tools/split-by-domain.el.
;; Do not append new tests here by hand without first updating the splitter.

;;; Code:

(require 'ert)
(require 'cl-lib)

(load "/home/seeback/.emacs.rc/ai-rc.el" nil t)
(load "/home/seeback/.emacs.rc/ai/tests/helpers/ai-test-helpers.el" nil t)

(ert-deftest rc/gptel-complete-auto-trigger-diagnostics-report-blocked-reason ()
  
  :tags '(domain/complete-trigger risk/observability prio/2)(with-temp-buffer
    (c++-mode)
    (rc/gptel-complete-set-auto-trigger-mode 'on)
    (let ((last-command-event ?x))
      (setq rc/gptel-complete-last-auto-trigger-check nil)
      (rc/gptel-complete-post-self-insert-trigger)
      (should (eq (plist-get rc/gptel-complete-last-auto-trigger-check :blocked-reason)
                  'autocomplete-mode-disabled))
      (should (eq (plist-get rc/gptel-complete-last-auto-trigger-check :major-mode)
                  'c++-mode)))))

(ert-deftest rc/gptel-complete-auto-trigger-blocks-comment-context ()
  
  :tags '(domain/complete-trigger prio/2)(with-temp-buffer
    (c++-mode)
    (gptel-autocomplete-mode 1)
    (rc/gptel-complete-set-auto-trigger-mode 'on)
    (insert "// comment =")
    (let ((last-command-event ?=))
      (setq rc/gptel-complete-last-auto-trigger-check nil)
      (rc/gptel-complete-post-self-insert-trigger)
      (should (eq (plist-get rc/gptel-complete-last-auto-trigger-check :blocked-reason)
                  'comment-or-string))
      (should (plist-get rc/gptel-complete-last-auto-trigger-check :in-comment-or-string)))))

(ert-deftest rc/gptel-complete-auto-trigger-blocks-comment-context-in-c-ts-mode ()
  
  :tags '(domain/complete-trigger prio/2)(with-temp-buffer
    (c-ts-mode)
    (gptel-autocomplete-mode 1)
    (rc/gptel-complete-set-auto-trigger-mode 'on)
    (insert "// comment =")
    (let ((last-command-event ?=))
      (setq rc/gptel-complete-last-auto-trigger-check nil)
      (rc/gptel-complete-post-self-insert-trigger)
      (should (eq (plist-get rc/gptel-complete-last-auto-trigger-check :blocked-reason)
                  'comment-or-string))
      (should (plist-get rc/gptel-complete-last-auto-trigger-check :in-comment-or-string)))))

(ert-deftest rc/gptel-complete-auto-trigger-blocks-comment-context-in-cpp-ts-mode ()
  
  :tags '(domain/complete-trigger prio/2)(with-temp-buffer
    (c++-ts-mode)
    (gptel-autocomplete-mode 1)
    (rc/gptel-complete-set-auto-trigger-mode 'on)
    (insert "// comment =")
    (let ((last-command-event ?=))
      (setq rc/gptel-complete-last-auto-trigger-check nil)
      (rc/gptel-complete-post-self-insert-trigger)
      (should (eq (plist-get rc/gptel-complete-last-auto-trigger-check :blocked-reason)
                  'comment-or-string))
      (should (plist-get rc/gptel-complete-last-auto-trigger-check :in-comment-or-string)))))

(ert-deftest rc/gptel-complete-auto-trigger-blocks-string-context ()
  
  :tags '(domain/complete-trigger prio/2)(with-temp-buffer
    (c++-mode)
    (gptel-autocomplete-mode 1)
    (rc/gptel-complete-set-auto-trigger-mode 'on)
    (insert "std::string s = \"value =")
    (should (eq (ignore-errors (c-in-literal)) 'string))
    (let ((last-command-event ?=))
      (setq rc/gptel-complete-last-auto-trigger-check nil)
      (rc/gptel-complete-post-self-insert-trigger)
      (should (eq (plist-get rc/gptel-complete-last-auto-trigger-check :blocked-reason)
                  'comment-or-string))
      (should (plist-get rc/gptel-complete-last-auto-trigger-check :in-comment-or-string)))))

(ert-deftest rc/gptel-complete-auto-trigger-blocks-string-context-in-cpp-ts-mode ()
  
  :tags '(domain/complete-trigger prio/2)(with-temp-buffer
    (c++-ts-mode)
    (gptel-autocomplete-mode 1)
    (rc/gptel-complete-set-auto-trigger-mode 'on)
    (insert "std::string s = \"value =")
    (should (eq (ignore-errors (c-in-literal)) 'string))
    (let ((last-command-event ?=))
      (setq rc/gptel-complete-last-auto-trigger-check nil)
      (rc/gptel-complete-post-self-insert-trigger)
      (should (eq (plist-get rc/gptel-complete-last-auto-trigger-check :blocked-reason)
                  'comment-or-string))
      (should (plist-get rc/gptel-complete-last-auto-trigger-check :in-comment-or-string)))))

(ert-deftest rc/gptel-complete-auto-trigger-blocks-string-context-in-python-ts-mode ()
  
  :tags '(domain/complete-trigger prio/2)(with-temp-buffer
    (python-ts-mode)
    (gptel-autocomplete-mode 1)
    (rc/gptel-complete-set-auto-trigger-mode 'on)
    (insert "value = f\"abc {x =")
    (let ((last-command-event ?=))
      (setq rc/gptel-complete-last-auto-trigger-check nil)
      (rc/gptel-complete-post-self-insert-trigger)
      (should (eq (plist-get rc/gptel-complete-last-auto-trigger-check :blocked-reason)
                  'comment-or-string))
      (should (plist-get rc/gptel-complete-last-auto-trigger-check :in-comment-or-string)))))

(ert-deftest rc/gptel-complete-auto-trigger-blocks-preprocessor-context ()
  
  :tags '(domain/complete-trigger prio/2)(with-temp-buffer
    (c++-mode)
    (gptel-autocomplete-mode 1)
    (rc/gptel-complete-set-auto-trigger-mode 'on)
    (insert "#define VALUE =")
    (let ((last-command-event ?=))
      (setq rc/gptel-complete-last-auto-trigger-check nil)
      (rc/gptel-complete-post-self-insert-trigger)
      (should (eq (plist-get rc/gptel-complete-last-auto-trigger-check :blocked-reason)
                  'preprocessor-context))
      (should (plist-get rc/gptel-complete-last-auto-trigger-check :in-preprocessor)))))

(ert-deftest rc/gptel-complete-auto-trigger-blocks-preprocessor-context-in-c-ts-mode ()
  
  :tags '(domain/complete-trigger prio/2)(with-temp-buffer
    (c-ts-mode)
    (gptel-autocomplete-mode 1)
    (rc/gptel-complete-set-auto-trigger-mode 'on)
    (insert "#define VALUE =")
    (let ((last-command-event ?=))
      (setq rc/gptel-complete-last-auto-trigger-check nil)
      (rc/gptel-complete-post-self-insert-trigger)
      (should (eq (plist-get rc/gptel-complete-last-auto-trigger-check :blocked-reason)
                  'preprocessor-context))
      (should (plist-get rc/gptel-complete-last-auto-trigger-check :in-preprocessor)))))

(ert-deftest rc/gptel-complete-auto-trigger-blocks-preprocessor-continuation-context ()
  
  :tags '(domain/complete-trigger prio/2)(with-temp-buffer
    (c++-mode)
    (gptel-autocomplete-mode 1)
    (rc/gptel-complete-set-auto-trigger-mode 'on)
    (insert "#define FOO(x) \\\n  call<int>(x)")
    (let ((last-command-event ?\)))
      (setq rc/gptel-complete-last-auto-trigger-check nil)
      (rc/gptel-complete-post-self-insert-trigger)
      (should (eq (plist-get rc/gptel-complete-last-auto-trigger-check :blocked-reason)
                  'preprocessor-context))
      (should (plist-get rc/gptel-complete-last-auto-trigger-check :in-preprocessor)))))

(ert-deftest rc/gptel-complete-auto-trigger-blocks-capf-active ()
  
  :tags '(domain/complete-trigger risk/coordination prio/2)(with-temp-buffer
    (emacs-lisp-mode)
    (rc/gptel-complete-set-auto-trigger-mode 'on)
    (setq-local gptel-autocomplete-mode t)
    (setq-local completion-in-region-mode t)
    (insert "=")
    (setq rc/gptel-complete-last-auto-trigger-check nil)
    (rc/gptel-complete-post-self-insert-trigger)
    (should (eq (plist-get rc/gptel-complete-last-auto-trigger-check :blocked-reason)
                'capf-active))))

(ert-deftest rc/gptel-complete-auto-trigger-dedupes-duplicate-timer-fire ()
  
  :tags '(domain/complete-trigger risk/race prio/3)(with-temp-buffer
    (emacs-lisp-mode)
    (rc/test-gptel-ensure-autocomplete)
    (let ((token '(1 2 3))
          (calls 0))
      (setq-local gptel-autocomplete-mode t)
      (setq-local rc/gptel-complete-auto-trigger-enabled t)
      (setq-local rc/gptel-complete-pending-auto-trigger-token token)
      (cl-letf (((symbol-function 'gptel-complete)
                 (lambda (&rest _args)
                   (cl-incf calls)
                   t))
                ((symbol-function 'rc/gptel-prepare-inline-complete-buffer)
                 (lambda (&optional _extra) t)))
        (rc/gptel-run-complete-auto-trigger (current-buffer) (point) (buffer-chars-modified-tick) token)
        (rc/gptel-run-complete-auto-trigger (current-buffer) (point) (buffer-chars-modified-tick) token)
        (should (= calls 1))
        (should (eq (plist-get (car (rc/gptel-complete-recent-trace (current-buffer))) :event)
                    'duplicate-auto-trigger))))))

(ert-deftest rc/gptel-complete-auto-trigger-skips-foreign-buffer-change ()
  
  :tags '(domain/complete-trigger prio/2)(with-temp-buffer
    (emacs-lisp-mode)
    (rc/test-gptel-ensure-autocomplete)
    (let ((token '(1 2 4))
          requested)
      (setq-local gptel-autocomplete-mode t)
      (setq-local rc/gptel-complete-pending-auto-trigger-token token)
      (cl-letf (((symbol-function 'gptel-complete)
                 (lambda (&rest _args)
                   (setq requested t)
                   t)))
        (insert "x")
        (rc/gptel-run-complete-auto-trigger (current-buffer) (point-min) 0 token)
        (should-not requested)
        (should (eq (plist-get (car (rc/gptel-complete-recent-trace (current-buffer))) :event)
                    'stale-auto-trigger))))))

(ert-deftest rc/gptel-complete-post-self-insert-trigger-uses-tiered-delay ()
  
  :tags '(domain/complete-trigger prio/2)(with-temp-buffer
    (let (delay)
      (cl-letf (((symbol-function 'rc/gptel-complete-auto-trigger-diagnostics)
                 (lambda (&optional _event)
                   '(:eligible t :trigger-match-kind line-end)))
                ((symbol-function 'rc/gptel-complete-record-auto-trigger-check)
                 (lambda (&rest _args) nil))
                ((symbol-function 'run-with-timer)
                 (lambda (secs _repeat _fn &rest _args)
                   (setq delay secs)
                   'auto-trigger-timer)))
        (rc/gptel-complete-post-self-insert-trigger))
      (should (= delay rc/gptel-complete-auto-trigger-line-end-delay)))
    (let (delay)
      (cl-letf (((symbol-function 'rc/gptel-complete-auto-trigger-diagnostics)
                 (lambda (&optional _event)
                   '(:eligible t :trigger-match-kind direct-char)))
                ((symbol-function 'rc/gptel-complete-record-auto-trigger-check)
                 (lambda (&rest _args) nil))
                ((symbol-function 'run-with-timer)
                 (lambda (secs _repeat _fn &rest _args)
                   (setq delay secs)
                   'auto-trigger-timer)))
        (rc/gptel-complete-post-self-insert-trigger))
      (should (= delay rc/gptel-complete-auto-trigger-direct-char-delay)))))
(provide 'ai-complete-trigger-test)
;;; ai-complete-trigger-test.el ends here
