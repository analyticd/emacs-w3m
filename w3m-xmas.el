;;; w3m-xmas.el --- The stuffs to use w3m.el on XEmacs.

;; Copyright (C) 2001 TSUCHIYA Masatoshi <tsuchiya@pine.kuee.kyoto-u.ac.jp>

;; Authors: Yuuichi Teranishi  <teranisi@gohome.org>,
;;          TSUCHIYA Masatoshi <tsuchiya@pine.kuee.kyoto-u.ac.jp>
;; Keywords: w3m, WWW, hypermedia

;; w3m-xmas.el is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published
;; by the Free Software Foundation; either version 2 of the License,
;; or (at your option) any later version.

;; w3m-xmas.el is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with w3m.el; if not, write to the Free Software Foundation,
;; Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA


;;; Commentary:

;; This file contains the stuffs to use w3m.el on XEmacs.  For more
;; detail about w3m.el, see:
;;
;;    http://namazu.org/~tsuchiya/emacs-w3m/


;;; Code:
(require 'poe)
(require 'poem)

(provide 'w3m-xmas);; It is needed to avoid circular dependencies.
(require 'w3m)

;;; Handle images:
(defun w3m-create-image (url &optional no-cache)
  "Retrieve data from URL and create an image object.
If optional argument NO-CACHE is non-nil, cache is not used."
  (condition-case err
      (let ((type (w3m-retrieve url 'raw no-cache)))
	(when (w3m-image-type-available-p (setq type (w3m-image-type type)))
	  (let ((data (w3m-with-work-buffer (buffer-string))))
	    (make-glyph
	     (make-image-instance
	      (vector type :data data)
	      nil nil 'no-error)))))
    (error nil)))

(defun w3m-insert-image (beg end image)
  "Display image on the current buffer.
Buffer string between BEG and END are replaced with IMAGE."
  (let (extent glyphs)
    (while (setq extent (extent-at beg nil 'w3m-xmas-icon extent 'at))
      (setq glyphs (cons (extent-end-glyph extent) glyphs)))
    (setq extent (make-extent beg end))
    (set-extent-property extent 'invisible t)
    (set-extent-property extent 'w3m-xmas-icon t)
    (set-extent-end-glyph extent image)
    (while glyphs
      (setq extent (make-extent end end))
      (set-extent-property extent 'w3m-xmas-icon t)
      (set-extent-end-glyph extent (car glyphs))
      (setq glyphs (cdr glyphs))))
  ;; Detach an underlined face if it exists.
  (unless (car w3m-cache-underline-faces)
    (let ((face (get-text-property beg 'face)))
      (when (and face
		 (face-underline-p face))
	(setq beg (set-marker (make-marker)
			      (or (previous-single-property-change
				   (1+ beg) 'face)
				  (point-min)))
	      end (set-marker (make-marker)
			      (or (next-single-property-change beg 'face)
				  (point-max))))
	(put-text-property beg end 'face nil)
	(push (list beg end face) (cdr w3m-cache-underline-faces))))))

(defun w3m-remove-image (beg end)
  "Remove an image which is inserted between BEG and END."
  (let (extent)
    (while (setq extent (extent-at beg nil 'w3m-xmas-icon extent 'at))
      (if (extent-end-glyph extent)
	  (set-extent-end-glyph extent nil))
      (set-extent-property extent 'invisible nil))
    (while (setq extent (extent-at end nil 'w3m-xmas-icon extent 'at))
      (if (extent-end-glyph extent)
	  (set-extent-end-glyph extent nil))
      (set-extent-property extent 'invisible nil))))

(defun w3m-image-type-available-p (image-type)
  "Return non-nil if an image with IMAGE-TYPE can be displayed inline."
  (and (device-on-window-system-p)
       (featurep image-type)))

;;; Toolbar:
(defcustom w3m-use-toolbar (and (featurep 'toolbar) t)
  "Non-nil activates toolbar of w3m."
  :group 'w3m
  :type 'boolean)

(defun w3m-xmas-make-toolbar-buttons (buttons)
  (dolist (button buttons)
    (let ((up (expand-file-name (concat button "-up.xpm")
				w3m-icon-directory))
	  (down (expand-file-name (concat button "-down.xpm")
				  w3m-icon-directory))
	  (disabled (expand-file-name (concat button "-disabled.xpm")
				      w3m-icon-directory))
	  (icon (intern (concat "w3m-toolbar-" button "-icon"))))
      (if (file-exists-p up)
	  (set icon
	       (toolbar-make-button-list
		up
		(and (file-exists-p down) down)
		(and (file-exists-p disabled) disabled)))
	(error "Icon file %s not found" up)))))

(defun w3m-setup-toolbar ()
  "Setup toolbar."
  (when w3m-use-toolbar
    (w3m-xmas-make-toolbar-buttons w3m-toolbar-buttons)
    (set-specifier default-toolbar
		   (cons (current-buffer) w3m-toolbar))))

(defun w3m-update-toolbar ()
  "Update toolbar."
  (when w3m-use-toolbar
    (set-specifier default-toolbar
		   (cons (current-buffer) w3m-toolbar))))

;;; Menu
(defun w3m-setup-menu ()
  (when (and (featurep 'menubar)
	     current-menubar
	     (not (assoc (car w3m-menubar) current-menubar)))
    (set-buffer-menubar (cons w3m-menubar current-menubar))))

;;; Widget:
(eval-when-compile (require 'wid-edit))

(defun w3m-xmas-define-missing-widgets ()
  "Define some missing widgets."
  (unless (get 'coding-system 'widget-type)
    ;; The following codes are imported from wid-edit.el of Emacs 20.7.

    (defvar widget-coding-system-prompt-value-history nil
      "History of input to `widget-coding-system-prompt-value'.")

    (defun widget-coding-system-prompt-value (widget prompt value unbound)
      ;; Read coding-system from minibuffer.
      (intern
       (completing-read (format "%s (default %s) " prompt value)
			(mapcar (lambda (sym)
				  (list (symbol-name sym)))
				(coding-system-list)))))

    (defun widget-coding-system-action (widget &optional event)
      ;; Read a file name from the minibuffer.
      (let ((answer
	     (widget-coding-system-prompt-value
	      widget
	      (widget-apply widget :menu-tag-get)
	      (widget-value widget)
	      t)))
	(widget-value-set widget answer)
	(widget-apply widget :notify widget event)
	(widget-setup))))

    (define-widget 'coding-system 'symbol
      "A MULE coding-system."
      :format "%{%t%}: %v"
      :tag "Coding system"
      :prompt-history 'widget-coding-system-prompt-value-history
      :prompt-value 'widget-coding-system-prompt-value
      :action 'widget-coding-system-action)

  (unless (get 'other 'widget-type)
    ;; The following definition is imported from wid-edit.el of Emacs 20.7.
    (define-widget 'other 'sexp
      "Matches any value, but doesn't let the user edit the value.
This is useful as last item in a `choice' widget.
You should use this widget type with a default value,
as in (other DEFAULT) or (other :tag \"NAME\" DEFAULT).
If the user selects this alternative, that specifies DEFAULT
as the value."
      :tag "Other"
      :format "%t%n"
      :value 'other)))

(eval-after-load "wid-edit" '(w3m-xmas-define-missing-widgets))

;;; Coding systems:
(unless (fboundp 'coding-system-category)
  (defalias 'coding-system-category 'coding-system-type))

;;; Header line (emulating Emacs 21).
(defvar w3m-header-line-map (make-sparse-keymap))
(define-key w3m-header-line-map 'button2 'w3m-goto-url)

(defun w3m-setup-header-line ()
  "Setup header line (emulating Emacs 21)."
  (when (and w3m-use-header-line w3m-current-url
	     (eq 'w3m-mode major-mode))
    (goto-char (point-min))
    (insert "Location: ")
    (set-extent-property (make-extent (point-min) (point))
			 'face 'w3m-header-line-location-title-face)
    (let ((start (point))
	  (help "button2 prompts to input URL"))
      (insert w3m-current-url)
      (set-extent-properties (make-extent start (point))
			     (list 'face
				   'w3m-header-line-location-content-face
				   'mouse-face 'highlight
				   'keymap w3m-header-line-map
				   'help-echo help
				   'balloon-help help))
      (setq start (point))
      (insert-char ?\  (max 0 (- (window-width) (current-column) 1)))
      (set-extent-property (make-extent start (point))
			   'face 'w3m-header-line-location-content-face)
      (unless (eolp)
	(insert "\n")))))

;;; w3m-xmas.el ends here.
