;;; bulk-tag-injector.el --- One-shot tagger for ai-action-runtime-test.el -*- lexical-binding: t; -*-

;; Purpose: insert `:tags '(domain/X risk/Y ... prio/N)` into every
;; existing `(ert-deftest ...)` form whose body does not yet declare tags.
;;
;; Usage:
;;
;;   emacs --batch -Q \
;;     -l tests/tools/bulk-tag-injector.el \
;;     -f rc/test-bulk-tag-inject
;;
;; Rules below are heuristic; afterwards run the full ERT and let
;; rc/lint-all-tests-have-tags surface anything missed.

;;; Code:

(require 'cl-lib)
(require 'subr-x)

(defconst rc/bulk-tag--target-file
  "/home/seeback/.emacs.rc/ai/tests/ai-action-runtime-test.el")


;;;; Domain inference --------------------------------------------------------

(defun rc/bulk-tag--infer-domain (name)
  "Return domain symbol like `domain/complete-state' for test NAME."
  (let ((n (symbol-name name)))
    (cond
     ;; Specific UI / inspector / observe overrides have to come first.
     ((string-match-p "action-panel"          n) 'domain/ui-panel)
     ((string-match-p "action-detail-renderer" n) 'domain/ui-inspector)
     ((string-match-p "describe-action-state" n) 'domain/describe)
     ((string-match-p "replay-ai-trace"       n) 'domain/replay)

     ((string-prefix-p "rc/gptel-toggle-"  n) 'domain/toggle)
     ((string-prefix-p "rc/gptel-rewrite-" n) 'domain/rewrite)
     ((string-prefix-p "rc/gptel-ask-"     n) 'domain/ask)

     ;; complete-cooldown / policy
     ((string-match-p "complete-cooldown"             n) 'domain/complete-cooldown)
     ((string-match-p "complete-compute-next-policy"  n) 'domain/complete-cooldown)

     ;; complete-followup / continuation / accept-intent
     ((string-match-p "complete-followup"               n) 'domain/complete-followup)
     ((string-match-p "complete-after-accept"           n) 'domain/complete-followup)
     ((string-match-p "complete-next-edit"              n) 'domain/complete-followup)
     ((string-match-p "complete-go-to-next-location"    n) 'domain/complete-followup)
     ((string-match-p "complete-force-stop"             n) 'domain/complete-followup)
     ((string-match-p "complete-candidate-cycle"        n) 'domain/complete-followup)
     ((string-match-p "complete-split-followup"         n) 'domain/complete-followup)
     ((string-match-p "complete-indent-followup"        n) 'domain/complete-followup)
     ((string-match-p "complete-tab-install"            n) 'domain/complete-followup)

     ;; coordination (company / lsp / yas / capf / flymake / signature / env)
     ((string-match-p "complete-company"                n) 'domain/complete-coordination)
     ((string-match-p "complete-lsp"                    n) 'domain/complete-coordination)
     ((string-match-p "complete-flymake"                n) 'domain/complete-coordination)
     ((string-match-p "complete-notify-"                n) 'domain/complete-coordination)
     ((string-match-p "complete-maybe-abort-company"    n) 'domain/complete-coordination)
     ((string-match-p "complete-environment-policy"     n) 'domain/complete-coordination)
     ((string-match-p "complete-source-policy"          n) 'domain/complete-coordination)
     ((string-match-p "complete-manual-complete"        n) 'domain/complete-coordination)
     ((string-match-p "complete-auto-trigger-blocks-yasnippet" n) 'domain/complete-coordination)

     ;; trigger
     ((string-match-p "complete-auto-trigger"           n) 'domain/complete-trigger)
     ((string-match-p "complete-post-self-insert"       n) 'domain/complete-trigger)

     ;; context
     ((string-match-p "complete-request-context"        n) 'domain/complete-context)
     ((string-match-p "complete-context-rules"          n) 'domain/complete-context)

     ;; language-rules
     ((string-match-p "complete-policy-rule"            n) 'domain/complete-language-rules)
     ((string-match-p "complete-emacs-lisp-"            n) 'domain/complete-language-rules)
     ((string-match-p "complete-c-ts-"                  n) 'domain/complete-language-rules)
     ((string-match-p "complete-cpp-"                   n) 'domain/complete-language-rules)
     ((string-match-p "complete-python-"                n) 'domain/complete-language-rules)
     ((string-match-p "complete-java-"                  n) 'domain/complete-language-rules)

     ;; observe / stats / trace / diagnostics / status
     ((string-match-p "complete-observe"                n) 'domain/complete-observe)
     ((string-match-p "complete-stats-report"           n) 'domain/complete-observe)
     ((string-match-p "complete-export-trace"           n) 'domain/complete-observe)
     ((string-match-p "complete-status-indicator"       n) 'domain/complete-observe)
     ((string-match-p "complete-diagnose-mode"          n) 'domain/complete-observe)
     ((string-match-p "complete-requesting-indicator"   n) 'domain/complete-state)

     ;; ui-panel / ui-inspector overlaps for complete
     ((string-match-p "complete-hint-label"             n) 'domain/ui-panel)
     ((string-match-p "complete-multi-line-render"      n) 'domain/ui-panel)

     ;; shared request layer
     ((string-match-p "complete-shared-request"         n) 'domain/action-request)
     ((string-prefix-p "rc/gptel-action-"               n) 'domain/action-request)

     ;; complete-state catch-all (must be last among complete branches)
     ((string-match-p "complete-cache"                  n) 'domain/complete-state)
     ((string-match-p "complete-stale"                  n) 'domain/complete-state)
     ((string-match-p "complete-superseded"             n) 'domain/complete-state)
     ((string-match-p "complete-success-cache-reuse"    n) 'domain/complete-state)
     ((string-match-p "complete-state-summary"          n) 'domain/complete-state)
     ((string-match-p "complete-mode-handler"           n) 'domain/complete-state)
     ((string-match-p "complete-clear-user-reject"      n) 'domain/complete-state)
     ((string-match-p "complete-line-accept"            n) 'domain/complete-state)
     ((string-match-p "complete-word-accept"            n) 'domain/complete-state)
     ((string-match-p "complete-full-accept"            n) 'domain/complete-state)
     ((string-match-p "complete-compatible-typing"      n) 'domain/complete-state)
     ((string-match-p "complete-delete"                 n) 'domain/complete-state)
     ((string-match-p "complete-diverged"               n) 'domain/complete-state)
     ((string-match-p "complete-post-command-move"      n) 'domain/complete-state)
     ((string-match-p "complete-extract-parts"          n) 'domain/complete-state)
     ((string-match-p "complete-lifecycle-hook"         n) 'domain/complete-state)
     ((string-match-p "complete-sync-session-state"     n) 'domain/complete-state)
     ((string-match-p "complete-normalize"              n) 'domain/complete-state)
     ((string-match-p "complete-timeout"                n) 'domain/complete-state)

     ;; default — leave unknown so lint flags it
     (t 'domain/UNKNOWN))))


;;;; Risk inference ----------------------------------------------------------

(defun rc/bulk-tag--infer-risks (name)
  "Return list of risk tags for test NAME (may be nil)."
  (let ((n (symbol-name name))
        (risks nil))
    (when (string-match-p "stale" n)               (push 'risk/stale-cache risks))
    (when (string-match-p "cache" n)               (push 'risk/cache-hit risks))
    (when (string-match-p "superseded" n)          (push 'risk/supersede risks))
    (when (string-match-p
           "cancel-from-network\\|late-result\\|late-response\\|timeout\\|dedupes\\|dedup-\\|race"
           n)
      (push 'risk/race risks))
    (when (string-match-p
           "company\\|yas\\|yasnippet\\|lsp\\|capf\\|flymake\\|signature\\|org-src\\|tramp\\|minibuffer\\|read-only\\|coordination"
           n)
      (push 'risk/coordination risks))
    (when (string-match-p
           "does-not-leak\\|trigger-source\\|request-source\\|source-policy\\|source-marker"
           n)
      (push 'risk/source-consistency risks))
    (when (string-match-p
           "force-stop\\|force-followup\\|chain-limit\\|accept-intent\\|after-accept\\|partial"
           n)
      (push 'risk/accept-intent risks))
    (when (string-match-p
           "style\\|vertical-spacing\\|blank-line\\|indent\\|spacing"
           n)
      (push 'risk/style risks))
    (when (string-match-p
           "panel\\|inspector\\|hint-label\\|stats\\|trace\\|observe\\|diagnose\\|diagnostics\\|state-summary\\|status-indicator\\|requesting-indicator\\|export-trace\\|replay\\|describe"
           n)
      (push 'risk/observability risks))
    (delete-dups risks)))


;;;; Priority inference ------------------------------------------------------

(defun rc/bulk-tag--infer-prio (name)
  "Return prio symbol for test NAME."
  (let ((n (symbol-name name)))
    (cond
     ;; ⭐⭐⭐ high-risk gates
     ((string-match-p "does-not-leak"                    n) 'prio/3)
     ((string-match-p "does-not-fall-through"            n) 'prio/3)
     ((string-match-p "cancel-from-network.*does-not"    n) 'prio/3)
     ((string-match-p "late-response"                    n) 'prio/3)
     ((string-match-p "late-result"                      n) 'prio/3)
     ((string-match-p "timeout-records"                  n) 'prio/3)
     ((string-match-p "stale.*show.*marks-stale-visible" n) 'prio/3)
     ((string-match-p "superseded.*caches-and-finalizes" n) 'prio/3)
     ((string-match-p "superseded.*can-show-immediately" n) 'prio/3)
     ((string-match-p "complete-cooldown"                n) 'prio/3)
     ((string-match-p "force-stop"                       n) 'prio/3)
     ((string-match-p "chain-limit"                      n) 'prio/3)
     ((string-match-p "compute-next-policy"              n) 'prio/3)
     ((string-match-p "yasnippet"                        n) 'prio/3)
     ((string-match-p "company-started"                  n) 'prio/3)
     ((string-match-p "auto-trigger-dedupes"             n) 'prio/3)
     ((string-match-p "environment-policy"               n) 'prio/3)
     ((string-match-p "sync-session-state-does-not-leak" n) 'prio/3)
     ;; ⭐ low priority for trivial feature-loads and renderer happy paths
     ((string-match-p "feature-loads"                    n) 'prio/1)
     ((string-match-p "mode-handler-resolves"            n) 'prio/1)
     ((string-match-p "tab-install-binds"                n) 'prio/1)
     ;; default ⭐⭐
     (t 'prio/2))))


;;;; Buffer rewriter ---------------------------------------------------------

(defun rc/bulk-tag--has-tags-p ()
  "Non-nil if point is at an `(ert-deftest ...)` form that already declares :tags."
  (save-excursion
    (let ((start (point))
          (form-end (save-excursion (forward-sexp 1) (point))))
      (goto-char start)
      (re-search-forward ":tags[ \t\n]" form-end t))))

(defun rc/bulk-tag--insert-after-docstring (tags)
  "Insert TAGS string after the docstring of the current `(ert-deftest ...)`.
Point should be on the opening paren of the form."
  (save-excursion
    (down-list 1)              ; move past `(`
    (forward-sexp 2)           ; skip `ert-deftest` symbol and NAME
    (forward-sexp 1)           ; skip the empty arglist ()
    ;; Now we should be right after `()`. Move to docstring start.
    (skip-chars-forward " \t\n")
    (cond
     ((eq (char-after) ?\")
      (forward-sexp 1)         ; skip docstring
      (insert (format "\n  :tags '%s" tags)))
     (t
      ;; No docstring — insert right after arglist.
      (insert (format "\n  :tags '%s" tags))))))

(defun rc/bulk-tag--format-tags (domain risks prio)
  "Format DOMAIN + RISKS + PRIO into the elisp source representation."
  (let ((all (append (list domain) risks (list prio))))
    (format "(%s)" (mapconcat #'symbol-name all " "))))

(defun rc/test-bulk-tag-inject ()
  "Walk every (ert-deftest ...) in the target test file and inject :tags."
  (interactive)
  (let ((buf (find-file-noselect rc/bulk-tag--target-file))
        (touched 0)
        (skipped-existing 0)
        (skipped-unknown 0))
    (with-current-buffer buf
      (goto-char (point-min))
      (while (re-search-forward "^(ert-deftest \\([^ \t\n()]+\\) " nil t)
        (let* ((name  (intern (match-string 1)))
               (form-start (match-beginning 0)))
          (goto-char form-start)
          (cond
           ((rc/bulk-tag--has-tags-p)
            (cl-incf skipped-existing))
           (t
            (let* ((domain (rc/bulk-tag--infer-domain name))
                   (risks  (rc/bulk-tag--infer-risks name))
                   (prio   (rc/bulk-tag--infer-prio name))
                   (tags   (rc/bulk-tag--format-tags domain risks prio)))
              (cond
               ((eq domain 'domain/UNKNOWN)
                (cl-incf skipped-unknown)
                (message "[bulk-tag] UNKNOWN domain for: %s" name))
               (t
                (rc/bulk-tag--insert-after-docstring tags)
                (cl-incf touched))))))
          (forward-line 1)))
      (save-buffer))
    (message "[bulk-tag] touched=%d existing=%d unknown=%d"
             touched skipped-existing skipped-unknown)))

(provide 'rc/test-bulk-tag-injector)
;;; bulk-tag-injector.el ends here
