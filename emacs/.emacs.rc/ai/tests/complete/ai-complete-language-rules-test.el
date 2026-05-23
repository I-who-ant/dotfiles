;;; ai-complete-language-rules-test.el --- AI runtime tests, split by domain -*- lexical-binding: t; -*-

;; Auto-extracted from ai-action-runtime-test.el by tests/tools/split-by-domain.el.
;; Do not append new tests here by hand without first updating the splitter.

;;; Code:

(require 'ert)
(require 'cl-lib)

(load "/home/seeback/.emacs.rc/ai-rc.el" nil t)
(load "/home/seeback/.emacs.rc/ai/tests/helpers/ai-test-helpers.el" nil t)

(ert-deftest rc/gptel-complete-python-indent-followup-splits-sibling-clauses ()
  
  :tags '(domain/complete-language-rules risk/style prio/2)(with-temp-buffer
    (python-mode)
    (let* ((parts (rc/gptel-complete-split-followup
                   "if ok:\n    work()\nelse:\n    recover()"))
           (display (car parts))
           (followups (cadr parts)))
      (should (equal display "if ok:"))
      (should (equal followups '("\n    work()"
                                 "\nelse:\n    recover()"))))))

(ert-deftest rc/gptel-complete-python-indent-followup-splits-except-finally-chain ()
  
  :tags '(domain/complete-language-rules risk/style prio/2)(with-temp-buffer
    (python-mode)
    (let* ((parts (rc/gptel-complete-split-followup
                   "try:\n    work()\nexcept ValueError:\n    recover()\nfinally:\n    cleanup()"))
           (display (car parts))
           (followups (cadr parts)))
      (should (equal display "try:"))
      (should (equal followups '("\n    work()"
                                 "\nexcept ValueError:\n    recover()"
                                 "\nfinally:\n    cleanup()"))))))

(ert-deftest rc/gptel-complete-emacs-lisp-equals-is-trigger-char ()
  
  :tags '(domain/complete-language-rules prio/2)(with-temp-buffer
    (emacs-lisp-mode)
    (should (memq ?= (rc/gptel-complete-trigger-chars)))
    (insert "(setq x =")
    (should (rc/gptel-complete-line-end-trigger-p))))

