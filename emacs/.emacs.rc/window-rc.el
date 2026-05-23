;;; window-rc.el --- Window movement and layout  -*- lexical-binding: t; -*-

;;; Code:

(require 'windmove)

(setq windmove-wrap-around t
      split-height-threshold 0
      split-width-threshold nil)

(defcustom rc/window-resize-step-height 3
  "Default number of lines to resize vertically."
  :type 'integer
  :group 'windows)

(defcustom rc/window-resize-step-width 5
  "Default number of columns to resize horizontally."
  :type 'integer
  :group 'windows)

(defun rc/window-horizontal-neighbor-p ()
  "Return non-nil when current window has a left or right neighbor."
  (or (window-in-direction 'left)
      (window-in-direction 'right)))

(defun rc/window-resize-grow ()
  "Grow current window intelligently based on its layout."
  (interactive)
  (if (rc/window-horizontal-neighbor-p)
      (enlarge-window-horizontally rc/window-resize-step-width)
    (enlarge-window rc/window-resize-step-height)))

(defun rc/window-resize-shrink ()
  "Shrink current window intelligently based on its layout."
  (interactive)
  (if (rc/window-horizontal-neighbor-p)
      (shrink-window-horizontally rc/window-resize-step-width)
    (shrink-window rc/window-resize-step-height)))

(defconst rc/frame-transparency 85)

(defun rc/toggle-transparency ()
  "Toggle between opaque and semi-transparent frame."
  (interactive)
  (let ((frame-alpha (frame-parameter nil 'alpha)))
    (if (or (not frame-alpha)
            (= (cadr frame-alpha) 100))
        (set-frame-parameter nil 'alpha
                             `(,rc/frame-transparency
                               ,rc/frame-transparency))
      (set-frame-parameter nil 'alpha '(100 100)))))

(provide 'window-rc)
;;; window-rc.el ends here
