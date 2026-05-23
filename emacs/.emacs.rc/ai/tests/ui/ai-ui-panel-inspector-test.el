;;; ai-ui-panel-inspector-test.el --- AI runtime tests, split by domain -*- lexical-binding: t; -*-

;; Auto-extracted from ai-action-runtime-test.el by tests/tools/split-by-domain.el.
;; Do not append new tests here by hand without first updating the splitter.

;;; Code:

(require 'ert)
(require 'cl-lib)

(load "/home/seeback/.emacs.rc/ai-rc.el" nil t)
(load "/home/seeback/.emacs.rc/ai/tests/helpers/ai-test-helpers.el" nil t)

(ert-deftest rc/gptel-replay-ai-trace-summarizes-suppressions-and-final-state ()
  
  :tags '(domain/replay risk/observability risk/race prio/2)(let* ((data '(:buffer "*demo*"
                 :major-mode emacs-lisp-mode
                 :recent-trace ((:kind suppress :reason company-active
                                  :trigger-kind manual :yield-target company)
                                (:kind timer :event auto-trigger-scheduled
                                  :trigger-kind auto :token (1 2 3))
                                (:kind lifecycle :event request-started
                                  :request-id "complete-1" :state requesting)
                                (:kind lifecycle :event visible
                                  :request-id "complete-1" :state visible)
                                (:kind lifecycle :event finalized
                                  :request-id "complete-1" :state accepted
                                  :end-reason accepted-full))))
         (summary (rc/gptel-replay-ai-trace data)))
    (should (= (plist-get summary :request-start-count) 1))
    (should (eq (plist-get summary :final-end-reason) 'accepted-full))
    (should (eq (plist-get (car (plist-get summary :suppress-reasons)) :reason)
                'company-active))
    (should (eq (plist-get (car (plist-get summary :timer-events)) :event)
                'auto-trigger-scheduled))))

(ert-deftest rc/gptel-complete-hint-label-shows-action-pills ()
  
  :tags '(domain/ui-panel risk/observability prio/2)(with-temp-buffer
    (rc/test-gptel-ensure-autocomplete)
    (setq-local gptel--current-suggestion
                (gptel--make-suggestion :request-source 'cache-refresh))
    (cl-letf (((symbol-function 'gptel-autocomplete-candidate-count) (lambda () 2))
              ((symbol-function 'gptel-autocomplete-next-edit-queue-size) (lambda () 1))
              ((symbol-function 'gptel-autocomplete-next-action-kind) (lambda () 'next-location)))
      (should (equal (gptel--completion-hint-label)
                     "[refresh M-j jump c2 n1] ")))
    (cl-letf (((symbol-function 'gptel-autocomplete-candidate-count) (lambda () 0))
              ((symbol-function 'gptel-autocomplete-next-edit-queue-size) (lambda () 0))
              ((symbol-function 'gptel-autocomplete-next-action-kind) (lambda () 'restore-available)))
      (should (equal (gptel--completion-hint-label)
                     "[refresh DEL restore] ")))
    (setq-local gptel--current-suggestion
                (gptel--make-suggestion :request-source 'followup))
    (cl-letf (((symbol-function 'gptel-autocomplete-candidate-count) (lambda () 0))
              ((symbol-function 'gptel-autocomplete-next-edit-queue-size) (lambda () 2))
              ((symbol-function 'gptel-autocomplete-next-action-kind) (lambda () 'next-edit)))
      (should (equal (gptel--completion-hint-label)
                     "[next-edit M-RET next n2] ")))))

(ert-deftest rc/gptel-complete-multi-line-render-uses-secondary-face ()
  
  :tags '(domain/ui-panel prio/2)(with-temp-buffer
    (rc/test-gptel-ensure-autocomplete)
    (let* ((rendered (gptel--completion-render-ghost-text "line1\nline2"))
           (face2 (get-text-property (1+ (length "line1")) 'face rendered)))
      (should (equal (substring-no-properties rendered) "line1\nline2"))
      (should (eq face2 'gptel-autocomplete-secondary-face)))))

(ert-deftest rc/gptel-complete-hint-label-shows-distance-summaries ()
  
  :tags '(domain/ui-panel risk/observability prio/2)(with-temp-buffer
    (rc/test-gptel-ensure-autocomplete)
    (insert "a\nb\nc\n")
    (goto-char (point-min))
    (setq-local gptel--current-suggestion
                (gptel--make-suggestion :request-source 'followup
                                        :next-edit-queue
                                        (list '(:id "next-edit-1"
                                                :text "\nline2\nline3"))))
    (gptel--runtime-set :cursor-prediction-target
                        (list :id "cursor-target-1"
                              :buffer (current-buffer)
                              :marker (copy-marker (point-max))
                              :point (point-max)))
    (cl-letf (((symbol-function 'gptel-autocomplete-next-action-kind) (lambda () 'next-edit)))
      (should (string-match-p "M-RET next ↓" (gptel--completion-hint-label))))
    (cl-letf (((symbol-function 'gptel-autocomplete-next-action-kind) (lambda () 'next-location)))
      (should (string-match-p "M-j jump ↓" (gptel--completion-hint-label))))))

(ert-deftest rc/gptel-action-panel-builds-entries-from-snapshots ()
  
  :tags '(domain/ui-panel risk/observability prio/2)(with-temp-buffer
    (let ((snapshots
            (list
             (list :action-kind 'complete
                   :title "complete:*temp*"
                   :buffer (current-buffer)
                  :request-id "complete-1"
                  :state 'visible
                  :end-reason nil
                  :visible t
                  :last-error nil
                   :detail (list :file "demo.el"
                                 :request-source 'cache
                                 :cache-source 'result
                                 :next-edit-id "next-edit-1"
                                 :next-edit-queue-size 1
                                 :cursor-prediction-target-id "cursor-target-1"
                                 :cursor-prediction-target-point 42
                                 :cursor-prediction-target-available t
                                 :next-action-kind 'next-edit
                                 :next-action-count 1))
            (list :action-kind 'rewrite
                  :title "rewrite:*temp*"
                  :buffer (current-buffer)
                  :request-id "rewrite-1"
                  :state 'failed
                  :end-reason 'failed-request
                  :visible nil
                  :last-error "boom"
                  :detail (list :region '(1 . 2))))))
      (cl-letf (((symbol-function 'rc/gptel-action-snapshots)
                 (lambda () snapshots)))
        (let ((entries (rc/gptel-action-panel-entries)))
          (should (= (length entries) 2))
          (should (equal (aref (cadar entries) 0) "complete"))
          (should (equal (aref (cadar entries) 3) "complete-1"))
          (should (equal (aref (cadar entries) 4) "cache:result"))
          (should (equal (aref (cadar entries) 7) "next-edit/1"))
          (should (equal (aref (cadr (cadr entries)) 0) "rewrite")))))))

;; Calibration case: 2026-05-18 / ui-panel-rewrite-bleed-001
(ert-deftest rc/gptel-action-snapshots-skip-inert-rewrite-buffers ()
  
  :tags '(domain/ui-panel risk/observability risk/source-consistency prio/3)(let ((rewrite-buffer (generate-new-buffer " *rewrite-inert*"))
        (complete-buffer (generate-new-buffer " *complete-live*")))
    (unwind-protect
        (progn
          (with-current-buffer rewrite-buffer
            (setq-local rc/gptel-rewrite-last-job
                        '(:rewrite-id 8
                          :mode text-mode
                          :region (1 . 2)
                          :request-id nil
                          :state nil
                          :last-error nil
                          :last-result nil)))
          (with-current-buffer complete-buffer
            (setq-local rc/gptel-complete-session-state
                        (list :visible t
                              :state 'visible
                              :request-id "complete-8"
                              :lifecycle-history
                              (list (list :event 'visible
                                          :request-id "complete-8"
                                          :state 'visible)))))
          (let ((snapshots (rc/gptel-action-snapshots)))
            (should (= (length snapshots) 1))
            (should (eq (plist-get (car snapshots) :action-kind) 'complete))
            (should (equal (plist-get (car snapshots) :request-id) "complete-8"))))
      (kill-buffer rewrite-buffer)
      (kill-buffer complete-buffer))))

(ert-deftest rc/gptel-action-panel-current-snapshot-roundtrip ()
  
  :tags '(domain/ui-panel risk/observability prio/2)(with-temp-buffer
    (rc/gptel-action-panel-mode)
    (let ((snapshot (list :action-kind 'ask :title "ask:*temp*" :buffer (current-buffer))))
      (setq tabulated-list-entries (list (rc/gptel-action-panel--entry snapshot)))
      (tabulated-list-print t)
      (goto-char (point-min))
      (search-forward "ask:*temp*")
      (beginning-of-line)
      (should (eq (plist-get (rc/gptel-action-panel-current-snapshot) :action-kind)
                  'ask)))))

(ert-deftest rc/gptel-action-panel-command-initializes-buffer ()
  
  :tags '(domain/ui-panel risk/observability prio/2)(let ((snapshot (list :action-kind 'ask
                        :title "ask:*temp*"
                        :buffer (current-buffer)
                        :request-id "ask-1"
                        :state 'ready
                        :end-reason nil
                        :visible nil
                        :last-error nil
                        :detail nil)))
    (cl-letf (((symbol-function 'rc/gptel-action-snapshots)
               (lambda () (list snapshot))))
      (rc/gptel-action-panel)
      (with-current-buffer "*AI Actions*"
        (should (eq major-mode 'rc/gptel-action-panel-mode))
        (should (equal (lookup-key rc/gptel-action-panel-mode-map (kbd "g"))
                       #'rc/gptel-action-panel-revert))
        (should (equal (lookup-key rc/gptel-action-panel-mode-map (kbd "RET"))
                       #'rc/gptel-action-panel-visit))
        (should (equal (lookup-key rc/gptel-action-panel-mode-map (kbd "i"))
                       #'rc/gptel-action-panel-inspect))
        (should (equal (lookup-key rc/gptel-action-panel-mode-map (kbd "q"))
                       #'quit-window))
        (should (= (length tabulated-list-entries) 1))
        (should (= (length tabulated-list-format) 10)))
      (kill-buffer "*AI Actions*"))))

(ert-deftest rc/gptel-action-panel-mode-header-shows-inline-keys ()
  
  :tags '(domain/ui-panel risk/observability prio/2)(with-temp-buffer
    (rc/gptel-action-panel-mode)
    (let ((header-text (format "%s" header-line-format)))
      (should (string-match-p "TAB accept" header-text))
      (should (string-match-p "M-RET next-edit" header-text))
      (should (string-match-p "M-j jump" header-text))
      (should (string-match-p "C-g clear" header-text)))))

(ert-deftest rc/gptel-action-panel-entry-uses-readable-labels ()
  
  :tags '(domain/ui-panel risk/observability prio/2)(let* ((snapshot (list :action-kind 'complete
                         :title "complete:*temp*"
                         :buffer (current-buffer)
                         :request-id "complete-9"
                         :state 'visible
                         :end-reason 'accepted-word
                         :visible t
                         :last-error nil
                         :detail '(:request-source cache
                                   :cache-source superseded
                                   :candidate-count 2
                                   :next-edit-queue-size 1
                                   :accepted-kind word
                                   :next-action-kind next-edit
                                   :next-action-count 1)))
         (entry (rc/gptel-action-panel--entry snapshot))
         (cols (cadr entry)))
    (should (string-match-p "cache:superseded" (aref cols 4)))
    (should (string-match-p "visible vis end:accepted" (aref cols 5)))
    (should (string-match-p "cand:2 next:1 acc:word/0" (aref cols 6)))
    (should (string-match-p "next-edit/1" (aref cols 7)))
    (should (string= "visible" (aref cols 9)))))

(ert-deftest rc/gptel-describe-action-state-renders-shared-sections ()
  
  :tags '(domain/describe risk/observability prio/2)(with-temp-buffer
    (let ((snapshot
           (list :action-kind 'rewrite
                 :title "rewrite:*temp*"
                 :buffer (current-buffer)
                 :request-id "rewrite-3"
                 :state 'failed
                 :end-reason 'failed-request
                 :visible nil
                 :last-error "boom"
                 :backend 'demo-backend
                 :model 'demo-model
                 :profile nil
                 :stats '(:request-count 2 :failure-count 1)
                 :history (list (list :event 'rewrite-failed
                                      :state 'failed
                                      :request-id "rewrite-3"
                                      :end-reason 'failed-request))
                 :transitions (list (list :state 'failed
                                          :previous-state 'requesting
                                          :event 'rewrite-failed
                                          :end-reason 'failed-request))
                 :detail (list :rewrite-id 3
                               :mode 'text-mode
                               :region '(1 . 2)
                               :result "patched"))))
      (cl-letf (((symbol-function 'rc/gptel-action-current-snapshot)
                 (lambda (&optional _buffer) snapshot))
                ((symbol-function 'rc/gptel-action-snapshots)
                 (lambda ()
                   (list snapshot
                         (list :action-kind 'ask
                               :title "ask:*other*"
                               :buffer (current-buffer)
                               :request-id "ask-1"
                               :state 'ready)))))
        (rc/gptel-describe-action-state)
        (with-current-buffer "*AI Action State*"
          (let ((rendered (buffer-string)))
            (should (string-match-p "Overview:" rendered))
            (should (string-match-p "kind: rewrite" rendered))
            (should (string-match-p "Recent History:" rendered))
            (should (string-match-p "Recent State Transitions:" rendered))
            (should (string-match-p "All Active Snapshots:" rendered))
            (should (string-match-p "\\*` 表示当前 buffer\\|`\\*` 表示当前 buffer" rendered))
            (should (string-match-p "rewrite-id: 3" rendered))
            (should (string-match-p "request=ask-1" rendered))
            (should (string-match-p "source=none" rendered))))
        (kill-buffer "*AI Action State*")))))

(ert-deftest rc/gptel-action-detail-renderer-complete-includes-cache-fields ()
  
  :tags '(domain/ui-inspector risk/cache-hit prio/2)(let ((lines (rc/gptel-action--detail-renderer
                (list :action-kind 'complete
                      :detail '(:suggestion-id 9
                                :request-source cache
                                :cache-source result
                                :next-edit-id "next-edit-1"
                                :next-edit-queue-size 1
                                :next-action-kind next-edit
                                :next-action-count 1
                                :restore-available nil
                                :divergence-distance 0
                                :candidate-index 0
                                :candidate-count 2
                                :cache-candidate-count 2
                                :followup-queue-size 1
                                :cache-followup-count 1
                                :accepted-length 0
                                :accepted-kind nil
                                :current-profile nil
                                :cache-size 1
                                :last-command-kind manual)))))
    (should (seq-some (lambda (line)
                        (string-match-p "cache-source: result" line))
                      lines))
    (should (seq-some (lambda (line)
                        (string-match-p "next-action: next-edit" line))
                      lines))
    (should (seq-some (lambda (line)
                        (string-match-p "next-action-count: 1" line))
                      lines))
    (should (seq-some (lambda (line)
                        (string-match-p "next-edit-id: next-edit-1" line))
                      lines))
    (should (seq-some (lambda (line)
                        (string-match-p "cache-candidate-count: 2" line))
                      lines))
    (should (seq-some (lambda (line)
                        (string-match-p "cache-next-edit-count: 1" line))
                      lines))))

(ert-deftest rc/gptel-show-answer-buffer-does-not-steal-selected-window ()
  
  :tags '(domain/ui-panel risk/race prio/2)(let ((answer-buffer (generate-new-buffer " *answer-window*"))
        (home-buffer (generate-new-buffer " *home-window*")))
    (unwind-protect
        (save-window-excursion
          (switch-to-buffer home-buffer)
          (with-current-buffer answer-buffer
            (insert "hello\nworld\n"))
          (let ((selected-before (selected-window))
                (window (rc/gptel-show-answer-buffer answer-buffer)))
            (should (window-live-p window))
            (should (eq (selected-window) selected-before))
            (should (eq (window-buffer window) answer-buffer))))
      (kill-buffer answer-buffer)
      (kill-buffer home-buffer))))

(ert-deftest rc/gptel-answer-window-follow-state-uses-visible-bottom-not-window-point ()
  
  :tags '(domain/ui-panel risk/race prio/2)
  (let ((answer-buffer (generate-new-buffer " *answer-follow*")))
    (unwind-protect
        (save-window-excursion
          (switch-to-buffer answer-buffer)
          (dotimes (i 120)
            (insert (format "line-%03d\n" i)))
          (let ((window (selected-window))
                (orig-window-end (symbol-function 'window-end)))
            (set-window-point window (point-max))
            (cl-letf (((symbol-function 'window-end)
                       (lambda (win &optional _update)
                         (if (eq win window)
                             (point-max)
                           (funcall orig-window-end win)))))
              (should (rc/gptel-answer-window-follow-p window)))
            (cl-letf (((symbol-function 'window-end)
                       (lambda (win &optional _update)
                         (if (eq win window)
                             (point-min)
                           (funcall orig-window-end win)))))
              (should-not (rc/gptel-answer-window-follow-p window)))))
      (kill-buffer answer-buffer))))
(provide 'ai-ui-panel-inspector-test)
;;; ai-ui-panel-inspector-test.el ends here