(ert-deftest rc/gptel-complete-c-ts-rule-includes-equals-trigger ()
  
  :tags '(domain/complete-language-rules prio/2)(let ((rule (rc/gptel-complete-mode-rule 'c-ts-mode)))
    (should rule)
    (should (memq ?= (plist-get rule :trigger-chars)))
    (should (eq (plist-get rule :direct-char-predicate)
                'rc/gptel-complete-c-family-direct-char-trigger-p))
    (should (eq (plist-get (rc/gptel-complete-followup-rule 'c-ts-mode) :split)
                'blank-or-terminator))))

(ert-deftest rc/gptel-complete-cpp-ts-rule-includes-equals-trigger ()
  
  :tags '(domain/complete-language-rules prio/2)(let ((rule (rc/gptel-complete-mode-rule 'c++-ts-mode)))
    (should rule)
    (should (memq ?= (plist-get rule :trigger-chars)))
    (should (eq (plist-get rule :line-end-predicate)
                'rc/gptel-complete-cpp-line-end-trigger-p))
    (should (eq (plist-get rule :direct-char-predicate)
                'rc/gptel-complete-c-family-direct-char-trigger-p))))

(ert-deftest rc/gptel-complete-cpp-direct-char-trigger-requires-double-colon ()
  
  :tags '(domain/complete-language-rules prio/2)(with-temp-buffer
    (c++-mode)
    (insert "std:")
    (should-not (eq (rc/gptel-complete-trigger-match-kind ?:) 'direct-char))
    (insert ":")
    (should (eq (rc/gptel-complete-trigger-match-kind ?:) 'direct-char))))

(ert-deftest rc/gptel-complete-cpp-direct-char-trigger-distinguishes-arrow-from-template-close ()
  
  :tags '(domain/complete-language-rules prio/2)(with-temp-buffer
    (c++-mode)
    (insert "foo<Bar>")
    (should-not (eq (rc/gptel-complete-trigger-match-kind ?>) 'direct-char))
    (erase-buffer)
    (insert "ptr->")
    (should (eq (rc/gptel-complete-trigger-match-kind ?>) 'direct-char))))

(ert-deftest rc/gptel-complete-c-ts-direct-char-trigger-requires-arrow-not-template-close ()
  
  :tags '(domain/complete-language-rules prio/2)(with-temp-buffer
    (c-ts-mode)
    (insert "ptr->")
    (should (eq (rc/gptel-complete-trigger-match-kind ?>) 'direct-char))))

(ert-deftest rc/gptel-complete-cpp-line-end-trigger-matches-control-condition ()
  
  :tags '(domain/complete-language-rules prio/2)(with-temp-buffer
    (c++-mode)
    (insert "if (ready)")
    (should (rc/gptel-complete-line-end-trigger-p))
    (should (eq (rc/gptel-complete-trigger-match-kind ?\)) 'line-end))
    (erase-buffer)
    (c++-mode)
    (insert "work();")
    (should (rc/gptel-complete-line-end-trigger-p))
    (should (eq (rc/gptel-complete-trigger-match-kind ?\;) 'line-end))))

(ert-deftest rc/gptel-complete-cpp-line-end-trigger-matches-template-call-tail ()
  
  :tags '(domain/complete-language-rules prio/2)(with-temp-buffer
    (c++-mode)
    (insert "auto value = makeThing<int>(input)")
    (should (rc/gptel-complete-line-end-trigger-p))
    (should (eq (rc/gptel-complete-trigger-match-kind ?\)) 'line-end))
    (erase-buffer)
    (c++-mode)
    (insert "node->child().value()")
    (should (rc/gptel-complete-line-end-trigger-p))
    (should (eq (rc/gptel-complete-trigger-match-kind ?\)) 'line-end))))

(ert-deftest rc/gptel-complete-java-rule-includes-new-and-dot-triggers ()
  
  :tags '(domain/complete-language-rules prio/2)(let ((rule (rc/gptel-complete-mode-rule 'java-mode)))
    (should rule)
    (should (memq ?. (plist-get rule :trigger-chars)))
    (should (memq ?@ (plist-get rule :trigger-chars)))
    (should (memq ?= (plist-get rule :trigger-chars)))
    (should (eq (plist-get rule :line-end-predicate)
                'rc/gptel-complete-java-line-end-trigger-p))
    (should (string-match-p "\\\\_<new\\\\_>" (plist-get rule :line-end-regexp)))))

(ert-deftest rc/gptel-complete-java-line-end-trigger-matches-new ()
  
  :tags '(domain/complete-language-rules prio/2)(with-temp-buffer
    (java-mode)
    (insert "Thing value = new")
    (should (rc/gptel-complete-line-end-trigger-p))
    (should (eq (rc/gptel-complete-trigger-match-kind ?w) 'line-end))))

(ert-deftest rc/gptel-complete-python-line-end-trigger-matches-colon ()
  
  :tags '(domain/complete-language-rules prio/2)(with-temp-buffer
    (python-mode)
    (insert "if ready:")
    (should (rc/gptel-complete-line-end-trigger-p))))

(ert-deftest rc/gptel-complete-python-line-end-trigger-matches-else-and-finally ()
  
  :tags '(domain/complete-language-rules prio/2)(with-temp-buffer
    (python-mode)
    (insert "else")
    (should (rc/gptel-complete-line-end-trigger-p))
    (should (eq (rc/gptel-complete-trigger-match-kind ?e) 'line-end))
    (erase-buffer)
    (python-mode)
    (insert "finally")
    (should (rc/gptel-complete-line-end-trigger-p))
    (should (eq (rc/gptel-complete-trigger-match-kind ?y) 'line-end))))

(ert-deftest rc/gptel-complete-python-indent-followup-splits-dedented-tail ()
  
  :tags '(domain/complete-language-rules risk/style prio/2)(with-temp-buffer
    (python-mode)
    (let* ((parts (rc/gptel-complete-split-followup
                   "for item in items:\n    total += item\nreturn total"))
           (display (car parts))
           (followups (cadr parts)))
      (should (equal display "for item in items:"))
      (should (equal followups '("\n    total += item"
                                 "\nreturn total"))))))

(ert-deftest rc/gptel-complete-java-line-end-trigger-matches-annotation-and-lambda ()
  
  :tags '(domain/complete-language-rules prio/2)(with-temp-buffer
    (java-mode)
    (insert "@Override")
    (should (rc/gptel-complete-line-end-trigger-p))
    (erase-buffer)
    (java-mode)
    (insert "items.stream().map(x ->")
    (should (rc/gptel-complete-line-end-trigger-p))))

(ert-deftest rc/gptel-complete-java-line-end-trigger-matches-control-condition ()
  
  :tags '(domain/complete-language-rules prio/2)(with-temp-buffer
    (java-mode)
    (insert "while (ready)")
    (should (rc/gptel-complete-line-end-trigger-p))
    (should (eq (rc/gptel-complete-trigger-match-kind ?\)) 'line-end))
    (erase-buffer)
    (java-mode)
    (insert "catch (IOException ex)")
    (should (rc/gptel-complete-line-end-trigger-p))
    (should (eq (rc/gptel-complete-trigger-match-kind ?\)) 'line-end))
    (erase-buffer)
    (java-mode)
    (insert "value();")
    (should (rc/gptel-complete-line-end-trigger-p))
    (should (eq (rc/gptel-complete-trigger-match-kind ?\;) 'line-end))))

(ert-deftest rc/gptel-complete-java-line-end-trigger-matches-method-chain-tail ()
  
  :tags '(domain/complete-language-rules prio/2)(with-temp-buffer
    (java-mode)
    (insert "items.stream().map(x -> normalize(x))")
    (should (rc/gptel-complete-line-end-trigger-p))
    (should (eq (rc/gptel-complete-trigger-match-kind ?\)) 'line-end))))

(ert-deftest rc/gptel-complete-policy-rule-drives-followup-style ()
  
  :tags '(domain/complete-language-rules risk/style prio/2)(let ((rule (rc/gptel-complete-followup-rule 'python-mode)))
    (should rule)
    (should (eq (plist-get rule :split) 'indent-block))))

(ert-deftest rc/gptel-complete-cpp-rule-preserves-vertical-spacing ()
  
  :tags '(domain/complete-language-rules risk/style prio/2)(let ((rule (rc/gptel-complete-mode-rule 'c++-mode)))
    (should rule)
    (should (string-match-p "vertical spacing" (plist-get rule :extra)))
    (should (string-match-p "blank lines" (plist-get rule :extra)))))

(ert-deftest rc/gptel-complete-python-rule-exposes-followup-splitter ()
  
  :tags '(domain/complete-language-rules prio/2)(let ((rule (rc/gptel-complete-mode-rule 'python-mode)))
    (should (eq (plist-get rule :followup-splitter)
                'rc/gptel-complete-python-split-followup))))

(ert-deftest rc/gptel-complete-python-ts-rule-matches-python-policy ()
  
  :tags '(domain/complete-language-rules prio/2)(let ((rule (rc/gptel-complete-mode-rule 'python-ts-mode)))
    (should rule)
    (should (memq ?= (plist-get rule :trigger-chars)))
    (should (string-match-p "\\\\_<finally\\\\_>" (plist-get rule :line-end-regexp)))
    (should (eq (plist-get (rc/gptel-complete-followup-rule 'python-ts-mode) :split)
                'indent-block))))

(ert-deftest rc/gptel-complete-java-ts-rule-matches-java-policy ()
  
  :tags '(domain/complete-language-rules prio/2)(let ((rule (rc/gptel-complete-mode-rule 'java-ts-mode)))
    (should rule)
    (should (memq ?@ (plist-get rule :trigger-chars)))
    (should (string-match-p "\\\\_<throws\\\\_>" (plist-get rule :line-end-regexp)))
    (should (eq (plist-get (rc/gptel-complete-followup-rule 'java-ts-mode) :split)
                'blank-or-terminator))))
(provide 'ai-complete-language-rules-test)
;;; ai-complete-language-rules-test.el ends here
