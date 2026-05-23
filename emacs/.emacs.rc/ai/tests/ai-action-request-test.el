;;; ai-action-request-test.el --- AI runtime tests, split by domain -*- lexical-binding: t; -*-

;; Auto-extracted from ai-action-runtime-test.el by tests/tools/split-by-domain.el.
;; Do not append new tests here by hand without first updating the splitter.

;;; Code:

(require 'ert)
(require 'cl-lib)

(load "/home/seeback/.emacs.rc/ai-rc.el" nil t)
(load "/home/seeback/.emacs.rc/ai/tests/helpers/ai-test-helpers.el" nil t)

(ert-deftest rc/gptel-action-send-records-success ()
  
  :tags '(domain/action-request prio/2)(with-temp-buffer
    (clrhash rc/gptel-action-request-counter-table)
    (let (callback streamed succeeded)
      (cl-letf (((symbol-function 'rc/gptel-ensure-core) (lambda () t))
                ((symbol-function 'gptel-request)
                 (lambda (_prompt &rest plist)
                   (setq callback (plist-get plist :callback))
                   'fake)))
        (rc/gptel-action-send
         :action-kind 'ask
         :buffer (current-buffer)
         :prompt "prompt"
         :position 1
         :stream t
         :system "system"
         :on-stream (lambda (response _info request)
                      (setq streamed (list response (plist-get request :request-id))))
         :on-success (lambda (_response _info request)
                       (setq succeeded (plist-get request :request-id)))))
      (should callback)
      (should (equal (plist-get (car (rc/gptel-action-request-history)) :state)
                     'requesting))
      (should (eq (plist-get (car (rc/gptel-action-lifecycle-history)) :event)
                  'request-started))
      (funcall callback "chunk" '(:status "streaming"))
      (should (equal streamed '("chunk" "ask-1")))
      (funcall callback t '(:status "ok"))
      (should (equal succeeded "ask-1"))
      (should (equal (plist-get (rc/gptel-action-last-request) :state)
                     'succeeded))
      (should (eq (plist-get (car (rc/gptel-action-lifecycle-history)) :event)
                  'request-succeeded)))))

(ert-deftest rc/gptel-action-send-records-failure-and-abort ()
  
  :tags '(domain/action-request prio/2)(with-temp-buffer
    (clrhash rc/gptel-action-request-counter-table)
    (let (callback failed aborted)
      (cl-letf (((symbol-function 'rc/gptel-ensure-core) (lambda () t))
                ((symbol-function 'gptel-request)
                 (lambda (_prompt &rest plist)
                   (setq callback (plist-get plist :callback))
                   'fake)))
        (rc/gptel-action-send
         :action-kind 'rewrite
         :buffer (current-buffer)
         :prompt "prompt"
         :position 1
         :system "system"
         :on-failure (lambda (_response info request)
                       (setq failed (list (plist-get info :status)
                                          (plist-get request :request-id))))
         :on-abort (lambda (_response _info request)
                     (setq aborted (plist-get request :request-id)))))
      (should callback)
      (funcall callback nil '(:status "boom"))
      (should (equal failed '("boom" "rewrite-1")))
      (should (equal (plist-get (rc/gptel-action-last-request) :end-reason)
                     'failed-request))
      (should (eq (plist-get (car (rc/gptel-action-lifecycle-history)) :event)
                  'request-failed)))
    (erase-buffer)
    (setq rc/gptel-action-lifecycle-history nil
          rc/gptel-action-request-history nil
          rc/gptel-action-active-request nil
          rc/gptel-action-last-request nil)
    (let (callback aborted)
      (cl-letf (((symbol-function 'rc/gptel-ensure-core) (lambda () t))
                ((symbol-function 'gptel-request)
                 (lambda (_prompt &rest plist)
                   (setq callback (plist-get plist :callback))
                   'fake)))
        (rc/gptel-action-send
         :action-kind 'rewrite
         :buffer (current-buffer)
         :prompt "prompt"
         :position 1
         :system "system"
         :on-abort (lambda (_response _info request)
                     (setq aborted (plist-get request :request-id)))))
      (funcall callback 'abort '(:status "aborted"))
      (should (equal aborted "rewrite-2"))
      (should (equal (plist-get (rc/gptel-action-last-request) :end-reason)
                     'aborted-request))
      (should (eq (plist-get (car (rc/gptel-action-lifecycle-history)) :event)
                  'request-aborted)))))

(ert-deftest rc/gptel-complete-shared-request-success ()
  
  :tags '(domain/action-request prio/2)(with-temp-buffer
    (rc/test-gptel-ensure-autocomplete)
    (rc/test-gptel-reset-runtime)
    (setq rc/gptel-action-request-history nil
          rc/gptel-action-active-request nil
          rc/gptel-action-last-request nil
          rc/gptel-action-lifecycle-history nil)
    (clrhash rc/gptel-action-request-counter-table)
    (let (callback)
      (cl-letf (((symbol-function 'gptel-request)
                 (lambda (_prompt &rest plist)
                   (setq callback (plist-get plist :callback))
                   'fake))
                ((symbol-function 'gptel--request-context)
                 #'rc/test-gptel-stub-request-context)
                ((symbol-function 'gptel--build-system-message)
                 (lambda (&optional _extra) "system")))
        (gptel-complete 'manual))
      (should callback)
      (should (equal (plist-get (rc/gptel-action-active-request) :request-id)
                     "complete-1"))
      (funcall callback "```text\n█START_COMPLETION█\nhello\n█END_COMPLETION█\n```"
               '(:status "ok"))
      (should (equal (plist-get (rc/gptel-action-last-request) :request-id)
                     "complete-1"))
      (should (eq (plist-get (rc/gptel-action-last-request) :state)
                  'succeeded))
      (should (eq (plist-get (car rc/gptel-action-lifecycle-history) :event)
                  'request-succeeded)))))

(ert-deftest rc/gptel-complete-shared-request-failure ()
  
  :tags '(domain/action-request prio/2)(with-temp-buffer
    (rc/test-gptel-ensure-autocomplete)
    (rc/test-gptel-reset-runtime)
    (setq rc/gptel-action-request-history nil
          rc/gptel-action-active-request nil
          rc/gptel-action-last-request nil
          rc/gptel-action-lifecycle-history nil)
    (clrhash rc/gptel-action-request-counter-table)
    (let (callback)
      (cl-letf (((symbol-function 'gptel-request)
                 (lambda (_prompt &rest plist)
                   (setq callback (plist-get plist :callback))
                   'fake))
                ((symbol-function 'gptel--request-context)
                 #'rc/test-gptel-stub-request-context)
                ((symbol-function 'gptel--build-system-message)
                 (lambda (&optional _extra) "system")))
        (gptel-complete 'manual))
      (should callback)
      (funcall callback nil '(:status "boom"))
      (should (equal (plist-get (rc/gptel-action-last-request) :request-id)
                     "complete-1"))
      (should (eq (plist-get (rc/gptel-action-last-request) :state)
                  'failed))
      (should (equal (plist-get (rc/gptel-action-last-request) :last-error)
                     "boom"))
      (should (eq (plist-get (car rc/gptel-action-lifecycle-history) :event)
                  'request-failed)))))

(ert-deftest rc/gptel-complete-shared-request-superseded ()
  
  :tags '(domain/action-request risk/supersede prio/2)(with-temp-buffer
    (rc/test-gptel-ensure-autocomplete)
    (rc/test-gptel-reset-runtime)
    (setq rc/gptel-action-request-history nil
          rc/gptel-action-active-request nil
          rc/gptel-action-last-request nil
          rc/gptel-action-lifecycle-history nil)
    (clrhash rc/gptel-action-request-counter-table)
    (gptel--completion-request-start-shared 7 'manual (point) "")
    (setq-local gptel--completion-request-id 8)
    (gptel--completion-handle-superseded-response
     7
     "```text\n█START_COMPLETION█\nhello\n█END_COMPLETION█\n```"
     ""
     ""
     (point))
    (should (equal (plist-get (rc/gptel-action-last-request) :request-id)
                   "complete-7"))
    (should (eq (plist-get (rc/gptel-action-last-request) :state)
                'superseded))
    (should (eq (plist-get (rc/gptel-action-last-request) :end-reason)
                'ignored-superseded))
    (should (eq (plist-get (car rc/gptel-action-lifecycle-history) :event)
                'request-superseded))))

(ert-deftest rc/gptel-action-current-snapshot-prefers-visible-complete ()
  
  :tags '(domain/action-request prio/2)(with-temp-buffer
    (setq-local rc/gptel-ask-session-id 2
                rc/gptel-ask-session-root default-directory
                rc/gptel-ask-session-file "demo.el"
                rc/gptel-ask-session-source (list :text "source")
                rc/gptel-ask-session-question-count 0
                rc/gptel-ask-session-source-count 1
                rc/gptel-ask-session-state 'ready)
    (setq-local rc/gptel-complete-session-state
                (list :visible t
                      :state 'visible
                      :request-id "complete-9"
                      :last-error nil
                      :lifecycle-history
                      (list (list :event 'visible
                                  :request-id "complete-9"
                                  :state 'visible))
                      :state-history
                      (list (list :event 'visible
                                  :state 'visible))
                      :current-profile "inline"
                      :stats '(:request-count 1)
                      :suggestion-id 9
                      :request-source 'cache
                      :cache-source 'result
                      :next-edit-id "next-edit-1"
                      :next-edit-queue-size 1
                      :next-action-kind 'next-edit
                      :next-action-count 1
                      :restore-available nil
                      :divergence-distance 0
                      :candidate-count 1
                      :candidate-index 0
                      :cache-candidate-count 1
                      :followup-queue-size 0
                      :cache-followup-count 0
                      :accepted-length 0
                      :accepted-kind nil
                      :last-command-kind nil
                      :cache-size 0
                      :superseded-ids nil))
    (cl-letf (((symbol-function 'rc/gptel-complete-session-meaningful-p)
               (lambda (&optional _buffer) t))
              ((symbol-function 'rc/gptel-sync-complete-session-state)
               (lambda () rc/gptel-complete-session-state))
              ((symbol-function 'gptel-autocomplete-visible-p) (lambda () t))
              ((symbol-function 'gptel-autocomplete-state) (lambda () 'visible)))
      (let ((snapshot (rc/gptel-action-current-snapshot)))
        (should (eq (plist-get snapshot :action-kind) 'complete))
        (should (equal (plist-get snapshot :request-id) "complete-9"))
        (should (eq (plist-get snapshot :state) 'visible))
        (should (eq (plist-get (plist-get snapshot :detail) :request-source) 'cache))
        (should (eq (plist-get (plist-get snapshot :detail) :cache-source) 'result))
        (should (eq (plist-get (plist-get snapshot :detail) :next-action-kind)
                    'next-edit))
        (should (equal (plist-get (plist-get snapshot :detail) :next-edit-id)
                       "next-edit-1"))))))
(provide 'ai-action-request-test)
;;; ai-action-request-test.el ends here
