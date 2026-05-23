;;; coverage-extract.el --- ERT tag scanner and coverage map generator -*- lexical-binding: t; -*-

;; Single source of truth for "test → metadata" mapping is the :tags slot
;; on each ert-deftest. This file owns:
;;   - the fixed tag vocabulary (domain/* risk/* prio/N)
;;   - validation helpers (used by rc/lint-all-tests-have-tags)
;;   - collection helpers (sorted, deterministic)
;;   - coverage-map / weakness-map generators
;;
;; See tests/exec-plans/active/01-inventory-and-coverage-map.md for design.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'subr-x)


;;;; Tag vocabulary -----------------------------------------------------------

(defconst rc/test-tag-domains
  '(action-request
    ask
    complete-state
    complete-trigger
    complete-cooldown
    complete-followup
    complete-context
    complete-language-rules
    complete-observe
    complete-coordination
    rewrite
    ui-panel
    ui-inspector
    replay
    toggle
    describe
    meta)
  "Closed vocabulary of valid `domain/*' tag suffixes.
`meta' covers tooling / lint / coverage self-tests.")

(defconst rc/test-tag-risks
  '(race
    coordination
    stale-cache
    style
    source-consistency
    protocol
    observability
    supersede
    accept-intent
    cache-hit)
  "Closed vocabulary of valid `risk/*' tag suffixes.")

(defconst rc/test-tag-prios '(1 2 3)
  "Closed vocabulary of valid `prio/N' tag suffixes.")


;;;; Tag introspection --------------------------------------------------------

(defun rc/test--tag-namespace (tag)
  "Return namespace symbol of TAG: domain, risk, prio, or unknown."
  (let ((name (symbol-name tag)))
    (cond
     ((string-prefix-p "domain/" name) 'domain)
     ((string-prefix-p "risk/" name)   'risk)
     ((string-prefix-p "prio/" name)   'prio)
     (t                                'unknown))))

(defun rc/test--tag-suffix (tag)
  "Return suffix string of TAG after the namespace slash."
  (let ((name (symbol-name tag)))
    (if (string-match "\\`[^/]+/\\(.+\\)\\'" name)
        (match-string 1 name)
      "")))

(defun rc/test-validate-tags (tags)
  "Return list of human-readable error strings for TAGS, or nil if valid."
  (let ((errors nil)
        (domain-count 0)
        (prio-count   0))
    (dolist (tag tags)
      (pcase (rc/test--tag-namespace tag)
        ('domain
         (cl-incf domain-count)
         (let ((suffix (intern (rc/test--tag-suffix tag))))
           (unless (memq suffix rc/test-tag-domains)
             (push (format "unknown domain tag: %s" tag) errors))))
        ('risk
         (let ((suffix (intern (rc/test--tag-suffix tag))))
           (unless (memq suffix rc/test-tag-risks)
             (push (format "unknown risk tag: %s" tag) errors))))
        ('prio
         (cl-incf prio-count)
         (let ((num (string-to-number (rc/test--tag-suffix tag))))
           (unless (memq num rc/test-tag-prios)
             (push (format "unknown prio tag: %s" tag) errors))))
        ('unknown
         (push (format "tag without namespace: %s" tag) errors))))
    (unless (= domain-count 1)
      (push (format "expected exactly 1 domain/* tag, got %d" domain-count)
            errors))
    (unless (= prio-count 1)
      (push (format "expected exactly 1 prio/* tag, got %d" prio-count)
            errors))
    (nreverse errors)))


;;;; Collection ---------------------------------------------------------------

(defun rc/test--known-test-p (sym)
  "Return non-nil if SYM is a defined ERT test we should consider."
  (and (symbolp sym)
       (fboundp 'ert-test-boundp)
       (ert-test-boundp sym)))

(defun rc/test-collect-tagged-tests ()
  "Return alist of (TEST-NAME . TAGS) for every known ERT test.
Sorted by TEST-NAME lexicographically for deterministic output."
  (let (result)
    (mapatoms
     (lambda (sym)
       (when (rc/test--known-test-p sym)
         (let* ((test (ert-get-test sym))
                (tags (ert-test-tags test)))
           (push (cons sym tags) result)))))
    (sort result (lambda (a b)
                   (string< (symbol-name (car a))
                            (symbol-name (car b)))))))


;;;; Lint helper (used by rc/lint-all-tests-have-tags) ------------------------

(defconst rc/test-lint-skip-names
  '(rc/lint-all-tests-have-tags)
  "Test names that should not be validated by the tag lint.
Avoids bootstrap problems where lint reports itself.")

(defun rc/test-lint-collect-errors ()
  "Return alist (TEST-NAME . ERRORS) for tests with invalid or missing tags."
  (let (result)
    (dolist (entry (rc/test-collect-tagged-tests))
      (let ((name (car entry))
            (tags (cdr entry)))
        (unless (memq name rc/test-lint-skip-names)
          (let ((errors (rc/test-validate-tags tags)))
            (when errors
              (push (cons name errors) result))))))
    (nreverse result)))

(defun rc/test-lint-format-errors (errors)
  "Format ERRORS alist into a human-readable multi-line string."
  (mapconcat
   (lambda (entry)
     (format "  %s: %s"
             (car entry)
             (mapconcat #'identity (cdr entry) "; ")))
   errors
   "\n"))


;;;; Generators ---------------------------------------------------------------

(defconst rc/test-generated-banner
  "<!-- Auto-generated by rc/test-generate-coverage-map. Do not edit. -->\n"
  "Header banner to mark a file as machine-produced.")

(defun rc/test--filter-by-namespace (tags namespace)
  "Return subset of TAGS that live under NAMESPACE (domain/risk/prio)."
  (cl-remove-if-not
   (lambda (tag) (eq (rc/test--tag-namespace tag) namespace))
   tags))

(defun rc/test--first-domain (tags)
  "Return the single domain tag in TAGS, or nil."
  (car (rc/test--filter-by-namespace tags 'domain)))

(defun rc/test--first-prio (tags)
  "Return the single prio tag in TAGS, or nil."
  (car (rc/test--filter-by-namespace tags 'prio)))

(defun rc/test--risk-tags (tags)
  "Return list of risk tags in TAGS."
  (rc/test--filter-by-namespace tags 'risk))

(defun rc/test-group-by-domain ()
  "Return alist (DOMAIN-TAG . LIST-OF-(NAME . TAGS)) sorted by DOMAIN-TAG."
  (let ((buckets (make-hash-table :test 'eq)))
    (dolist (entry (rc/test-collect-tagged-tests))
      (let ((domain (or (rc/test--first-domain (cdr entry))
                        'domain/UNTAGGED)))
        (push entry (gethash domain buckets nil))))
    (sort
     (cl-loop for k being the hash-keys of buckets
              collect (cons k (nreverse (gethash k buckets))))
     (lambda (a b)
       (string< (symbol-name (car a)) (symbol-name (car b)))))))

(defconst rc/test-weakness-domain-floor 3
  "Minimum total tests in a domain before its missing risks count as weakness.
Domains below this floor are considered low-volume and skipped: it is normal
for a single-test domain like `meta' to have zero coverage across all risks.")

(defun rc/test--domain-totals ()
  "Return alist (DOMAIN-TAG . TEST-COUNT) over all collected tests."
  (let ((totals (make-hash-table :test 'eq)))
    (dolist (entry (rc/test-collect-tagged-tests))
      (when-let ((domain (rc/test--first-domain (cdr entry))))
        (puthash domain (1+ (gethash domain totals 0)) totals)))
    (cl-loop for k being the hash-keys of totals
             collect (cons k (gethash k totals)))))

(defun rc/test-find-weakness ()
  "Return weakness cells: domain × risk pairs with low coverage.

Only domains with at least `rc/test-weakness-domain-floor' tests are
considered. For each such domain, every risk slot in
`rc/test-tag-risks' with <= 1 test is reported.

Returns list of plists:
  (:domain DOMAIN :risk RISK :count COUNT :domain-total TOTAL)
sorted by COUNT ascending, then DOMAIN name."
  (let* ((totals (rc/test--domain-totals))
         (eligible (cl-remove-if-not
                    (lambda (cell)
                      (>= (cdr cell) rc/test-weakness-domain-floor))
                    totals))
         (counts (make-hash-table :test 'equal)))
    (dolist (entry (rc/test-collect-tagged-tests))
      (let* ((tags   (cdr entry))
             (domain (rc/test--first-domain tags))
             (risks  (rc/test--risk-tags tags)))
        (when (and domain risks (assq domain eligible))
          (dolist (risk risks)
            (let ((key (cons domain risk)))
              (puthash key (1+ (gethash key counts 0)) counts))))))
    (let (weak)
      (dolist (domain-cell eligible)
        (let ((domain (car domain-cell))
              (total  (cdr domain-cell)))
          (dolist (risk rc/test-tag-risks)
            (let* ((rtag (intern (format "risk/%s" risk)))
                   (n    (gethash (cons domain rtag) counts 0)))
              (when (<= n 1)
                (push (list :domain domain :risk rtag
                            :count n :domain-total total)
                      weak))))))
      (sort weak (lambda (a b)
                   (if (= (plist-get a :count) (plist-get b :count))
                       (string< (symbol-name (plist-get a :domain))
                                (symbol-name (plist-get b :domain)))
                     (< (plist-get a :count) (plist-get b :count))))))))

(defun rc/test--format-coverage-row (entry)
  "Format ENTRY (NAME . TAGS) as one markdown table row."
  (let* ((name  (car entry))
         (tags  (cdr entry))
         (prio  (rc/test--first-prio tags))
         (risks (rc/test--risk-tags tags)))
    (format "| `%s` | %s | %s |"
            name
            (if risks
                (mapconcat #'symbol-name risks ", ")
              "_(none)_")
            (or prio "_(none)_"))))

(defun rc/test-generate-coverage-map (&optional out-file)
  "Write coverage map to OUT-FILE, defaulting to tests/generated/coverage-map.md."
  (let* ((default (expand-file-name
                   "tests/generated/coverage-map.md"
                   "/home/seeback/.emacs.rc/ai"))
         (path    (or out-file default))
         (groups  (rc/test-group-by-domain))
         (total   (length (rc/test-collect-tagged-tests))))
    (make-directory (file-name-directory path) t)
    (with-temp-file path
      (insert rc/test-generated-banner)
      (insert (format "# Coverage Map\n\nTotal tests: %d\n\n" total))
      (insert "By domain:\n\n")
      (dolist (group groups)
        (insert (format "- `%s`: %d\n" (car group) (length (cdr group)))))
      (insert "\n")
      (dolist (group groups)
        (insert (format "## `%s` (%d)\n\n" (car group) (length (cdr group))))
        (insert "| Test | Risks | Prio |\n")
        (insert "| --- | --- | --- |\n")
        (dolist (entry (cdr group))
          (insert (rc/test--format-coverage-row entry))
          (insert "\n"))
        (insert "\n")))
    path))

(defun rc/test-generate-weakness-map (&optional out-file)
  "Write weakness map to OUT-FILE, defaulting to tests/generated/weakness-map.md."
  (let* ((default (expand-file-name
                   "tests/generated/weakness-map.md"
                   "/home/seeback/.emacs.rc/ai"))
         (path    (or out-file default))
         (weak    (rc/test-find-weakness)))
    (make-directory (file-name-directory path) t)
    (with-temp-file path
      (insert rc/test-generated-banner)
      (insert "# Weakness Map\n\n")
      (insert (format "Cells with <= 1 test, restricted to domains with at least %d total tests.\n"
                      rc/test-weakness-domain-floor))
      (insert "Sorted by count ascending, then domain name.\n\n")
      (insert "| Domain | Risk | Tests | Domain Total |\n")
      (insert "| --- | --- | --- | --- |\n")
      (dolist (cell weak)
        (insert (format "| `%s` | `%s` | %d | %d |\n"
                        (plist-get cell :domain)
                        (plist-get cell :risk)
                        (plist-get cell :count)
                        (plist-get cell :domain-total)))))
    path))

(provide 'rc/test-coverage-extract)
;;; coverage-extract.el ends here
