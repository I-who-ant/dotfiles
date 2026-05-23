;;; ai-complete-observe-test.el --- AI runtime tests, split by domain -*- lexical-binding: t; -*-

;; Auto-extracted from ai-action-runtime-test.el by tests/tools/split-by-domain.el.
;; Do not append new tests here by hand without first updating the splitter.

;;; Code:

(require 'ert)
(require 'cl-lib)

(load "/home/seeback/.emacs.rc/ai-rc.el" nil t)
(load "/home/seeback/.emacs.rc/ai/tests/helpers/ai-test-helpers.el" nil t)

(ert-deftest rc/gptel-complete-diagnose-mode-echoes-blocked-reason ()
  
  :tags '(domain/complete-observe risk/observability prio/2)(with-temp-buffer
    (c++-mode)
    (rc/gptel-complete-set-auto-trigger-mode 'diagnose)
    (let (captured-message)
      (cl-letf (((symbol-function 'message)
                 (lambda (fmt &rest args)
                   (setq captured-message (apply #'format fmt args)))))
        (let ((last-command-event ?x))
          (rc/gptel-complete-post-self-insert-trigger)))
      (should (string-match-p "AI 半自动未触发\\[c\\+\\+-mode\\]" captured-message))
      (should (string-match-p "source=auto-typing" captured-message))
      (should (string-match-p "reason=autocomplete-mode-disabled" captured-message)))))

(ert-deftest rc/gptel-complete-diagnose-mode-throttles-repeated-message ()
  
  :tags '(domain/complete-observe risk/observability prio/2)(with-temp-buffer
    (c++-mode)
    (rc/gptel-complete-set-auto-trigger-mode 'diagnose)
    (let (messages)
      (cl-letf (((symbol-function 'message)
                 (lambda (fmt &rest args)
                   (push (apply #'format fmt args) messages))))
        (let ((last-command-event ?x))
          (rc/gptel-complete-post-self-insert-trigger)
          (rc/gptel-complete-post-self-insert-trigger)))
      (should (= (length messages) 1)))))

(ert-deftest rc/gptel-complete-observe-hook-records-stats-and-latency ()
  
  :tags '(domain/complete-observe risk/observability prio/2)(rc/test-gptel-reset-observe-global)
  (with-temp-buffer
    (rc/test-gptel-reset-runtime)
    (rc/gptel-complete-observe-lifecycle-hook
     '(:event request-started
       :request-id 1
       :source manual
       :timestamp 10.0))
    (rc/gptel-complete-observe-lifecycle-hook
     '(:event visible
       :request-id 1
       :source manual
       :state visible
       :timestamp 10.2))
    (rc/gptel-complete-observe-lifecycle-hook
     '(:event finalized
       :request-id 1
       :state accepted
       :end-reason accepted-full
       :timestamp 10.3))
    (let* ((local (rc/gptel-complete-current-buffer-observe-stats))
           (global (rc/gptel-complete-global-observe-stats))
           (timeline (car (rc/gptel-complete-request-timelines (current-buffer)))))
      (should (= (plist-get local :request-count) 1))
      (should (= (plist-get local :request-succeeded-count) 1))
      (should (= (plist-get local :accepted-full-count) 1))
      (should (= (plist-get local :cache-miss-count) 1))
      (should (= (plist-get global :request-count) 1))
      (should (equal (alist-get 'manual (plist-get local :trigger-source-counts)) 1))
      (should (= (plist-get timeline :started-at) 10.0))
      (should (= (plist-get timeline :first-stream-at) 10.2))
      (should (= (plist-get timeline :completed-at) 10.2))
      (should (eq (plist-get timeline :outcome) 'succeeded)))))

(ert-deftest rc/gptel-complete-observe-trace-trims-and-reset-works ()
  
  :tags '(domain/complete-observe risk/observability risk/race prio/2)(rc/test-gptel-reset-observe-global)
  (with-temp-buffer
    (rc/test-gptel-reset-runtime)
    (let ((rc/gptel-complete-observe-trace-length 3))
      (dotimes (i 5)
        (rc/gptel-complete-observe-lifecycle-hook
         (list :event 'request-started
               :request-id i
               :source 'manual
               :timestamp (+ 10 i)))))
    (should (= (length (rc/gptel-complete-recent-trace (current-buffer))) 3))
    (should (= (length rc/gptel-complete-global-observe-trace) 3))
    (rc/gptel-stats-reset t)
    (should (= (length (rc/gptel-complete-recent-trace (current-buffer))) 0))
    (should (= (plist-get (rc/gptel-complete-current-buffer-observe-stats) :request-count) 0))
    (should (= (length rc/gptel-complete-global-observe-trace) 0))
    (should (= (plist-get (rc/gptel-complete-global-observe-stats) :request-count) 0))))

(ert-deftest rc/gptel-complete-export-trace-redacts-by-default-and-supports-markdown ()
  
  :tags '(domain/complete-observe risk/observability risk/race prio/2)(rc/test-gptel-reset-observe-global)
  (with-temp-buffer
    (rc/test-gptel-reset-runtime)
    (setq-local rc/gptel-action-request-history
                (list (list :action-kind 'complete
                            :request-id "complete-1"
                            :prompt (concat "abcdefghijklmnopqrstuvwxyz0123456789"
                                            "ABCDEFGHIJKLMNOPQRSTUVWXYZ")
                            :system "system prompt"
                            :state 'succeeded)))
    (rc/gptel-complete-observe-lifecycle-hook
     '(:event request-started
       :request-id 1
       :source manual
       :timestamp 10.0))
    (let ((elisp-export (rc/gptel-export-recent-ai-trace 'elisp nil (current-buffer)))
          (raw-export (rc/gptel-export-recent-ai-trace 'elisp t (current-buffer)))
          (markdown-export (rc/gptel-export-recent-ai-trace 'markdown nil (current-buffer))))
      (should (string-match-p "\\.\\.\\[redacted\\]\\|…\\[redacted\\]" elisp-export))
      (should (string-match-p "ABCDEFGHIJKLMNOPQRSTUVWXYZ" raw-export))
      (should (string-match-p "^# AI Trace:" markdown-export))
      (should (string-match-p "| ts | kind | event | state | request | source | end |"
                              markdown-export)))))

(ert-deftest rc/gptel-complete-stats-report-shows-current-buffer-and-global ()
  
  :tags '(domain/complete-observe risk/observability prio/2)(rc/test-gptel-reset-observe-global)
  (with-temp-buffer
    (rc/test-gptel-reset-runtime)
    (rc/gptel-complete-observe-lifecycle-hook
     '(:event request-started :request-id 1 :source manual :timestamp 1.0))
    (rc/gptel-complete-observe-lifecycle-hook
     '(:event visible :request-id 1 :source manual :state visible :timestamp 1.2))
    (with-temp-buffer
      (rc/test-gptel-reset-runtime)
      (rc/gptel-complete-observe-lifecycle-hook
       '(:event request-started :request-id 2 :source auto :timestamp 2.0))
      (rc/gptel-complete-observe-lifecycle-hook
       '(:event finalized :request-id 2 :state failed :end-reason failed-request :timestamp 2.4)))
    (let ((report (rc/gptel-stats (current-buffer))))
      (should (string-match-p "Current Buffer (since reset):" report))
      (should (string-match-p "requests=1 succeeded=1 failed=0 aborted=0 superseded=0" report))
      (should (string-match-p "Global Lifetime:" report))
      (should (string-match-p "requests=2 succeeded=1 failed=1 aborted=0 superseded=0" report)))))

(ert-deftest rc/gptel-complete-status-indicator-clears-after-status ()
  
  :tags '(domain/complete-observe risk/observability prio/2)(with-temp-buffer
    (rc/test-gptel-ensure-autocomplete)
    (rc/test-gptel-reset-runtime)
    (gptel--completion-show-status-indicator 'failed)
    (should (eq (gptel-autocomplete-status-indicator) 'failed))
    (should (string-match-p "!" (gptel--completion-mode-lighter)))
    (gptel--completion-clear-status-indicator)
    (should-not (gptel-autocomplete-status-indicator))))
(provide 'ai-complete-observe-test)
;;; ai-complete-observe-test.el ends here
