;;; ai-rewrite-runtime-test.el --- AI runtime tests, split by domain -*- lexical-binding: t; -*-

;; Auto-extracted from ai-action-runtime-test.el by tests/tools/split-by-domain.el.
;; Do not append new tests here by hand without first updating the splitter.

;;; Code:

(require 'ert)
(require 'cl-lib)

(load "/home/seeback/.emacs.rc/ai-rc.el" nil t)
(load "/home/seeback/.emacs.rc/ai/tests/helpers/ai-test-helpers.el" nil t)

(ert-deftest rc/gptel-rewrite-snapshot-prefers-shared-history ()
  
  :tags '(domain/rewrite prio/2)(with-temp-buffer
    (setq-local rc/gptel-rewrite-last-job
                (list :rewrite-id 3
                      :request-id "rewrite-3"
                      :state 'failed
                      :end-reason 'failed-request
                      :last-error "boom"
                      :last-result nil
                      :mode 'emacs-lisp-mode
                      :region '(1 . 2)))
    (setq-local rc/gptel-action-lifecycle-history
                (list (list :action-kind 'rewrite
                            :event 'rewrite-failed
                            :request-id "rewrite-3"
                            :state 'failed
                            :end-reason 'failed-request)))
    (let ((snapshot (rc/gptel-rewrite-action-snapshot)))
      (should (eq (plist-get snapshot :action-kind) 'rewrite))
      (should (eq (plist-get (car (plist-get snapshot :history)) :event)
                  'rewrite-failed))
      (should (= (length (plist-get snapshot :history)) 1))
      (should (eq (plist-get (plist-get snapshot :detail) :request-source) 'region))
      (should (eq (plist-get (plist-get snapshot :detail) :next-action-kind)
                  'retry-request)))))

(ert-deftest rc/gptel-rewrite-snapshot-ignores-empty-buffer-locals ()
  
  :tags '(domain/rewrite prio/2)(with-temp-buffer
    (setq-local rc/gptel-rewrite-last-job nil)
    (should-not (rc/gptel-rewrite-action-snapshot))))
(provide 'ai-rewrite-runtime-test)
;;; ai-rewrite-runtime-test.el ends here
