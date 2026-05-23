;;; ai-complete-state-test.el --- AI runtime tests, split by domain -*- lexical-binding: t; -*-

;; Auto-extracted from ai-action-runtime-test.el by tests/tools/split-by-domain.el.
;; Do not append new tests here by hand without first updating the splitter.

;;; Code:

(require 'ert)
(require 'cl-lib)

(load "/home/seeback/.emacs.rc/ai-rc.el" nil t)
(load "/home/seeback/.emacs.rc/ai/tests/helpers/ai-test-helpers.el" nil t)

(ert-deftest rc/gptel-complete-normalize-invalidated-edit ()
  
  :tags '(domain/complete-state prio/2)(let ((entry (rc/gptel-complete-normalize-entry
                '(:event invalidated-edit
                  :state invalidated
                  :previous-state visible
                  :end-reason ignored-buffer-edit
                  :request-id 42))))
    (should (eq (plist-get entry :event) 'finalized))
    (should (eq (plist-get entry :state) 'ignored))
    (should (eq (plist-get entry :previous-state) 'visible))
    (should (eq (plist-get entry :end-reason) 'ignored-buffer-edit))))

(ert-deftest rc/gptel-complete-sync-session-state-normalizes-suggestion ()
  
  :tags '(domain/complete-state prio/2)(with-temp-buffer
    (setq-local gptel-autocomplete-mode t)
    (setq-local gptel--current-suggestion
                '(:id 7
                  :request-id 42
                  :request-source manual
                  :state invalidated
                  :accepted-length 3
                  :accepted-kind word
                  :candidate-index 1
                  :candidate-count 2
                  :followup-queue ("next")
                  :last-end-reason ignored-buffer-edit
                  :last-command-kind delete
                  :recent-events ((:event invalidated-edit
                                   :state invalidated
                                   :end-reason ignored-buffer-edit))))
    (setq-local gptel--completion-state-history
                '((:state invalidated
                   :previous-state visible
                   :event invalidated-edit
                   :end-reason ignored-buffer-edit)))
    (setq-local gptel--completion-lifecycle-history
                '((:event invalidated-edit
                   :state invalidated
                   :end-reason ignored-buffer-edit)))
    (setq-local gptel--autocomplete-runtime-state
                '(:active-request-id 42
                  :superseded-request-ids (9)
                  :last-result (:request-id 42)
                  :cache (a b)
                  :last-visible-text "ghost"
                  :last-error nil
                  :candidates (a b)))
    (cl-letf (((symbol-function 'gptel-autocomplete-visible-p) (lambda () nil))
              ((symbol-function 'gptel-autocomplete-state) (lambda () 'invalidated))
              ((symbol-function 'gptel-autocomplete-end-reason)
               (lambda () 'ignored-buffer-edit))
              ((symbol-function 'gptel-autocomplete-state-history)
               (lambda () gptel--completion-state-history))
              ((symbol-function 'gptel-autocomplete-current-suggestion)
               (lambda () gptel--current-suggestion))
              ((symbol-function 'gptel-autocomplete-active-request-id) (lambda () 42))
              ((symbol-function 'gptel-autocomplete-last-result)
               (lambda () '(:request-id 42)))
              ((symbol-function 'gptel-autocomplete-last-visible-text)
               (lambda () "ghost"))
              ((symbol-function 'gptel-autocomplete-last-command-kind)
               (lambda () 'delete))
              ((symbol-function 'gptel-autocomplete-lifecycle-history)
               (lambda ()
                 (list '(:event reused :request-id 42 :state reused :source result)
                       '(:event finalized :request-id 42 :state ignored
                         :end-reason ignored-buffer-edit))))
              ((symbol-function 'gptel-autocomplete-cache-size) (lambda () 2))
              ((symbol-function 'gptel-autocomplete-candidate-count) (lambda () 2))
              ((symbol-function 'gptel-autocomplete-candidate-index) (lambda () 1))
              ((symbol-function 'gptel-autocomplete-last-error) (lambda () nil))
              ((symbol-function 'gptel-autocomplete-stats) (lambda () '(:request-count 1)))
              ((symbol-function 'gptel-autocomplete-followup-queue-size) (lambda () 1))
              ((symbol-function 'gptel-autocomplete-next-edit-id)
               (lambda () "next-edit-1"))
              ((symbol-function 'gptel-autocomplete-next-edit-queue-size)
               (lambda () 1))
              ((symbol-function 'gptel-autocomplete-cursor-prediction-target-id)
               (lambda () "cursor-target-1"))
              ((symbol-function 'gptel-autocomplete-cursor-prediction-point)
               (lambda () 17))
              ((symbol-function 'gptel-autocomplete-cursor-prediction-available-p)
               (lambda () t))
              ((symbol-function 'gptel-autocomplete-next-action-kind)
               (lambda () 'next-edit))
              ((symbol-function 'gptel-autocomplete-next-action-count)
               (lambda () 1))
              ((symbol-function 'gptel-autocomplete-restore-available-p)
               (lambda () nil))
              ((symbol-function 'gptel-autocomplete-divergence-distance)
               (lambda () 0))
              ((symbol-function 'gptel-autocomplete-superseded-request-ids)
               (lambda () '(9))))
      (rc/gptel-sync-complete-session-state)
      (let ((state (rc/gptel-complete-session-state)))
        (should (eq (plist-get state :state) 'ignored))
        (should (eq (plist-get state :end-reason) 'ignored-buffer-edit))
        (should (equal (plist-get state :request-id) "complete-42"))
        (should (equal (plist-get (car (plist-get state :lifecycle-history)) :request-id)
                       "complete-42"))
        (should (seq-some (lambda (entry)
                            (eq (plist-get entry :event) 'finalized))
                          (plist-get state :lifecycle-history)))
        (should (eq (plist-get (car (plist-get state :state-history)) :state)
                    'ignored))
        (should (eq (plist-get (car (plist-get state :recent-events)) :event)
                    'finalized))
        (should (equal (plist-get state :followup-queue-size) 1))
        (should (equal (plist-get state :next-edit-id) "next-edit-1"))
        (should (= (plist-get state :next-edit-queue-size) 1))
        (should (equal (plist-get state :cursor-prediction-target-id)
                       "cursor-target-1"))
        (should (= (plist-get state :cursor-prediction-target-point) 17))
        (should (plist-get state :cursor-prediction-target-available))
        (should (eq (plist-get state :cache-source) 'result))
        (should (= (plist-get state :cache-followup-count) 1))
        (should (= (plist-get state :cache-candidate-count) 2))
        (should (eq (plist-get state :next-action-kind) 'next-edit))
        (should (= (plist-get state :next-action-count) 1))
        (should-not (plist-get state :restore-available))
        (should (= (plist-get state :divergence-distance) 0))))))

(ert-deftest rc/gptel-complete-sync-session-state-does-not-leak-trigger-source-into-manual ()
  
  :tags '(domain/complete-state risk/source-consistency prio/3)(with-temp-buffer
    (setq-local gptel-autocomplete-mode t)
    (setq-local gptel--current-suggestion
                '(:id 1
                  :request-id 1
                  :request-source manual
                  :state followup-ready))
    (setq-local rc/gptel-complete-last-auto-trigger-check
                '(:trigger-source cache-refresh))
    (setq-local gptel--autocomplete-runtime-state
                '(:active-request-id 1
                  :last-result (:request-id 1)))
    (cl-letf (((symbol-function 'gptel-autocomplete-visible-p) (lambda () nil))
              ((symbol-function 'gptel-autocomplete-display-phase) (lambda () 'idle))
              ((symbol-function 'gptel-autocomplete-stale-p) (lambda () nil))
              ((symbol-function 'gptel-autocomplete-requesting-indicator-visible-p)
               (lambda () nil))
              ((symbol-function 'gptel-autocomplete-status-indicator) (lambda () nil))
              ((symbol-function 'gptel-autocomplete-state) (lambda () 'followup-ready))
              ((symbol-function 'gptel-autocomplete-end-reason) (lambda () nil))
              ((symbol-function 'gptel-autocomplete-current-suggestion)
               (lambda () gptel--current-suggestion))
              ((symbol-function 'gptel-autocomplete-active-request-id) (lambda () 1))
              ((symbol-function 'gptel-autocomplete-current-request-metadata)
               (lambda () nil))
              ((symbol-function 'gptel-autocomplete-stats) (lambda () nil))
              ((symbol-function 'gptel-autocomplete-lifecycle-history)
               (lambda () '((:event request-started :state requesting :request-id 1))))
              ((symbol-function 'gptel-autocomplete-state-history)
               (lambda () '((:event request-started :state requesting :request-id 1))))
              ((symbol-function 'gptel-autocomplete-last-result)
               (lambda () '(:request-id 1))))
      (rc/gptel-sync-complete-session-state)
      (let ((state (rc/gptel-complete-session-state)))
        (should (equal (plist-get state :request-id) "complete-1"))
        (should (eq (plist-get state :request-source) 'manual))
        (should-not (plist-get state :trigger-source))))))

(ert-deftest rc/gptel-complete-full-accept-finalizes-accepted-full ()
  
  :tags '(domain/complete-state prio/2)(with-temp-buffer
    (rc/test-gptel-visible-completion "hello" 11)
    (let (payload)
      (cl-letf (((symbol-function 'gptel--run-after-accept-hook)
                 (lambda (&rest extra) (setq payload extra))))
        (gptel-accept-completion))
      (should (equal (buffer-string) "hello"))
      (should (eq (gptel-autocomplete-state) 'accepted))
      (should (eq (gptel-autocomplete-end-reason) 'accepted-full))
      (should (equal (plist-get payload :request-id) 11))
      (should (equal (plist-get payload :accepted-text) "hello"))
      (should (string-prefix-p "cursor-target-"
                               (or (gptel-autocomplete-cursor-prediction-target-id)
                                   "")))
      (should (= (gptel-autocomplete-cursor-prediction-point) (point)))
      (should (eq (rc/test-gptel-last-lifecycle-event) 'finalized)))))

(ert-deftest rc/gptel-complete-word-accept-keeps-visible-remainder ()
  
  :tags '(domain/complete-state prio/2)(with-temp-buffer
    (rc/test-gptel-visible-completion "hello world" 12)
    (gptel-accept-word)
    (should (equal (buffer-string) "hello"))
    (should (eq (gptel-autocomplete-state) 'partial-accepted))
    (should (equal (plist-get (gptel-autocomplete-current-suggestion) :current-visible-text)
                   " world"))
    (should (eq (plist-get (car gptel--completion-lifecycle-history) :event)
                'partial-accepted))))

(ert-deftest rc/gptel-complete-line-accept-keeps-visible-remainder ()
  
  :tags '(domain/complete-state prio/2)(with-temp-buffer
    (rc/test-gptel-visible-completion "hello\nworld" 13)
    (gptel-accept-line)
    (should (equal (buffer-string) "hello\n"))
    (should (eq (gptel-autocomplete-state) 'partial-accepted))
    (should (equal (plist-get (gptel-autocomplete-current-suggestion) :current-visible-text)
                   "world"))
    (should (eq (plist-get (car gptel--completion-lifecycle-history) :event)
                'partial-accepted))))

(ert-deftest rc/gptel-complete-clear-user-reject-finalizes-rejected-user ()
  
  :tags '(domain/complete-state prio/2)(with-temp-buffer
    (rc/test-gptel-visible-completion "hello" 14)
    (gptel-clear-completion 'user-reject)
    (should (eq (gptel-autocomplete-end-reason) 'rejected-user))
    (should (eq (gptel-autocomplete-state) 'ignored))
    (should (eq (rc/test-gptel-last-lifecycle-event) 'finalized))
    (should (eq (rc/test-gptel-last-end-reason) 'rejected-user))))

(ert-deftest rc/gptel-complete-post-command-move-finalizes-ignored-point-move ()
  
  :tags '(domain/complete-state prio/2)(with-temp-buffer
    (insert "a")
    (goto-char (point-max))
    (rc/test-gptel-visible-completion "hello" 15)
    (let ((this-command 'left-char))
      (gptel--pre-command)
      (backward-char 1)
      (gptel--post-command-clear))
    (should (eq (gptel-autocomplete-end-reason) 'ignored-point-move))
    (should (eq (gptel-autocomplete-state) 'ignored))
    (should (eq (rc/test-gptel-last-end-reason) 'ignored-point-move))))

(ert-deftest rc/gptel-complete-compatible-typing-keeps-visible ()
  
  :tags '(domain/complete-state prio/2)(with-temp-buffer
    (rc/test-gptel-visible-completion "hello" 16)
    (let ((this-command 'self-insert-command))
      (gptel--pre-command)
      (insert "h")
      (gptel--post-command-clear))
    (should (equal (buffer-string) "h"))
    (should (eq (gptel-autocomplete-state) 'visible))
    (should (equal (plist-get (gptel-autocomplete-current-suggestion) :current-visible-text)
                   "ello"))))

(ert-deftest rc/gptel-complete-delete-restore-returns-visible ()
  
  :tags '(domain/complete-state prio/2)(with-temp-buffer
    (rc/test-gptel-visible-completion "hello" 17)
    (let ((this-command 'self-insert-command))
      (gptel--pre-command)
      (insert "x")
      (gptel--post-command-clear))
    (should (eq (gptel-autocomplete-state) 'temporarily-diverged))
    (let ((this-command 'delete-backward-char))
      (gptel--pre-command)
      (delete-backward-char 1)
      (gptel--post-command-clear))
    (should (equal (buffer-string) ""))
    (should (eq (gptel-autocomplete-state) 'visible))
    (should (eq (gptel-autocomplete-end-reason) 'restored-after-delete))))

(ert-deftest rc/gptel-complete-delete-disagreed-finalizes-ignored-typing-disagreed ()
  
  :tags '(domain/complete-state prio/2)(with-temp-buffer
    (rc/test-gptel-visible-completion "hello" 18)
    (dolist (ch '("x" "y" "z"))
      (let ((this-command 'self-insert-command))
        (gptel--pre-command)
        (insert ch)
        (gptel--post-command-clear)))
    (should (equal (buffer-string) "xyz"))
    (should (eq (gptel-autocomplete-end-reason) 'ignored-typing-disagreed))
    (should (eq (gptel-autocomplete-state) 'ignored))))

(ert-deftest rc/gptel-complete-diverged-ghost-is-hidden-until-restored ()
  
  :tags '(domain/complete-state prio/2)(with-temp-buffer
    (rc/test-gptel-visible-completion "hello" 18)
    (let ((this-command 'self-insert-command))
      (gptel--pre-command)
      (insert "x")
      (gptel--post-command-clear))
    (should (eq (gptel-autocomplete-state) 'temporarily-diverged))
    (should-not (gptel-autocomplete-visible-p))
    (should-not (plist-get (gptel-autocomplete-current-suggestion) :current-visible-text))
    (should (equal (plist-get (gptel-autocomplete-current-suggestion) :seed-text)
                   "hello"))
    (should (overlayp gptel--completion-overlay))
    (should (= (overlay-start gptel--completion-overlay) (point)))
    (let ((this-command 'delete-backward-char))
      (gptel--pre-command)
      (delete-backward-char 1)
      (gptel--post-command-clear))
    (should (eq (gptel-autocomplete-state) 'visible))
    (should (gptel-autocomplete-visible-p))
    (should (equal (plist-get (gptel-autocomplete-current-suggestion) :current-visible-text)
                   "hello"))))

(ert-deftest rc/gptel-complete-diverged-clear-preserves-last-visible-text ()
  
  :tags '(domain/complete-state prio/2)(with-temp-buffer
    (rc/test-gptel-visible-completion "hello" 18)
    (dolist (ch '("x" "y" "z"))
      (let ((this-command 'self-insert-command))
        (gptel--pre-command)
        (insert ch)
        (gptel--post-command-clear)))
    (should (eq (gptel-autocomplete-end-reason) 'ignored-typing-disagreed))
    (should (equal (plist-get (car gptel--completion-lifecycle-history) :text)
                   "hello"))))

(ert-deftest rc/gptel-complete-superseded-response-caches-and-finalizes ()
  
  :tags '(domain/complete-state risk/supersede risk/cache-hit prio/3)(with-temp-buffer
    (rc/test-gptel-visible-completion "old" 19)
    (setq-local gptel--completion-request-id 20)
    (gptel--completion-handle-superseded-response
     19
     "```text\n█START_COMPLETION█\nhello\n█END_COMPLETION█\n```"
     ""
     ""
     (point))
    (should (eq (gptel-autocomplete-end-reason) 'ignored-superseded))
    (should (eq (gptel-autocomplete-state) 'superseded))
    (should (= (gptel-autocomplete-cache-size) 1))
    (should (equal (car (gptel-autocomplete-superseded-request-ids)) 19))))

(ert-deftest rc/gptel-complete-cache-reuse-transitions-to-visible ()
  
  :tags '(domain/complete-state risk/cache-hit prio/2)(with-temp-buffer
    (rc/test-gptel-ensure-autocomplete)
    (rc/test-gptel-reset-runtime)
    (gptel--completion-cache-store 21 (point) "" "cached" "" 'superseded)
    (let ((cached (gptel--completion-cache-pop (point) "" "")))
      (should cached)
      (gptel--completion-show-cache cached))
    (should (eq (gptel-autocomplete-state) 'visible))
    (should (equal (plist-get (gptel-autocomplete-current-suggestion) :request-source)
                   'cache))
    (should (equal (buffer-substring-no-properties (point-min) (point-max)) ""))
    (should (eq (plist-get (cadr gptel--completion-lifecycle-history) :event)
                'reused))
    (should (eq (plist-get (car gptel--completion-lifecycle-history) :event)
                'visible))))

(ert-deftest rc/gptel-complete-cache-reuse-preserves-followups-and-candidates ()
  
  :tags '(domain/complete-state risk/cache-hit prio/2)(with-temp-buffer
    (rc/test-gptel-ensure-autocomplete)
    (rc/test-gptel-reset-runtime)
    (gptel--completion-cache-store
     31
     (point)
     ""
     '(:display "head"
       :full "head\nnext"
       :followups ("next")
       :candidates ((:display "head" :followups ("next") :full "head\nnext")
                    (:display "alt" :followups nil :full "alt")))
     ""
     'result)
    (let ((cached (gptel--completion-cache-pop (point) "" "")))
      (should cached)
      (gptel--completion-show-cache cached))
    (should (eq (gptel-autocomplete-state) 'visible))
    (should (equal (plist-get (gptel-autocomplete-current-suggestion) :request-source)
                   'cache))
    (should (= (gptel-autocomplete-candidate-count) 2))
    (should (= (gptel-autocomplete-followup-queue-size) 1))
    (should (equal (plist-get (gptel-autocomplete-current-suggestion) :current-visible-text)
                   "head"))
    (cl-letf (((symbol-function 'gptel-request)
               (lambda (&rest _args)
                 (ert-fail "cached followup path should not send a network request"))))
      (gptel-complete 'followup))
    (should (eq (gptel-autocomplete-state) 'visible))
    (should (equal (plist-get (gptel-autocomplete-current-suggestion) :request-source)
                   'followup))
    (should (equal (plist-get (gptel-autocomplete-current-suggestion) :current-visible-text)
                   "next"))))

(ert-deftest rc/gptel-complete-extract-parts-drops-leaked-start-marker-tail ()
  
  :tags '(domain/complete-state prio/2)(with-temp-buffer
    (let* ((parts (gptel--extract-completion-parts
                   "// cout << *max_it << \" \" << *min_it << \"\\n\";█START_COMPLETION█"
                   ""
                   ""))
           (display (plist-get parts :display)))
      (should (equal display "// cout << *max_it << \" \" << *min_it << \"\\n\";"))
      (should-not (string-match-p "START_COMPLETION" display)))))

(ert-deftest rc/gptel-complete-extract-parts-drops-stray-end-marker ()
  
  :tags '(domain/complete-state prio/2)(with-temp-buffer
    (let* ((parts (gptel--extract-completion-parts
                   "value();\n█END_COMPLETION█"
                   ""
                   ""))
           (display (plist-get parts :display)))
      (should (equal display "value();"))
      (should-not (string-match-p "END_COMPLETION" display)))))

(ert-deftest rc/gptel-complete-extract-parts-salvages-commentary-preamble ()
  
  :tags '(domain/complete-state prio/2)(with-temp-buffer
    (let* ((parts (gptel--extract-completion-parts
                   "Here is the completion:\nvalue();"
                   ""
                   ""))
           (display (plist-get parts :display)))
      (should (equal display "value();")))))

(ert-deftest rc/gptel-complete-extract-parts-strips-stray-code-fence-lines ()
  
  :tags '(domain/complete-state prio/2)(with-temp-buffer
    (let* ((parts (gptel--extract-completion-parts
                   "```cpp\nvalue();\n```"
                   ""
                   ""))
           (display (plist-get parts :display)))
      (should (equal display "value();")))))

(ert-deftest rc/gptel-complete-superseded-cache-refreshes-visible-path ()
  
  :tags '(domain/complete-state risk/supersede risk/cache-hit prio/2)(with-temp-buffer
    (emacs-lisp-mode)
    (rc/test-gptel-ensure-autocomplete)
    (rc/test-gptel-reset-runtime)
    (let ((rc/gptel-complete-cache-refresh-delay 0)
          events)
      (cl-letf (((symbol-function 'run-with-timer)
                 (lambda (_delay _repeat fn &rest args)
                   (apply fn args)
                   'cache-refresh-timer))
                ((symbol-function 'gptel-request)
                 (lambda (&rest _args)
                   (ert-fail "cache refresh path should not send a network request"))))
        (gptel--completion-cache-store 61 (point) "" "cached" "" 'superseded))
      (setq events (mapcar (lambda (entry) (plist-get entry :event))
                           (seq-take gptel--completion-lifecycle-history 4)))
      (should (equal events '(visible reused cache-refresh-triggered reused)))
      (should (eq (gptel-autocomplete-state) 'visible))
      (should (equal (plist-get (gptel-autocomplete-current-suggestion) :request-source)
                     'cache))
      (should (equal (plist-get (gptel-autocomplete-current-suggestion) :current-visible-text)
                     "cached")))))

(ert-deftest rc/gptel-complete-superseded-cache-refresh-can-show-immediately ()
  
  :tags '(domain/complete-state risk/supersede risk/cache-hit prio/3)(with-temp-buffer
    (emacs-lisp-mode)
    (rc/test-gptel-ensure-autocomplete)
    (rc/test-gptel-reset-runtime)
    (let (timer-called)
      (cl-letf (((symbol-function 'run-with-timer)
                 (lambda (&rest _args)
                   (setq timer-called t)
                   'cache-refresh-timer))
                ((symbol-function 'gptel-request)
                 (lambda (&rest _args)
                   (ert-fail "immediate cache refresh should not send a network request"))))
        (gptel--completion-cache-store 62 (point) "" "cached" "" 'superseded))
      (should-not timer-called)
      (should (eq (gptel-autocomplete-state) 'visible))
      (should (equal (plist-get (gptel-autocomplete-current-suggestion) :request-source)
                     'cache))
      (should (equal (plist-get (gptel-autocomplete-current-suggestion) :current-visible-text)
                     "cached")))))

(ert-deftest rc/gptel-complete-cache-refresh-throttles-repeated-availability ()
  
  :tags '(domain/complete-state risk/cache-hit prio/2)(with-temp-buffer
    (emacs-lisp-mode)
    (rc/test-gptel-ensure-autocomplete)
    (rc/test-gptel-reset-runtime)
    (setq-local rc/gptel-complete-last-cache-refresh-at (float-time))
    (gptel--completion-cache-store 71 (point) "" "cached" "" 'superseded)
    (cl-letf (((symbol-function 'run-with-timer)
               (lambda (&rest _args)
                 (ert-fail "throttled cache refresh should not schedule timer"))))
      (rc/gptel-complete-handle-cache-available
       (list :request-id 71
             :target-point (point)
             :prefix ""
             :after ""
             :source 'superseded
             :cache-size 1)))
    (should-not rc/gptel-complete-cache-refresh-timer)))

(ert-deftest rc/gptel-complete-success-cache-reuse-skips-request ()
  
  :tags '(domain/complete-state risk/cache-hit prio/2)(with-temp-buffer
    (rc/test-gptel-ensure-autocomplete)
    (rc/test-gptel-reset-runtime)
    (setq rc/gptel-action-request-history nil
          rc/gptel-action-active-request nil
          rc/gptel-action-last-request nil
          rc/gptel-action-lifecycle-history nil)
    (clrhash rc/gptel-action-request-counter-table)
    (let (callback request-count)
      (cl-letf (((symbol-function 'gptel-request)
                 (lambda (_prompt &rest plist)
                   (setq request-count (1+ (or request-count 0)))
                   (setq callback (plist-get plist :callback))
                   'fake))
                ((symbol-function 'gptel--request-context)
                 #'rc/test-gptel-stub-request-context)
                ((symbol-function 'gptel--build-system-message)
                 (lambda (&optional _extra) "system")))
        (gptel-complete 'manual)
        (should (= request-count 1))
        (funcall callback
                 "```text\n█START_COMPLETION█\nhello\n█END_COMPLETION█\n```"
                 '(:status "ok"))
        (should (= (gptel-autocomplete-cache-size) 1))
        (gptel-clear-completion 'new-request)
        (setq callback nil)
        (gptel-complete 'manual)
        (should (= request-count 1))
        (should-not callback))
      (should (eq (gptel-autocomplete-state) 'visible))
      (should (equal (plist-get (gptel-autocomplete-current-suggestion) :request-source)
                     'cache))
      (should (equal (plist-get (gptel-autocomplete-current-suggestion) :current-visible-text)
                     "hello"))
      (should (= (gptel-autocomplete-cache-size) 0)))))

(ert-deftest rc/gptel-complete-superseded-ignore-on-arrive-records-source-marker ()
  
  :tags '(domain/complete-state risk/source-consistency risk/supersede prio/2)(with-temp-buffer
    (rc/test-gptel-ensure-autocomplete)
    (rc/test-gptel-reset-runtime)
    (gptel--completion-request-start-shared 7 'manual (point) "")
    (gptel--completion-request-record-merge 7 :supersede-strategy 'ignore-on-arrive)
    (setq-local gptel--completion-request-id 8)
    (setq-local gptel--current-suggestion
                (gptel--make-suggestion :request-id 7 :request-source 'manual))
    (gptel--completion-handle-superseded-response
     7
     "```text\n█START_COMPLETION█\nhello\n█END_COMPLETION█\n```"
     ""
     ""
     (point))
    (should (= (gptel-autocomplete-cache-size) 1))
    (should (eq (plist-get (car (gptel--runtime-get :cache)) :source)
                'superseded-ignore-on-arrive))
    (should (eq (plist-get (plist-get (rc/gptel-action-last-request) :detail)
                           :supersede-strategy)
                'ignore-on-arrive))))

(ert-deftest rc/gptel-complete-superseded-cancel-from-network-does-not-cache-late-result ()
  
  :tags '(domain/complete-state risk/race risk/supersede risk/cache-hit prio/3)(with-temp-buffer
    (rc/test-gptel-ensure-autocomplete)
    (rc/test-gptel-reset-runtime)
    (gptel--completion-request-start-shared 9 'manual (point) "")
    (gptel--completion-request-record-merge 9 :supersede-strategy 'cancel-from-network)
    (setq-local gptel--completion-request-id 10)
    (setq-local gptel--current-suggestion
                (gptel--make-suggestion :request-id 9 :request-source 'manual))
    (gptel--completion-handle-superseded-response
     9
     "```text\n█START_COMPLETION█\nlate\n█END_COMPLETION█\n```"
     ""
     ""
     (point))
    (should (= (gptel-autocomplete-cache-size) 0))
    (should (eq (plist-get (plist-get (rc/gptel-action-last-request) :detail)
                           :supersede-strategy)
                'cancel-from-network))
    (should (eq (plist-get (plist-get (rc/gptel-action-last-request) :detail)
                           :transport-outcome)
                'canceled))))

(ert-deftest rc/gptel-complete-timeout-records-transport-outcome-and-drops-late-response ()
  
  :tags '(domain/complete-state risk/race prio/3)(with-temp-buffer
    (rc/test-gptel-ensure-autocomplete)
    (rc/test-gptel-reset-runtime)
    (setq rc/gptel-action-request-history nil
          rc/gptel-action-active-request nil
          rc/gptel-action-last-request nil
          rc/gptel-action-lifecycle-history nil)
    (clrhash rc/gptel-action-request-counter-table)
    (setq-local gptel--current-suggestion
                (gptel--make-suggestion :request-id 12 :request-source 'manual))
    (gptel--runtime-set :active-request-id 12)
    (gptel--completion-request-start-shared 12 'manual (point) "")
    (gptel--completion-request-record-merge 12 :logical-outcome 'requesting
                                            :transport-outcome 'pending)
    (gptel--completion-request-timeout-fired (current-buffer) 12)
    (should (equal (gptel-autocomplete-last-error) "timeout"))
    (should-not (gptel-autocomplete-active-request-id))
    (should (eq (plist-get (rc/gptel-action-last-request) :state) 'failed))
    (should (eq (plist-get (plist-get (rc/gptel-action-last-request) :detail)
                           :transport-outcome)
                'timeout))
    (let ((callback (gptel--completion-request-callback 12 "" "" (point) nil)))
      (funcall callback "```text\n█START_COMPLETION█\nlate\n█END_COMPLETION█\n```"
               '(:status "ok")))
    (should (= (gptel-autocomplete-cache-size) 0))
    (should (eq (plist-get (gptel-autocomplete-request-metadata 12) :transport-outcome)
                'timeout))))

(ert-deftest rc/gptel-complete-mode-handler-resolves-function-symbol ()
  
  :tags '(domain/complete-state prio/1)(with-temp-buffer
    (emacs-lisp-mode)
    (cl-letf (((symbol-function 'rc/gptel-complete-mode-rule)
               (lambda (&optional _mode)
                 '(:direct-char-predicate ignore))))
      (should (eq (rc/gptel-complete-mode-handler :direct-char-predicate)
                  'ignore)))))

(ert-deftest rc/gptel-complete-lifecycle-hook-tracks-invalidated-counts ()
  
  :tags '(domain/complete-state prio/2)(with-temp-buffer
    (setq-local rc/gptel-complete-session-state
                (list :invalidated-move-count 0
                      :invalidated-edit-count 0
                      :mode-disabled-count 0
                      :ignored-point-move-count 0
                      :ignored-buffer-edit-count 0
                      :ignored-superseded-count 0
                      :ignored-typing-disagreed-count 0
                      :forward-stable-count 0
                      :restored-count 0
                      :temporarily-diverged-count 0
                      :cache-hit-count 0
                      :superseded-count 0
                      :aborted-count 0
                      :rejected-count 0
                      :ignored-count 0
                      :state 'visible))
    (cl-letf (((symbol-function 'rc/gptel-sync-complete-session-state)
               (lambda () rc/gptel-complete-session-state)))
      (rc/gptel-complete-lifecycle-hook
       '(:event invalidated-move
         :state invalidated
         :previous-state visible
         :end-reason ignored-point-move))
      (let ((state (rc/gptel-complete-session-state)))
        (should (= (plist-get state :invalidated-move-count) 1))
        (should (= (plist-get state :ignored-point-move-count) 1))
        (should (= (plist-get state :ignored-count) 1))))))

(ert-deftest rc/gptel-complete-state-summary-includes-auto-trigger-diagnostics ()
  
  :tags '(domain/complete-state risk/observability prio/2)(with-temp-buffer
    (setq-local rc/gptel-complete-session-state
                (list :state 'idle
                      :stats nil
                      :trigger-source 'signature-help
                      :cache-source 'result
                      :next-edit-id "next-edit-1"
                      :next-edit-queue-size 1
                      :next-action-kind 'next-edit
                      :next-action-count 1
                      :restore-available nil
                      :divergence-distance 0
                      :cache-followup-count 1
                      :cache-candidate-count 2))
    (setq-local rc/gptel-complete-auto-trigger-mode 'diagnose)
    (setq-local rc/gptel-complete-last-auto-trigger-check
                '(:trigger-source signature-help
                  :source-rule (:enabled t :delay 0.04)
                  :trigger-match-kind line-end
                  :blocked-reason no-trigger-match
                  :line-end-match nil
                  :event-char "="
                  :trigger-chars (61 40)))
    (setq-local rc/gptel-complete-auto-trigger-history
                '((:trigger-match-kind line-end
                   :blocked-reason no-trigger-match
                   :line-end-match nil
                   :event-char "="
                   :eligible nil)
                  (:trigger-match-kind direct-char
                   :blocked-reason nil
                   :line-end-match nil
                   :event-char "("
                   :eligible t)))
    (let ((summary (rc/gptel-complete-state-summary)))
      (should (string-match-p "major-mode:" summary))
      (should (string-match-p "auto-trigger-mode: diagnose" summary))
      (should (string-match-p "trigger-source: signature-help" summary))
      (should (string-match-p "source-rule-enabled: yes" summary))
      (should (string-match-p "cache-source: result" summary))
      (should (string-match-p "next-action: next-edit" summary))
      (should (string-match-p "next-action-count: 1" summary))
      (should (string-match-p "next-edit-id: next-edit-1" summary))
      (should (string-match-p "next-edit-queue: 1" summary))
      (should (string-match-p "restore-available: no" summary))
      (should (string-match-p "blocked-reason-counts: no-trigger-match=1" summary))
      (should (string-match-p "last-success-source: direct-char" summary))
      (should (string-match-p "cache-next-edit-count: 1" summary))
      (should (string-match-p "cache-candidate-count: 2" summary))
      (should (string-match-p "blocked-reason: no-trigger-match" summary))
      (should (string-match-p "event: =" summary)))))

(ert-deftest rc/gptel-complete-cache-match-supports-exact-and-prefix-hit ()
  
  :tags '(domain/complete-state risk/cache-hit prio/2)(with-temp-buffer
    (rc/test-gptel-ensure-autocomplete)
    (rc/test-gptel-reset-runtime)
    (gptel--completion-cache-store 11 (point) "" "hello" "" 'result)
    (let ((exact (gptel-autocomplete-cache-match (point) "" "")))
      (should (eq (plist-get exact :cache-hit-kind) 'exact))
      (should (equal (plist-get exact :display) "hello")))
    (let ((prefix (gptel-autocomplete-cache-match (point) "he" "")))
      (should (eq (plist-get prefix :cache-hit-kind) 'prefix))
      (should (equal (plist-get prefix :display) "llo"))
      (should (equal (plist-get prefix :typed-prefix) "he")))
    (should-not (gptel-autocomplete-cache-match (point) "zz" ""))))

(ert-deftest rc/gptel-complete-requesting-indicator-updates-lighter-and-clears ()
  
  :tags '(domain/complete-state risk/observability prio/2)(with-temp-buffer
    (rc/test-gptel-ensure-autocomplete)
    (rc/test-gptel-reset-runtime)
    (setq-local gptel--current-suggestion
                (gptel--make-suggestion :request-id 7 :request-source 'manual))
    (setq-local gptel--autocomplete-runtime-state
                (plist-put gptel--autocomplete-runtime-state
                           :active-request-id 7))
    (gptel--completion-show-requesting-indicator (current-buffer) 7 'manual)
    (should (gptel-autocomplete-requesting-indicator-visible-p))
    (should (string-match-p "•" (gptel--completion-mode-lighter)))
    (gptel--completion-clear-requesting-indicator)
    (should-not (gptel-autocomplete-requesting-indicator-visible-p))
    (should (equal (gptel--completion-mode-lighter) " GPTel-A"))))

;; Calibration case: 2026-05-19 / complete-clear-indicator-001
(ert-deftest rc/gptel-complete-clear-completion-tolerates-unbound-requesting-indicator-timer ()
  
  :tags '(domain/complete-state risk/observability risk/race prio/3)(with-temp-buffer
    (rc/test-gptel-ensure-autocomplete)
    (rc/test-gptel-reset-runtime)
    (rc/test-gptel-visible-completion "hello" 11)
    (gptel--runtime-set :requesting-indicator-visible t)
    (gptel--runtime-set :requesting-indicator-reason 'manual)
    (makunbound 'gptel--completion-requesting-indicator-timer)
    (should
     (eq (condition-case err
             (progn
               (gptel-clear-completion 'user-reject)
               'ok)
           (error (car err)))
         'ok))
    (should-not (gptel-autocomplete-requesting-indicator-visible-p))
    (should-not (gptel-autocomplete-active-request-id))
    (should (eq (gptel-autocomplete-end-reason) 'rejected-user))))

(ert-deftest rc/gptel-complete-stale-cache-show-marks-stale-visible ()
  
  :tags '(domain/complete-state risk/cache-hit risk/stale-cache prio/3)(with-temp-buffer
    (rc/test-gptel-ensure-autocomplete)
    (rc/test-gptel-reset-runtime)
    (gptel--completion-cache-store 21 (point) "" "hello" "" 'result)
    (let ((cached (gptel-autocomplete-cache-match (point) "he" "")))
      (should (eq (plist-get cached :cache-hit-kind) 'prefix))
      (gptel--completion-show-cache cached))
    (should (gptel-autocomplete-visible-p))
    (should (gptel-autocomplete-stale-p))
    (should (eq (gptel-autocomplete-display-phase) 'stale-visible))
    (should (string-match-p "stale" (gptel--completion-hint-label)))))

(ert-deftest rc/gptel-complete-stale-refresh-helper-covers-append-keep-replace ()
  
  :tags '(domain/complete-state risk/stale-cache prio/2)(with-temp-buffer
    (rc/test-gptel-ensure-autocomplete)
    (rc/test-gptel-reset-runtime)
    (setq-local gptel--current-suggestion
                (gptel--make-suggestion :request-id 31 :request-source 'cache
                                        :current-visible-text "hel" :stale t))
    (setq-local gptel--autocomplete-runtime-state
                (plist-put gptel--autocomplete-runtime-state :display-stale t))
    (should (eq (gptel--completion-refresh-stale-visible "hello" (point)) 'append))
    (should-not (gptel-autocomplete-stale-p))
    (setq-local gptel--current-suggestion
                (gptel--make-suggestion :request-id 32 :request-source 'cache
                                        :current-visible-text "hello" :stale t))
    (setq-local gptel--autocomplete-runtime-state
                (plist-put gptel--autocomplete-runtime-state :display-stale t))
    (should (eq (gptel--completion-refresh-stale-visible "hel" (point)) 'keep))
    (should (gptel-autocomplete-stale-p))
    (should (eq (gptel-autocomplete-display-phase) 'stale-visible))
    (setq-local gptel--current-suggestion
                (gptel--make-suggestion :request-id 33 :request-source 'cache
                                        :current-visible-text "world" :stale t))
    (setq-local gptel--autocomplete-runtime-state
                (plist-put gptel--autocomplete-runtime-state :display-stale t))
    (should (eq (gptel--completion-refresh-stale-visible "hello" (point)) 'replace))
    (should-not (gptel-autocomplete-stale-p))
    (should (eq (plist-get (car gptel--completion-lifecycle-history) :event)
                'stale-refresh-replace))))
(provide 'ai-complete-state-test)
;;; ai-complete-state-test.el ends here
