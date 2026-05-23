;;; ai-complete-followup-test.el --- AI runtime tests, split by domain -*- lexical-binding: t; -*-

;; Auto-extracted from ai-action-runtime-test.el by tests/tools/split-by-domain.el.
;; Do not append new tests here by hand without first updating the splitter.

;;; Code:

(require 'ert)
(require 'cl-lib)

(load "/home/seeback/.emacs.rc/ai-rc.el" nil t)
(load "/home/seeback/.emacs.rc/ai/tests/helpers/ai-test-helpers.el" nil t)

(ert-deftest rc/gptel-complete-candidate-cycle-syncs-next-edit-runtime ()
  
  :tags '(domain/complete-followup prio/2)(with-temp-buffer
    (rc/test-gptel-ensure-autocomplete)
    (rc/test-gptel-reset-runtime)
    (setq-local gptel--autocomplete-runtime-state
                (plist-put gptel--autocomplete-runtime-state
                           :candidates
                           (list
                            '(:display "head" :followups ("\nnext one"))
                            '(:display "alt" :followups nil))))
    (setq-local gptel--current-suggestion
                (gptel--make-suggestion :request-id 81 :request-source 'manual
                                        :candidate-index 0 :candidate-count 2))
    (gptel--candidate-apply-current (point))
    (should (= (gptel-autocomplete-next-edit-queue-size) 1))
    (should (string-prefix-p "next-edit-" (or (gptel-autocomplete-next-edit-id) "")))
    (gptel-autocomplete-next-candidate)
    (should (equal (plist-get (gptel-autocomplete-current-suggestion) :current-visible-text)
                   "alt"))
    (should (= (gptel-autocomplete-next-edit-queue-size) 0))
    (should-not (gptel-autocomplete-next-edit-id))
    (should-not (plist-get (gptel-autocomplete-current-suggestion) :followup-queue))))

(ert-deftest rc/gptel-complete-next-edit-queue-and-apply ()
  
  :tags '(domain/complete-followup prio/2)(with-temp-buffer
    (rc/test-gptel-ensure-autocomplete)
    (rc/test-gptel-reset-runtime)
    (setq-local gptel--current-suggestion
                (gptel--make-suggestion :request-id 41 :request-source 'manual))
    (gptel--completion-followup-push '("next chunk"))
    (should (= (gptel-autocomplete-next-edit-queue-size) 1))
    (should (string-prefix-p "next-edit-" (gptel-autocomplete-next-edit-id)))
    (gptel-apply-next-edit)
    (should (eq (gptel-autocomplete-state) 'visible))
    (should (equal (plist-get (gptel-autocomplete-current-suggestion) :request-source)
                   'followup))
    (should (equal (plist-get (gptel-autocomplete-current-suggestion) :current-visible-text)
                   "next chunk"))
    (should (string-prefix-p "next-edit-"
                             (or (plist-get (gptel-autocomplete-current-suggestion) :next-edit-id)
                                 "")))
    (should (= (gptel-autocomplete-next-edit-queue-size) 0))
    (should-not (plist-get (gptel-autocomplete-current-suggestion) :followup-queue))))

(ert-deftest rc/gptel-complete-next-edit-apply-preserves-leading-newline ()
  
  :tags '(domain/complete-followup prio/2)(with-temp-buffer
    (c++-mode)
    (rc/test-gptel-ensure-autocomplete)
    (rc/test-gptel-reset-runtime)
    (setq-local gptel--current-suggestion
                (gptel--make-suggestion :request-id 42 :request-source 'manual))
    (gptel--completion-followup-push '("\nreturn value;\n}"))
    (gptel-apply-next-edit)
    (should (equal (plist-get (gptel-autocomplete-current-suggestion) :current-visible-text)
                   "\nreturn value;\n}"))))

(ert-deftest rc/gptel-complete-split-followup-preserves-newline-boundary ()
  
  :tags '(domain/complete-followup prio/2)(with-temp-buffer
    (c++-mode)
    (let* ((parts (gptel--split-followup-chunks "if (ready) {\n  work();\n\nreturn other;"))
           (display (car parts))
           (followups (cadr parts)))
      (should (equal display "if (ready) {\n  work();\n"))
      (should (equal followups '("\nreturn other;"))))))

(ert-deftest rc/gptel-complete-indent-followup-preserves-newline-boundary ()
  
  :tags '(domain/complete-followup risk/style prio/2)(with-temp-buffer
    (python-mode)
    (let* ((parts (rc/gptel-complete-split-followup "if ok:\n    return value"))
           (display (car parts))
           (followups (cadr parts)))
      (should (equal display "if ok:"))
      (should (equal followups '("\n    return value"))))))

(ert-deftest rc/gptel-complete-go-to-next-location-retriggers ()
  
  :tags '(domain/complete-followup prio/2)(with-temp-buffer
    (rc/test-gptel-visible-completion "hello" 51)
    (let (request-source)
      (cl-letf (((symbol-function 'rc/gptel-complete-notify-source-event)
                 (lambda (source &optional _payload)
                   (setq request-source source)
                   t)))
        (gptel-accept-completion)
        (insert " later")
        (goto-char (point-min))
        (should (< (point) (gptel-autocomplete-cursor-prediction-point)))
        (gptel-go-to-next-location t)
        (should (= (point) (gptel-autocomplete-cursor-prediction-point)))
        (should (eq request-source 'post-jump-retrigger))))))

(ert-deftest rc/gptel-complete-after-accept-jump-can-auto-continue ()
  
  :tags '(domain/complete-followup risk/accept-intent prio/2)(with-temp-buffer
    (rc/test-gptel-visible-completion "hello" 52)
    (let ((rc/gptel-complete-auto-jump-to-next-location t)
          jumped)
      (cl-letf (((symbol-function 'run-with-timer)
                 (lambda (_delay _repeat fn &rest args)
                   (apply fn args)
                   'jump-timer))
                ((symbol-function 'rc/gptel-go-to-next-location)
                 (lambda (&optional retrigger)
                   (setq jumped retrigger)
                   t)))
        (gptel-accept-completion)
        (rc/gptel-complete-after-accept-trigger '(:request-id 52 :accepted-text "hello"))
        (should jumped)))))

(ert-deftest rc/gptel-complete-after-accept-jump-respects-next-edit-priority ()
  
  :tags '(domain/complete-followup risk/accept-intent prio/2)(with-temp-buffer
    (rc/test-gptel-visible-completion "hello" 53)
    (let ((rc/gptel-complete-auto-jump-to-next-location t)
          jumped)
      (gptel--completion-followup-push '("next chunk"))
      (cl-letf (((symbol-function 'rc/gptel-go-to-next-location)
                 (lambda (&optional _retrigger)
                   (setq jumped t)
                   t)))
        (gptel-accept-completion)
        (should-not jumped)))))

(ert-deftest rc/gptel-complete-after-accept-next-step-prefers-jump-over-followup ()
  
  :tags '(domain/complete-followup risk/accept-intent prio/2)(with-temp-buffer
    (rc/test-gptel-ensure-autocomplete)
    (setq-local gptel-autocomplete-mode t)
    (cl-letf (((symbol-function 'gptel-autocomplete-next-edit-queue-size) (lambda () 0))
              ((symbol-function 'gptel-autocomplete-cursor-prediction-available-p) (lambda () t))
              ((symbol-function 'rc/gptel-complete-followup-eligible-p) (lambda (_payload) t)))
      (let ((rc/gptel-complete-auto-jump-to-next-location t))
        (should (eq (rc/gptel-complete-after-accept-next-step
                     '(:accepted-text "hello"))
                    'jump))))))

(ert-deftest rc/gptel-complete-after-accept-trigger-skips-when-jump-wins ()
  
  :tags '(domain/complete-followup risk/accept-intent prio/2)(with-temp-buffer
    (rc/test-gptel-ensure-autocomplete)
    (setq-local gptel-autocomplete-mode t)
    (let (timer-called)
      (cl-letf (((symbol-function 'gptel-autocomplete-next-edit-queue-size) (lambda () 0))
                ((symbol-function 'gptel-autocomplete-cursor-prediction-available-p) (lambda () t))
                ((symbol-function 'rc/gptel-complete-followup-eligible-p) (lambda (_payload) t))
                ((symbol-function 'run-with-timer)
                 (lambda (&rest _args)
                   (setq timer-called t)
                   'continuation-timer)))
        (let ((rc/gptel-complete-auto-jump-to-next-location t))
          (rc/gptel-complete-after-accept-trigger '(:accepted-text "hello"))))
      (should timer-called)
      (should-not rc/gptel-complete-followup-timer))))

(ert-deftest rc/gptel-complete-force-stop-does-not-fall-through-to-jump ()
  
  :tags '(domain/complete-followup risk/accept-intent prio/3)(with-temp-buffer
    (rc/test-gptel-visible-completion "hello" 54)
    (let ((rc/gptel-complete-auto-jump-to-next-location t)
          jumped)
      (cl-letf (((symbol-function 'rc/gptel-go-to-next-location)
                 (lambda (&optional _retrigger)
                   (setq jumped t)
                   t)))
        (rc/gptel-complete-with-accept-intent
         'force-stop
         (lambda ()
           (gptel-accept-completion)
           (rc/gptel-complete-after-accept-trigger '(:request-id 54 :accepted-text "hello"))
           (rc/gptel-complete-after-accept-jump '(:request-id 54 :accepted-text "hello"))))
        (should-not jumped)))))

(ert-deftest rc/gptel-complete-followup-ready-and-followup-visible ()
  
  :tags '(domain/complete-followup prio/2)(with-temp-buffer
    (rc/test-gptel-ensure-autocomplete)
    (rc/test-gptel-reset-runtime)
    (setq-local gptel--current-suggestion
                (gptel--make-suggestion :request-id 22 :request-source 'manual))
    (gptel--completion-followup-push '("next chunk"))
    (should (eq (gptel-autocomplete-state) 'followup-ready))
    (cl-letf (((symbol-function 'gptel-request)
               (lambda (&rest _args)
                 (ert-fail "followup path should not send a network request"))))
      (gptel-complete 'followup))
    (should (eq (gptel-autocomplete-state) 'visible))
    (should (equal (plist-get (gptel-autocomplete-current-suggestion) :request-source)
                   'followup))
    (should (equal (plist-get (gptel-autocomplete-current-suggestion) :current-visible-text)
                   "next chunk"))))

(ert-deftest rc/gptel-complete-followup-does-not-trigger-in-comment-context ()
  
  :tags '(domain/complete-followup prio/2)(with-temp-buffer
    (c++-mode)
    (gptel-autocomplete-mode 1)
    (insert "// comment")
    (should-not (rc/gptel-complete-followup-eligible-p '(:accepted-text "more")))
    (setq rc/gptel-complete-followup-timer 'dummy)
    (cl-letf (((symbol-function 'gptel-complete)
               (lambda (&rest _args)
                 (ert-fail "followup timer should not request inside comment context"))))
      (rc/gptel-run-complete-followup (current-buffer))
      (should-not rc/gptel-complete-followup-timer))))

(ert-deftest rc/gptel-complete-followup-does-not-trigger-in-preprocessor-context ()
  
  :tags '(domain/complete-followup prio/2)(with-temp-buffer
    (c++-mode)
    (gptel-autocomplete-mode 1)
    (insert "#define VALUE")
    (should-not (rc/gptel-complete-followup-eligible-p '(:accepted-text "more")))
    (setq rc/gptel-complete-followup-timer 'dummy)
    (cl-letf (((symbol-function 'gptel-complete)
               (lambda (&rest _args)
                 (ert-fail "followup timer should not request inside preprocessor context"))))
      (rc/gptel-run-complete-followup (current-buffer))
      (should-not rc/gptel-complete-followup-timer))))

(ert-deftest rc/gptel-complete-tab-install-binds-next-edit-command ()
  
  :tags '(domain/complete-followup prio/1)(with-temp-buffer
    (cl-letf (((symbol-function 'rc/gptel-ensure-autocomplete) (lambda () t)))
      (setq-local gptel-autocomplete-mode-map (make-sparse-keymap))
      (setq-local gptel-autocomplete-completion-map (make-sparse-keymap))
      (rc/gptel-install-complete-hooks)
      (should (equal (lookup-key gptel-autocomplete-mode-map (kbd "M-RET"))
                     #'rc/gptel-inline-apply-next-edit))
      (should (equal (lookup-key gptel-autocomplete-mode-map (kbd "M-j"))
                     #'rc/gptel-inline-go-to-next-location))
      (should (equal (lookup-key gptel-autocomplete-completion-map (kbd "M-RET"))
                     #'rc/gptel-inline-apply-next-edit))
      (should (equal (lookup-key gptel-autocomplete-completion-map (kbd "M-j"))
                     #'rc/gptel-inline-go-to-next-location)))))

(ert-deftest rc/gptel-complete-after-accept-trigger-uses-continuation-delay-for-followup ()
  
  :tags '(domain/complete-followup risk/accept-intent prio/2)(with-temp-buffer
    (rc/gptel-complete-session-reset)
    (setq rc/gptel-complete-auto-continuation-chain-length 0
          rc/gptel-complete-continuation-timer nil)
    (let (captured-delays)
      (cl-letf (((symbol-function 'gptel-autocomplete-next-edit-queue-size)
                 (lambda () 0))
                ((symbol-function 'gptel-autocomplete-cursor-prediction-available-p)
                 (lambda () nil))
                ((symbol-function 'rc/gptel-complete-followup-eligible-p)
                 (lambda (_payload) t))
                ((symbol-function 'rc/gptel-complete-set-policy-explain)
                 (lambda (_policy) nil))
                ((symbol-function 'run-with-timer)
                 (lambda (delay &rest _args)
                   (push delay captured-delays)
                   'fake-timer)))
        (rc/gptel-complete-after-accept-trigger
         (list :partial nil :accepted-text "foo"))
        (should (member rc/gptel-complete-continuation-delay captured-delays))
        (should (= rc/gptel-complete-auto-continuation-chain-length 0))))))
(provide 'ai-complete-followup-test)
;;; ai-complete-followup-test.el ends here
