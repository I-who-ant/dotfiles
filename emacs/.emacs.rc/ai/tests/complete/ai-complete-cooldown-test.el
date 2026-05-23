;;; ai-complete-cooldown-test.el --- AI runtime tests, split by domain -*- lexical-binding: t; -*-

;; Auto-extracted from ai-action-runtime-test.el by tests/tools/split-by-domain.el.
;; Do not append new tests here by hand without first updating the splitter.

;;; Code:

(require 'ert)
(require 'cl-lib)

(load "/home/seeback/.emacs.rc/ai-rc.el" nil t)
(load "/home/seeback/.emacs.rc/ai/tests/helpers/ai-test-helpers.el" nil t)

(ert-deftest rc/gptel-complete-cooldown-records-from-lifecycle-on-auto-ignore ()
  
  :tags '(domain/complete-cooldown prio/3)(with-temp-buffer
    (rc/gptel-complete-session-reset)
    (rc/gptel-complete-session-update :request-source 'auto)
    (setq rc/gptel-complete-cooldown-table nil)
    (insert "if x")
    (let ((rc/gptel-complete-cooldown-threshold 3))
      (rc/gptel-complete-record-cooldown-from-lifecycle
       (list :end-reason 'ignored-point-move :request-id "r1"))
      (rc/gptel-complete-record-cooldown-from-lifecycle
       (list :end-reason 'ignored-point-move :request-id "r2"))
      (let ((entry (rc/gptel-complete-cooldown-entry)))
        (should entry)
        (should (= (plist-get entry :count) 2))
        (should (eq (plist-get entry :last-reason) 'ignored-point-move))
        (should (null (rc/gptel-complete-cooldown-active-entry))))
      (rc/gptel-complete-record-cooldown-from-lifecycle
       (list :end-reason 'rejected-user :request-id "r3"))
      (let ((entry (rc/gptel-complete-cooldown-entry)))
        (should (= (plist-get entry :count) 3))
        (should (rc/gptel-complete-cooldown-active-entry))))))

(ert-deftest rc/gptel-complete-cooldown-tracks-reason-counts-per-bucket ()
  
  :tags '(domain/complete-cooldown prio/3)(with-temp-buffer
    (rc/gptel-complete-session-reset)
    (rc/gptel-complete-session-update :request-source 'auto)
    (setq rc/gptel-complete-cooldown-table nil)
    (insert "if x")
    (rc/gptel-complete-record-cooldown-from-lifecycle
     (list :end-reason 'ignored-point-move))
    (rc/gptel-complete-record-cooldown-from-lifecycle
     (list :end-reason 'ignored-typing-disagreed))
    (rc/gptel-complete-record-cooldown-from-lifecycle
     (list :end-reason 'ignored-typing-disagreed))
    (let* ((entry (rc/gptel-complete-cooldown-entry))
           (counts (plist-get entry :reason-counts)))
      (should (= (or (alist-get 'ignored-point-move counts nil nil #'eq) 0) 1))
      (should (= (or (alist-get 'ignored-typing-disagreed counts nil nil #'eq) 0) 2)))))

(ert-deftest rc/gptel-complete-cooldown-skips-non-auto-request-sources ()
  
  :tags '(domain/complete-cooldown risk/source-consistency prio/3)(with-temp-buffer
    (rc/gptel-complete-session-reset)
    (rc/gptel-complete-session-update :request-source 'manual)
    (setq rc/gptel-complete-cooldown-table nil)
    (insert "if x")
    (rc/gptel-complete-record-cooldown-from-lifecycle
     (list :end-reason 'ignored-point-move))
    (rc/gptel-complete-record-cooldown-from-lifecycle
     (list :end-reason 'rejected-user))
    (should (null (rc/gptel-complete-cooldown-entry)))))

(ert-deftest rc/gptel-complete-cooldown-key-changes-on-prefix-edit ()
  
  :tags '(domain/complete-cooldown prio/3)(with-temp-buffer
    (rc/gptel-complete-session-reset)
    (rc/gptel-complete-session-update :request-source 'auto)
    (setq rc/gptel-complete-cooldown-table nil)
    (insert "if x")
    (let ((rc/gptel-complete-cooldown-threshold 2))
      (rc/gptel-complete-record-cooldown-from-lifecycle
       (list :end-reason 'ignored-point-move))
      (rc/gptel-complete-record-cooldown-from-lifecycle
       (list :end-reason 'ignored-point-move))
      (should (rc/gptel-complete-cooldown-active-entry))
      ;; user edits the prefix; key should shift
      (insert " == 1")
      (should (null (rc/gptel-complete-cooldown-active-entry))))))

(ert-deftest rc/gptel-complete-compute-next-policy-force-stop-returns-idle ()
  
  :tags '(domain/complete-cooldown risk/accept-intent prio/3)(with-temp-buffer
    (rc/gptel-complete-session-reset)
    (cl-letf (((symbol-function 'gptel-autocomplete-next-edit-queue-size)
               (lambda () 0))
              ((symbol-function 'gptel-autocomplete-cursor-prediction-available-p)
               (lambda () nil)))
      (let ((rc/gptel-complete-pending-accept-intent 'force-stop))
        (let ((policy (rc/gptel-complete-compute-next-policy
                       (list :partial nil :accepted-text "foo"))))
          (should (eq (plist-get policy :kind) 'idle))
          (should (eq (plist-get policy :reason) 'forced-stop))
          (should (eq (plist-get policy :override) 'force-stop)))))))

(ert-deftest rc/gptel-complete-compute-next-policy-force-followup-returns-followup ()
  
  :tags '(domain/complete-cooldown risk/accept-intent prio/3)(with-temp-buffer
    (rc/gptel-complete-session-reset)
    (cl-letf (((symbol-function 'gptel-autocomplete-next-edit-queue-size)
               (lambda () 0))
              ((symbol-function 'gptel-autocomplete-cursor-prediction-available-p)
               (lambda () nil)))
      (let ((rc/gptel-complete-pending-accept-intent 'force-followup))
        (let ((policy (rc/gptel-complete-compute-next-policy
                       (list :partial nil :accepted-text "foo"))))
          (should (eq (plist-get policy :kind) 'followup))
          (should (eq (plist-get policy :reason) 'forced))
          (should (eq (plist-get policy :override) 'force-followup)))))))

(ert-deftest rc/gptel-complete-compute-next-policy-chain-limit-yields-idle ()
  
  :tags '(domain/complete-cooldown risk/accept-intent prio/3)(with-temp-buffer
    (rc/gptel-complete-session-reset)
    (setq rc/gptel-complete-continuation-stopped-by-limit-count 0)
    (cl-letf (((symbol-function 'gptel-autocomplete-next-edit-queue-size)
               (lambda () 0))
              ((symbol-function 'gptel-autocomplete-cursor-prediction-available-p)
               (lambda () nil)))
      (let ((rc/gptel-complete-auto-continuation-chain-length 3)
            (rc/gptel-complete-auto-continuation-chain-limit 3))
        (let ((policy (rc/gptel-complete-compute-next-policy
                       (list :partial nil :accepted-text "foo"))))
          (should (eq (plist-get policy :kind) 'idle))
          (should (eq (plist-get policy :reason) 'chain-limit-reached))
          (rc/gptel-complete--apply-intent-counters policy)
          (should (= rc/gptel-complete-continuation-stopped-by-limit-count 1)))))))


;;;; Coordination with trigger ------------------------------------------------
;; Phase 04 additions: verify cooldown participates in auto-trigger gating.

(ert-deftest rc/gptel-complete-cooldown-active-marks-auto-trigger-blocked ()
  "Cooldown active should surface `cooldown-active' as the auto-trigger block reason.
This validates the integration between `rc/gptel-complete-cooldown-active-entry'
and `rc/gptel-complete-auto-trigger-blocked-reason' — the two have separate
tests for their internal behavior, but the connection point was previously
not exercised."
  :tags '(domain/complete-cooldown risk/coordination prio/3)
  (with-temp-buffer
    (setq-local rc/gptel-complete-auto-trigger-enabled t)
    (setq-local gptel-autocomplete-mode t)
    (cl-letf (((symbol-function 'rc/gptel-complete-environment-blocked-reason)
               (lambda (&rest _) nil))
              ((symbol-function 'rc/gptel-inline-completion-visible-p)
               (lambda () nil))
              ((symbol-function 'rc/gptel-complete-policy-allows-point-context-p)
               (lambda () t))
              ((symbol-function 'rc/gptel-complete-in-preprocessor-p)
               (lambda () nil))
              ((symbol-function 'gptel-autocomplete-active-request-id)
               (lambda () nil))
              ((symbol-function 'rc/gptel-complete-trigger-match-kind)
               (lambda (&optional _e) 'word)))
      ;; Baseline: cooldown inactive → reason is not cooldown.
      (cl-letf (((symbol-function 'rc/gptel-complete-cooldown-active-entry)
                 (lambda () nil)))
        (should-not (eq (rc/gptel-complete-auto-trigger-blocked-reason ?a)
                        'cooldown-active)))
      ;; Once cooldown is active, the reason flips to `cooldown-active'.
      (cl-letf (((symbol-function 'rc/gptel-complete-cooldown-active-entry)
                 (lambda () (list :count 3 :last-reason 'ignored-point-move))))
        (should (eq (rc/gptel-complete-auto-trigger-blocked-reason ?a)
                    'cooldown-active))))))

(ert-deftest rc/gptel-complete-cooldown-active-marks-auto-trigger-ineligible ()
  "Cooldown active should make `auto-trigger-eligible-p' return nil.
Mirrors the blocked-reason test but on the boolean eligibility path."
  :tags '(domain/complete-cooldown risk/coordination prio/3)
  (with-temp-buffer
    (setq-local rc/gptel-complete-auto-trigger-enabled t)
    (setq-local gptel-autocomplete-mode t)
    (cl-letf (((symbol-function 'rc/gptel-complete-environment-auto-allowed-p)
               (lambda () t))
              ((symbol-function 'rc/gptel-inline-completion-visible-p)
               (lambda () nil))
              ((symbol-function 'rc/gptel-complete-policy-allows-point-context-p)
               (lambda () t))
              ((symbol-function 'gptel-autocomplete-active-request-id)
               (lambda () nil)))
      ;; Cooldown inactive: eligibility may pass given the stubs above.
      (cl-letf (((symbol-function 'rc/gptel-complete-cooldown-active-entry)
                 (lambda () nil)))
        (should (rc/gptel-complete-auto-trigger-eligible-p)))
      ;; Cooldown active: eligibility flips to nil regardless of other gates.
      (cl-letf (((symbol-function 'rc/gptel-complete-cooldown-active-entry)
                 (lambda () (list :count 5 :last-reason 'rejected-user))))
        (should-not (rc/gptel-complete-auto-trigger-eligible-p))))))

(ert-deftest rc/gptel-complete-cooldown-summary-formats-count-and-reason ()
  "Cooldown summary string includes count, threshold, and last-reason.
Phase 04 addition for `risk/observability' coverage of the cooldown surface."
  :tags '(domain/complete-cooldown risk/observability prio/2)
  (let ((rc/gptel-complete-cooldown-threshold 3))
    ;; No entry → nil.
    (should (null (rc/gptel-complete-cooldown-summary nil)))
    ;; Explicit entry → formatted string.
    (should (equal
             (rc/gptel-complete-cooldown-summary
              (list :count 4
                    :last-reason 'ignored-point-move))
             "4/3 via ignored-point-move"))
    ;; Missing last-reason falls back to `unknown'.
    (should (equal
             (rc/gptel-complete-cooldown-summary
              (list :count 2))
             "2/3 via unknown"))))

(provide 'ai-complete-cooldown-test)
;;; ai-complete-cooldown-test.el ends here
