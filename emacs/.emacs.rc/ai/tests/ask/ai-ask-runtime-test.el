;;; ai-ask-runtime-test.el --- AI runtime tests, split by domain -*- lexical-binding: t; -*-

;; Auto-extracted from ai-action-runtime-test.el by tests/tools/split-by-domain.el.
;; Do not append new tests here by hand without first updating the splitter.

;;; Code:

(require 'ert)
(require 'cl-lib)

(load "/home/seeback/.emacs.rc/ai-rc.el" nil t)
(load "/home/seeback/.emacs.rc/ai/tests/helpers/ai-test-helpers.el" nil t)

(ert-deftest rc/gptel-ask-rollback-records-lifecycle-event ()
  
  :tags '(domain/ask prio/2)(with-temp-buffer
    (setq-local rc/gptel-ask-session-id 1
                rc/gptel-ask-session-root default-directory
                rc/gptel-ask-session-file "demo.el"
                rc/gptel-ask-session-source (list :text "hi")
                rc/gptel-ask-session-turns
                (list (list :question "q1" :answer "a1" :source (list :text "hi"))
                      (list :question "q2" :answer "a2" :source (list :text "hi")))
                rc/gptel-ask-session-history nil
                rc/gptel-ask-session-question-count 2
                rc/gptel-ask-session-source-count 1
                rc/gptel-ask-session-save-file nil
                rc/gptel-ask-session-state 'ready
                rc/gptel-action-lifecycle-history nil)
    (cl-letf (((symbol-function 'rc/gptel-render-ask-session-buffer) (lambda (&rest _args) nil))
              ((symbol-function 'rc/gptel-save-ask-session) (lambda (&rest _args) nil))
              ((symbol-function 'rc/gptel-refresh-open-session-panels) (lambda (&rest _args) nil)))
      (rc/gptel-ask-truncate-session (current-buffer) 1))
    (should (= (length rc/gptel-ask-session-turns) 1))
    (should (eq (plist-get (car rc/gptel-action-lifecycle-history) :event) 'rollback))
    (should (= (plist-get (car rc/gptel-action-lifecycle-history) :keep-count) 1))))

(ert-deftest rc/gptel-ask-history-entry-uses-generic-context-label ()
  
  :tags '(domain/ask prio/2)(let ((entry (rc/gptel-ask-history-entry
                '(:label "demo-context"
                  :text "int x = 1;")
                "这是什么？")))
    (should (string-match-p "Context from `demo-context`" entry))
    (should (string-match-p "Question:" entry))))

(ert-deftest rc/gptel-ask-fallback-source-prefers-current-buffer ()
  
  :tags '(domain/ask prio/2)(with-temp-buffer
    (insert "(defun demo ())")
    (setq-local buffer-file-name "/tmp/demo.el")
    (let ((source (rc/gptel-ask-fallback-source (current-buffer))))
      (should (eq (plist-get source :kind) 'buffer))
      (should (equal (plist-get source :file) "/tmp/demo.el"))
      (should (string-match-p "defun demo" (plist-get source :text))))))

(ert-deftest rc/gptel-ask-source-summary-describes-buffer-and-directory ()
  
  :tags '(domain/ask risk/observability prio/2)(let ((buffer-source '(:kind buffer :label "/tmp/demo.el"))
        (directory-source '(:kind directory :root "/tmp/project/demo")))
    (should (equal (rc/gptel-ask-source-summary buffer-source)
                   "buffer:/tmp/demo.el"))
    (should (equal (rc/gptel-ask-source-summary directory-source)
                   "directory:demo"))))

(ert-deftest rc/gptel-ask-source-candidates-include-buffer-and-directory ()
  
  :tags '(domain/ask prio/2)(let ((root (make-temp-file "ask-source-" t)))
    (unwind-protect
        (with-temp-buffer
          (setq default-directory root)
          (setq-local buffer-file-name (expand-file-name "demo.py" root))
          (insert "print('hi')\n")
          (let ((candidates (rc/gptel-ask-source-candidates (current-buffer))))
            (should (eq (caar candidates) 'buffer))
            (should (eq (caadr candidates) 'directory))
            (should (string-match-p "print" (plist-get (cdar candidates) :text)))))
      (delete-directory root t))))

(ert-deftest rc/gptel-ask-question-without-region-uses-fallback-source ()
  
  :tags '(domain/ask prio/2)(with-temp-buffer
    (insert "(message \"hi\")")
    (setq-local buffer-file-name "/tmp/demo.el")
    (let (captured-source sent-question)
      (cl-letf (((symbol-function 'rc/gptel-ask-buffer-live-p) (lambda () nil))
                ((symbol-function 'rc/gptel-ensure-ask-session)
                 (lambda (source &optional _force-new)
                   (setq captured-source source)
                   (current-buffer)))
                ((symbol-function 'rc/gptel-read-ask-question)
                 (lambda (_source-available-p _current-source-fn
                          _on-replace _on-new
                          _on-use-buffer _on-use-directory)
                   '(:action ask :question "解释一下")))
                ((symbol-function 'rc/gptel-send-ask-question)
                 (lambda (_buffer question)
                   (setq sent-question question))))
        (rc/gptel-ask-question))
      (should (eq (plist-get captured-source :kind) 'buffer))
      (should (equal sent-question "解释一下")))))

(ert-deftest rc/gptel-ask-question-can-switch-to-directory-source ()
  
  :tags '(domain/ask prio/2)(let ((root (make-temp-file "ask-switch-" t)))
    (unwind-protect
        (with-temp-buffer
          (setq default-directory root)
          (setq-local buffer-file-name (expand-file-name "demo.py" root))
          (insert "print('hi')\n")
          (let (initial-source final-source sent-question)
            (cl-letf (((symbol-function 'rc/gptel-ask-buffer-live-p) (lambda () nil))
                      ((symbol-function 'rc/gptel-ensure-ask-session)
                       (lambda (source &optional _force-new)
                         (setq initial-source source)
                         (setq-local rc/gptel-ask-session-source source)
                         (current-buffer)))
                      ((symbol-function 'rc/gptel-replace-ask-session-source)
                       (lambda (buffer source)
                         (with-current-buffer buffer
                           (setq-local rc/gptel-ask-session-source source))))
                      ((symbol-function 'rc/gptel-read-ask-question)
                       (lambda (_source-available-p _current-source-fn
                                _on-replace _on-new
                                _on-use-buffer on-use-directory)
                         (funcall on-use-directory)
                         '(:action ask :question "看看这个目录要做什么")))
                      ((symbol-function 'rc/gptel-send-ask-question)
                       (lambda (buffer question)
                         (setq sent-question question
                               final-source
                               (buffer-local-value 'rc/gptel-ask-session-source buffer)))))
              (rc/gptel-ask-question))
            (should (eq (plist-get initial-source :kind) 'buffer))
            (should (eq (plist-get final-source :kind) 'directory))
            (should (equal sent-question "看看这个目录要做什么"))))
      (delete-directory root t))))

(ert-deftest rc/gptel-ask-snapshot-exposes-next-action-detail ()
  
  :tags '(domain/ask prio/2)(with-temp-buffer
    (setq-local rc/gptel-ask-session-id 3
                rc/gptel-ask-session-title "demo"
                rc/gptel-ask-session-state 'ready
                rc/gptel-ask-session-source '(:kind buffer :text "x")
                rc/gptel-ask-session-question-count 1
                rc/gptel-ask-session-source-count 1)
    (cl-letf (((symbol-function 'rc/gptel-ask-session-valid-p) (lambda (&optional _b) t)))
      (let ((snapshot (rc/gptel-ask-action-snapshot (current-buffer))))
        (should (eq (plist-get (plist-get snapshot :detail) :request-source) 'buffer))
        (should (eq (plist-get (plist-get snapshot :detail) :next-action-kind)
                    'ask-next))))))

(ert-deftest rc/gptel-ask-directory-source-includes-current-snippet ()
  
  :tags '(domain/ask prio/2)(let ((root (make-temp-file "ask-dir-" t)))
    (unwind-protect
        (with-temp-buffer
          (setq default-directory root)
          (setq-local buffer-file-name (expand-file-name "demo.cpp" root))
          (insert "int answer = 42;\nstd::string name = \"demo\";\n")
          (write-region (point-min) (point-max) buffer-file-name nil 'silent)
          (write-region "" nil (expand-file-name "CMakeLists.txt" root) nil 'silent)
          (let ((source (rc/gptel-ask-source-from-directory (current-buffer))))
            (should (eq (plist-get source :kind) 'directory))
            (should (string-match-p "Current file: .*demo.cpp" (plist-get source :text)))
            (should (string-match-p "Current file snippet:" (plist-get source :text)))
            (should (string-match-p "int answer = 42;" (plist-get source :text)))))
      (delete-directory root t))))

(ert-deftest rc/gptel-ask-streaming-preserves-user-point-while-appending ()
  
  :tags '(domain/ask risk/race prio/2)
  (with-temp-buffer
    (setq-local rc/gptel-ask-session-id 9
                rc/gptel-ask-session-root default-directory
                rc/gptel-ask-session-file "demo.el"
                rc/gptel-ask-session-source (list :text "(message \"hi\")"
                                                  :file "demo.el"
                                                  :root default-directory)
                rc/gptel-ask-session-turns nil
                rc/gptel-ask-session-history nil
                rc/gptel-ask-session-question-count 0
                rc/gptel-ask-session-source-count 1
                rc/gptel-ask-session-save-file nil
                rc/gptel-ask-session-state 'ready
                rc/gptel-ask-session-last-error nil)
    (cl-letf (((symbol-function 'rc/gptel-ask-session-valid-p)
               (lambda (&optional _b) t))
              ((symbol-function 'rc/gptel-setup-action-locals)
               (lambda (&rest _args) nil))
              ((symbol-function 'rc/gptel-show-answer-buffer)
               (lambda (&rest _args) nil))
              ((symbol-function 'rc/gptel-question-system-message)
               (lambda () nil))
              ((symbol-function 'rc/gptel-answer-windows-at-bottom-p)
               (lambda (_buffer) nil))
              ((symbol-function 'rc/gptel-answer-refresh-windows)
               (lambda (&rest _args) nil))
              ((symbol-function 'rc/gptel-action-record-event)
               (lambda (&rest _args) nil))
              ((symbol-function 'rc/gptel-action-send)
               (lambda (&rest args)
                 (let ((buffer (plist-get args :buffer))
                       (on-stream (plist-get args :on-stream)))
                   (with-current-buffer buffer
                     (goto-char (point-min)))
                   (funcall on-stream "stream-body" nil '(:request-id "ask-1"))
                   '(:request-id "ask-1")))))
      (rc/gptel-send-ask-question (current-buffer) "解释一下"))
    (should (= (point) (point-min)))
    (should (string-match-p "stream-body"
                            (buffer-substring-no-properties
                             (point-min)
                             (point-max))))))
(provide 'ai-ask-runtime-test)
;;; ai-ask-runtime-test.el ends here
