;;; ox-reveal.el --- reveal.js Presentation Back-End for Org Export Engine

;; Author: Yujie Wen & Zech Xu
;; Created: 2014-04-27
;; Version: 1.0
;; Package-Requires: ((org "8.0"))
;; Keywords: outlines, hypermedia, slideshow, presentation

;; This file is not part of GNU Emacs.

;;; Copyright Notice:

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.

;; Please see "Readme.org" for detail introductions.

;;; Code:

(require 'ox-html)
(eval-when-compile (require 'cl))

(org-export-define-derived-backend 'reveal 'html

  :menu-entry
  '(?R "Export to reveal.js HTML Presentation"
       ((?R "To file" org-reveal-export-to-html)
        (?B "To file and Browse" org-reveal-export-to-html-and-browse)))

  :options-alist
  '(;; other text for title slide;
    ;; each "#+OTHER" line will be a line in title slide
    ;; default is empty
    (:other  "OTHER" nil "" newline)
    ;; Display controls in the bottom right corner
    (:reveal-control nil "reveal_control" t t)
    ;; Display a presentation progress bar
    (:reveal-progress nil "reveal_progress" t t)
    ;; Push each slide change to the browser history
    (:reveal-history nil  "reveal_history" nil t)
    ;; Vertical centering of slides
    (:reveal-center nil "reveal_center" t t)
    ;; Enables touch navigation on devices with touch input
    (:reveal-touch nil "reveal_touch" t t)
    ;; Enable keyboard navigation
    (:reveal-keyboard nil "reveal_keyboard" t t)
    ;; Display the page number of the current slide
    (:reveal-slide-number nil "reveal_slide_number" t t)
    ;; Enable slide thumbnail overview
    (:reveal-overview nil "reveal_overview" t t)
    ;; Number of milliseconds between automatically proceeding to the next slide
    ;; no autoslide by setting to 0.
    (:reveal-autoslide nil "reveal_autoslide" 0 t)
    ;; the headline levels used for nested slides
    (:reveal-hlevel nil "reveal_hlevel"  1 t)
    (:reveal-width  nil "reveal_width"  -1 t) ; slide width
    (:reveal-height nil "reveal_height" -1 t) ; slide height
    ;; (:reveal-min-scale nil "reveal_min_scale" -1 t)
    ;; (:reveal-max-scale nil "reveal_max_scale" -1 t)
    ;; enable mathjax by default. To disable mathjax:
    ;; #+OPTIONS: reveal_mathjax:nil
    (:reveal-mathjax nil "reveal_mathjax" t t)
    (:reveal-root "REVEAL_ROOT" nil org-reveal-root t)
    (:reveal-margin "REVEAL_MARGIN" nil "-1" t) ; slide margin
    (:reveal-max-scale "REVEAL_MAX_SCALE" nil "-1" t)
    (:reveal-min-scale "REVEAL_MIN_SCALE" nil "-1" t)
    (:reveal-trans "REVEAL_TRANS" nil org-reveal-transition t)
    (:reveal-speed "REVEAL_SPEED" nil org-reveal-transition-speed t)
    (:reveal-theme "REVEAL_THEME" nil org-reveal-theme t)
    ;; extra CSS and js.
    (:reveal-extra-css "REVEAL_EXTRA_CSS" nil nil nil)
    (:reveal-extra-js "REVEAL_EXTRA_JS" nil nil nil)
    ;; template for title slide
    (:reveal-title-slide-temp "REVEAL_TITLE_SLIDE_TEMP" nil org-reveal-title-slide-temp t)
    (:reveal-title-slide-attr "REVEAL_TITLE_SLIDE_ATTR" nil nil space)
    ;; REVEAL_HEAD is similar to HTML_HEAD
    (:reveal-head "REVEAL_HEAD" nil org-reveal-head newline))

  :translate-alist
  '((export-block . org-reveal-export-block)
    (headline . org-reveal-headline)
    (inner-template . org-reveal-inner-template)
    (item . org-reveal-item)
    (keyword . org-reveal-keyword)
    (paragraph . org-reveal-paragraph)
    (section . org-reveal-section)
    (src-block . org-reveal-src-block)
    ;; (footnote-reference . org-html-footnote-reference)
    ;; (footnote-definition . org-reveal-footnote-definition)
    (template . org-reveal-template))

  :export-block '("REVEAL" "NOTES"))

;; add shortcut for notes
(add-to-list 'org-structure-template-alist
             '("n" "#+BEGIN_NOTES\n?\n#+END_NOTES" "<notes>\n?\n</notes>"))


(defcustom org-reveal-root ""
  "The root directory of reveal.js packages.
It is the directory within which js/reveal.min.js is.
Default is empty string, i.e., current directory."
  :group 'org-export-reveal
  :type 'string)

(defcustom org-reveal-footnote-format "[%s]"
  "The format for the footnote reference.
%s will be replaced by the footnote reference itself."
  :group 'org-export-reveal
  :type 'string)

(defcustom org-reveal-title-slide-temp
  "<h1>%t</h1>\n<h2>%a</h2>\n<h2>%e</h2>\n<h3>%d</h3>"
  "Format template to specify title page slide.
See `org-html-postamble-format' for the valid elements which
can be include."
  :group 'org-export-reveal
  :type 'string)

(defcustom org-reveal-transition "default"
  "Reveal transistion style."
  :group 'org-export-reveal
  :type 'string)

(defcustom org-reveal-transition-speed "default"
  "Reveal transistion speed."
  :group 'org-export-reveal
  :type 'string)

(defcustom org-reveal-theme "black"
  "Reveal theme."
  :group 'org-export-reveal
  :type 'string)

(defcustom org-reveal-head nil
  "Preamble contents for head part."
  :group 'org-export-reveal
  :type 'string)


(defun frag-class (frag)
  "Return proper HTML string description of fragment style of the slide."
  (cond
   ((stringp frag) (format " class=\"fragment %s\"" frag))
   (t nil)))

(defun if-format (fmt val)
  (if val (format fmt val) ""))

(defun org-reveal-export-block (export-block contents info)
  "Transocde a EXPORT-BLOCK element from Org to Reveal.
CONTENTS is nil. NFO is a plist holding contextual information."
  (let ((block-type (org-element-property :type export-block))
        (block-string (org-element-property :value export-block)))
    (cond ((string= block-type "NOTES")
           (concat
            "<aside class=\"notes\">\n"
            (org-export-string-as block-string 'html 'body-only)
            "</aside>"))
          ((string= block-type "HTML")
           (org-remove-indentation block-string)))))

(defun org-reveal-headline (headline contents info)
  "Transcode a HEADLINE element from Org to Reveal.
CONTENTS holds the contents of the headline. INFO is a plist
holding contextual information."
  ;; First call org-html-headline to get the formatted HTML contents.
  ;; Then add enclosing <section> tags to mark slides.
  (setq contents (or contents ""))
  (let* ((numberedp (org-export-numbered-headline-p headline info))
         (level (org-export-get-relative-level headline info))
         (text (org-export-data (org-element-property :title headline) info))
         (todo (and (plist-get info :with-todo-keywords)
                    (let ((todo (org-element-property :todo-keyword headline)))
                      (and todo (org-export-data todo info)))))
         (todo-type (and todo (org-element-property :todo-type headline)))
         (tags (and (plist-get info :with-tags)
                    (org-export-get-tags headline info)))
         (priority (and (plist-get info :with-priority)
                        (org-element-property :priority headline)))
         ;; Create the headline text.
         (full-text (org-html-format-headline--wrap headline info)))
    (cond
     ;; Case 1: This is a footnote section: ignore it.
     ((org-element-property :footnote-section-p headline) nil)
     ;; Case 2. This is a deep sub-tree: export it as a list item.
     ;;         Also export as items headlines for which no section
     ;;         format has been found.
     ((org-export-low-level-p headline info)
      ;; Build the real contents of the sub-tree.
      (let* ((type (if numberedp 'ordered 'unordered))
             (itemized-body (org-reveal-format-list-item
                             contents type nil info nil 'none full-text)))
        (concat
         (and (org-export-first-sibling-p headline info)
              (org-html-begin-plain-list type))
         itemized-body
         (and (org-export-last-sibling-p headline info)
              (org-html-end-plain-list type)))))
     ;; Case 3. Standard headline.  Export it as a section.
     (t
      (let* ((level1 (+ level (1- org-html-toplevel-hlevel)))
             (hlevel (plist-get info :reveal-hlevel))
             (first-content (car (org-element-contents headline))))
        (concat
         (if (or (/= level 1)
                 (not (org-export-first-sibling-p headline info)))
             ;; Stop previous slide.
             "</section>\n")
         (if (eq level hlevel)
             ;; Add an extra "<section>" to group following slides
             ;; into vertical ones.
             "<section>\n")
         ;; Start a new slide.
         (format "<section id=\"%s\" %s%s%s%s%s%s%s>\n"
                 (or (org-element-property :CUSTOM_ID headline)
                     (concat "sec-"
                             (mapconcat 'number-to-string
                                        (org-export-get-headline-number headline info)
                                        "-")))
                 (if-format " data-state=\"%s\""
                            (org-element-property :REVEAL_DATA_STATE headline))
                 (if-format " data-transition=\"%s\""
                            (org-element-property :REVEAL_DATA_TRANSITION headline))
                 (if-format " data-background=\"%s\""
                            (org-element-property :REVEAL_DATA_BG headline))
                 (if-format " data-background-size=\"%s\""
                            (org-element-property :REVEAL_DATA_BG_SIZE headline))
                 (if-format " data-background-repeat=\"%s\""
                            (org-element-property :REVEAL_DATA_BG_REPEAT headline))
                 (if-format " data-background-transition=\"%s\""
                            (org-element-property :REVEAL_DATA_BG_TRANS headline))
                 (if-format " %s" (org-element-property :REVEAL_DATA_EXTRA headline)))
         ;; The HTML content of this headline.
         (format "\n<h%d%s>%s</h%d>\n"
                 level1
                 (if-format " class=\"fragment %s\""
                            (org-element-property :REVEAL-FRAG headline))
                 full-text
                 level1)
         ;; When there is no section, pretend there is an empty
         ;; one to get the correct <div class="outline- ...>
         ;; which is needed by `org-info.js'.
         (if (not (eq (org-element-type first-content) 'section))
             (concat (org-reveal-section first-content "" info)
                     contents)
           contents)
         (if (= level hlevel)
             ;; Add an extra "</section>" to stop vertical slide
             ;; grouping.
             "</section>\n")
         (if (and (= level 1)
                  (org-export-last-sibling-p headline info))
             ;; Last head 1. Stop all slides.
             "</section>")))))))

(defgroup org-export-reveal nil
  "Options for exporting Org-mode files to reveal.js HTML pressentations."
  :tag "Org Export reveal"
  :group 'org-export)


(defun org-reveal-stylesheets (info)
  "Return the HTML contents for declaring reveal stylesheets
using custom variable `org-reveal-root'."
  (let* ((root-dir (plist-get info :reveal-root))
         (css-dir (concat (file-name-as-directory root-dir) "css"))
         (min-css-file (concat (file-name-as-directory css-dir) "reveal.css"))
         (theme-dir (concat (file-name-as-directory css-dir) "theme"))
         (theme-file (concat (file-name-as-directory theme-dir)
                             (format "%s.css" (plist-get info :reveal-theme))))
         (extra-css-file (plist-get info :reveal-extra-css))
         (lib-css-path (mapconcat 'file-name-as-directory `(,root-dir "lib" "css") ""))
         (zenburn-css-file (concat lib-css-path "zenburn.css")))
    (format "
<link rel=\"stylesheet\" href=\"%s\"/>
<link rel=\"stylesheet\" href=\"%s\" id=\"theme\"/>
<link rel=\"stylesheet\" href=\"%s\" id=\"extra\"/>

<!-- For code syntax highlighting -->
<link rel=\"stylesheet\" href=\"%s\">

<!-- For specific styles: footnote and code -->
<style>
    .reveal section div.footdef {
        font-size: 0.6em;
        text-align: left;
    }

    .reveal section code {
        border:2px outset grey;
    }

    /* change center alignment to left */
    /* .reveal section p {  */
    /*    text-align: left;  */
    /* }  */

</style>

<!-- For PDF export: URL?print-pdf#/ -->
<script>
    var link = document.createElement( 'link' );
    link.rel = 'stylesheet';
    link.type = 'text/css';
    link.href = window.location.search.match( /print-pdf/gi ) ? '%s/css/print/pdf.css' : '%s/css/print/paper.css';
    document.getElementsByTagName( 'head' )[0].appendChild( link );
</script>
"
            min-css-file
            theme-file
            (if extra-css-file extra-css-file "")
            zenburn-css-file
            root-dir
            root-dir)))


(defun org-reveal-scripts (info)
  "Return the necessary scripts for initializing reveal.js using
custom variable `org-reveal-root'."
  (let* ((root-dir (plist-get info :reveal-root))
         (js-path (mapconcat 'file-name-as-directory `(,root-dir "js") ""))
         (lib-js-path (mapconcat 'file-name-as-directory `(,root-dir "lib" "js") ""))
         (plugin-path (mapconcat 'file-name-as-directory `(,root-dir "plugin") ""))
         (markdown-path (mapconcat 'file-name-as-directory `(,plugin-path "markdown") ""))
         (extra-js (plist-get info :reveal-extra-js)))
    (concat
     (format "<script src=\"%s\"></script>\n<script src=\"%s\"></script>\n"
             (concat lib-js-path "head.min.js")
             (concat js-path "reveal.min.js"))
     "<script>\n"
     (format "
           // Full list of configuration options available here:
           // https://github.com/hakimel/reveal.js#configuration
           Reveal.initialize({
                  controls: %s,
                  progress: %s,
                  history: %s,
                  center: %s,
                  slideNumber: %s,

                  keyboard: %s,
                  touch: %s,
                  overview: %s,
                  %s

                  autoSlide: %d, // Number of milliseconds between automatically proceeding to the next slide
                  theme: Reveal.getQueryHash().theme, // available themes are in /css/theme
                  transition: Reveal.getQueryHash().transition || '%s', // default/cube/page/concave/zoom/linear/fade/none
                  transitionSpeed: '%s',\n"
             (if (plist-get info :reveal-control) "true" "false")
             (if (plist-get info :reveal-progress) "true" "false")
             (if (plist-get info :reveal-history) "true" "false")
             (if (plist-get info :reveal-center) "true" "false")
             (if (plist-get info :reveal-slide-number) "true" "false")
             (if (plist-get info :reveal-keyboard) "true" "false")
             (if (plist-get info :reveal-touch) "true" "false")
             (if (plist-get info :reveal-overview) "true" "false")
             (let ((width (plist-get info :reveal-width))
                   (height (plist-get info :reveal-height))
                   (margin (string-to-number (plist-get info :reveal-margin)))
                   (min-scale (string-to-number (plist-get info :reveal-min-scale)))
                   (max-scale (string-to-number (plist-get info :reveal-max-scale))))
               (concat
                (if (> width 0)     (format "width: %d,      //slide width\n" width) "")
                (if (> height 0)    (format "height: %d,     //slide height\n" height) "")
                (if (>= margin 0)   (format "margin: %.2f,   //slide margin\n" margin) "")
                (if (> min-scale 0) (format "minScale: %.2f, //slide min scaling factor\n" min-scale) "")
                (if (> max-scale 0) (format "maxScale: %.2f, //slide max scaling factor\n" max-scale) "")))

             (plist-get info :reveal-autoslide)
             (plist-get info :reveal-trans)
             (plist-get info :reveal-speed))

     (format "
                  // Optional libraries used to extend on reveal.js
                  dependencies: [
                       { src: '%s', condition: function() { return !document.body.classList; } }
                     , { src: '%s', condition: function() { return !!document.querySelector( '[data-markdown]' ); } }
                     , { src: '%s', condition: function() { return !!document.querySelector( '[data-markdown]' ); } }
                     , { src: '%s', async: true, callback: function() { hljs.initHighlightingOnLoad(); } }
                     , { src: '%s', async: true, condition: function() { return !!document.body.classList; } }
                     , { src: '%s', async: true, condition: function() { return !!document.body.classList; } }
                     // , { src: '%s', async: true, condition: function() { return !!document.body.classList; } }
                     // , { src: '%s', async: true, condition: function() { return !!document.body.classList; } }
                     %s
                  ]
           });\n"
             (concat lib-js-path "classList.js")
             (concat markdown-path "showdown.js")
             (concat markdown-path "markdown.js")
             (concat plugin-path
                     (file-name-as-directory "highlight")
                     "highlight.js")
             (concat plugin-path
                     (file-name-as-directory "zoom-js")
                     "zoom.js")
             (concat plugin-path
                     (file-name-as-directory "notes")
                     "notes.js")
             (concat plugin-path
                     (file-name-as-directory "search")
                     "search.js")
             (concat plugin-path
                     (file-name-as-directory "remotes")
                     "remotes.js")
             (if extra-js (concat ", " extra-js) ""))

     "</script>\n")))

(defun org-reveal-toc-headlines-r (headlines info prev_level hlevel prev_x prev_y)
  "Generate toc headline text recursively."
  (let* ((headline (car headlines))
         (text (org-export-data (org-element-property :title headline) info))
         (level (org-export-get-relative-level headline info))
         (x (if (<= level hlevel) (+ prev_x 1) prev_x))
         (y (if (<= level hlevel) 0 (+ prev_y 1)))
         (remains (cdr headlines))
         (remain-text
          (if remains
              ;; Generate text for remain headlines
              (org-reveal-toc-headlines-r remains info level hlevel x y)
            "")))
    (concat
     ;; Need to start a new level of unordered list
     (cond ((> level prev_level) "<ul>\n")
           ;; Need to end previous list item and the whole list.
           ((< level prev_level) "</li>\n</ul>\n")
           ;; level == prev_level, Need to end previous list item.
           (t "</li>\n"))
     (format "<li>\n<a href=\"#%s\">%s</a>\n%s"
             (or (org-element-property :CUSTOM_ID headline)
                 (concat "sec-" (mapconcat 'number-to-string
                                           (org-export-get-headline-number headline info)
                                           "-")))
             text remain-text))))

(defun org-reveal-toc-headlines (headlines info)
  "Generate the Reveal.js contents for headlines in table of contents.
Add proper internal link to each headline."
  (let ((level (org-export-get-relative-level (car headlines) info))
        (hlevel (plist-get info :reveal-hlevel)))
    (concat
     (format "<h2>%s</h2>"
             (org-export-translate "Table of Contents" :html info))
     (org-reveal-toc-headlines-r headlines info 0 hlevel 1 1)
     (if headlines "</li>\n</ul>\n" ""))))


(defun org-reveal-toc (depth info)
  "Build a slide of table of contents."
  (let ((headlines (org-export-collect-headlines info depth)))
    (and headlines
         (format "<section>\n%s</section>\n"
                 (org-reveal-toc-headlines headlines info)))))

(defun org-reveal-inner-template (contents info)
  "Return body of document string after HTML conversion.
CONTENTS is the transcoded contents string. INFO is a plist
holding export options."
  (concat
   ;; Table of contents.
   (let ((depth (plist-get info :with-toc)))
     (when depth (org-reveal-toc depth info)))
   ;; Document contents.
   contents))

(defun org-reveal-format-list-item
    (contents type checkbox info &optional term-counter-id frag headline)
  "Format a list item into Reveal.js HTML."
  (let* (;; The argument definition of `org-html-checkbox' differs
         ;; between Org-mode master and 8.2.5h. To deal both cases,
         ;; both argument definitions are tried here.
         (org-checkbox (condition-case nil
                           (org-html-checkbox checkbox info)
                         ;; In case of wrong number of arguments, try another one
                         ((debug wrong-number-of-arguments) (org-html-checkbox checkbox))))
         (checkbox (concat org-checkbox (and checkbox " "))))
    (concat
     (case type
       (ordered
        (concat
         "<li"
         (if-format " value=\"%s\"" term-counter-id)
         (frag-class frag)
         ">"
         (if headline (concat headline "<br/>"))))
       (unordered
        (concat
         "<li"
         (frag-class frag)
         ">"
         (if headline (concat headline "<br/>"))))
       (descriptive
        (concat
         "<dt"
         (frag-class frag)
         "><b>"
         (concat checkbox (or term-counter-id "(no term)"))
         "</b></dt><dd>")))
     (unless (eq type 'descriptive) checkbox)
     contents
     (case type
       (ordered "</li>")
       (unordered "</li>")
       (descriptive "</dd>")))))

(defun org-reveal-item (item contents info)
  "Transcode an ITEM element from Org to Reveal.
CONTENTS holds the contents of the item. INFO is aplist holding
contextual information."
  (let* ((plain-list (org-export-get-parent item))
         (type (org-element-property :type plain-list))
         (counter (org-element-property :counter item))
         (checkbox (org-element-property :checkbox item))
         (tag (let ((tag (org-element-property :tag item)))
                (and tag (org-export-data tag info))))
         (frag (org-export-read-attribute :attr_reveal plain-list :frag)))
    (org-reveal-format-list-item
     contents type checkbox info (or tag counter) frag)))

(defun org-reveal-parse-value (value &optional token)
  "Return HTML tags or perform SIDE EFFECT according to key.

Currently it only used to split a slide into 2 by inserting:
#+REVEAL_HTML: SPLIT
in the middle of the slide content.
This function can potentially be expanded to handle other cases."
  (pcase value
    ("SPLIT" "</section>\n<section>")
    (OTHER  OTHER)))

(defun org-reveal-keyword (keyword contents info)
  "Transcode a KEYWORD element from Org to HTML,
and may change custom variables as SIDE EFFECT.
CONTENTS is nil. INFO is a plist holding contextual information."
  (let ((key (org-element-property :key keyword))
        (value (org-element-property :value keyword)))
    (case (intern key)
      (REVEAL_HTML (org-reveal-parse-value value)))))

(defun org-reveal-paragraph (paragraph contents info)
  "Transcode a PARAGRAPH element from Org to Reveal HTML.
CONTENTS is the contents of the paragraph, as a string.  INFO is
the plist used as a communication channel."
  (let ((parent (org-export-get-parent paragraph)))
    (cond
     ((and (eq (org-element-type parent) 'item)
           (= (org-element-property :begin paragraph)
              (org-element-property :contents-begin parent)))
      ;; leading paragraph in a list item have no tags
      contents)
     ;; ((org-html-standalone-image-p paragraph info)
     ;;  ;; standalone image
     ;;  (let ((frag (org-export-read-attribute :attr_reveal paragraph :frag)))
     ;;         (if frag
     ;;             (progn
     ;;               ;; This is ugly; need to update if the output from
     ;;               ;; org-html-format-inline-image changes.
     ;;               (unless (string-match "class=\"figure\"" contents)
     ;;                 (error "Unexpected HTML output for image!"))
     ;;               (replace-match (concat "class=\"figure fragment " frag " \"") t t contents))
     ;;           contents)))
     (t (format "<p%s %s>\n%s</p>"
                (if-format " class=\"fragment %s\""
                           (org-export-read-attribute :attr_reveal paragraph :frag))
                (if-format " style=\"%s\""
                           (org-export-read-attribute :attr_reveal paragraph :style))
                contents)))))


(defun org-reveal-format-footnote-definition (n def)
  "Format the footnote definition numbered as N and defined as DEF.

This function is borrowed from `org-html-format-footnote-definition'."
  (format
   "<div class=\"footdef\">%s %s</div>\n"
   (format org-reveal-footnote-format
           (let* ((id (format "fn.%s" n))
                  (href (format " href=\"#fnr.%s\"" n))
                  (attributes (concat " class=\"footnum\"" href)))
             (org-html--anchor id n attributes)))
   def))

(defun org-reveal--footnotes-definitions (element info)
  "Return footnotes definitions in ELEMENT as a string.

This function is borrowed from `org-latex--delayed-footnotes-definition'.

INFO is a plist used as a communication channel.

Footnotes definitions are returned in the div of class footdef."
  (mapconcat (lambda (ref)
               (org-reveal-format-footnote-definition
                (org-export-get-footnote-number ref info)
                (org-trim (org-export-data (org-export-get-footnote-definition
                                            ref info)
                                           info))))
             ;; Find every footnote reference in ELEMENT.
             (let* (all-refs
                    search-refs    ; For byte-compiler.
                    (search-refs (function
                                  (lambda (data)
                                    ;; Return a list of all footnote references never seen
                                    ;; before in DATA.
                                    (org-element-map data 'footnote-reference
                                      (lambda (ref)
                                        (when (org-export-footnote-first-reference-p ref info)
                                          (push ref all-refs)
                                          (when (eq (org-element-property :type ref) 'standard)
                                            (funcall search-refs
                                                     (org-export-get-footnote-definition ref info)))))
                                      info)
                                    (reverse all-refs)))))
               (funcall search-refs element))
             ;; return empty string if no footnote is found.
             ""))

(defun org-reveal-section (section contents info)
  "Transcode a SECTION element from Org to Reveal.
CONTENTS holds the contents of the section. INFO is a plist
holding contextual information."
  ;; Just return the contents. No "<div>" tags.
  (concat contents
          ;; get all the footnote definitions of current section
          (org-reveal--footnotes-definitions section info)))


(defun org-reveal-src-block (src-block contents info)
  "Transcode a SRC-BLOCK element from Org to Reveal.
CONTENTS holds the contents of the item.  INFO is a plist holding
contextual information."
  (if (org-export-read-attribute :attr_html src-block :textarea)
      (org-html--textarea-block src-block)
    (let ((lang (org-element-property :language src-block))
          (caption (org-export-get-caption src-block))
          (code (org-html-format-code src-block info))
          (frag (org-export-read-attribute :attr_reveal src-block :frag))
          (label (let ((lbl (org-element-property :name src-block)))
                   (if (not lbl) ""
                     (format " id=\"%s\""
                             (org-export-solidify-link-text lbl))))))
      (if (not lang)
          (format "<pre %s%s>\n%s</pre>"
                  (or (frag-class frag) " class=\"example\"")
                  label
                  code)
        (format
         "<div class=\"org-src-container\">\n%s%s\n</div>"
         (if (not caption) ""
           (format "<label class=\"org-src-name\">%s</label>"
                   (org-export-data caption info)))
         (format "\n<pre %s%s>%s</pre>"
                 (or (frag-class frag)
                     (format " class=\"src src-%s\"" lang))
                 label code))))))

(defun org-reveal-template (contents info)
  "Return complete document string after HTML conversion.
contents is the transcoded contents string.
info is a plist holding export options."
  (concat
   (format "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<!DOCTYPE html>\n<html%s>\n<head>\n"
           (if-format " lang=\"%s\"" (plist-get info :language)))
   "<meta charset=\"utf-8\"/>\n"
   (if-format "<title>%s</title>\n" (org-export-data (plist-get info :title) info))
   (if-format "<meta name=\"author\" content=\"%s\"/>\n" (org-export-data (plist-get info :author) info))
   (if-format "<meta name=\"description\" content=\"%s\"/>\n" (plist-get info :description))
   (if-format "<meta name=\"keywords\" content=\"%s\"/>\n" (plist-get info :keywords))
   "\n<meta name=\"apple-mobile-web-app-capable\" content=\"yes\" />\n"
   "\n<meta name=\"apple-mobile-web-app-status-bar-style\" content=\"black-translucent\" />\n"
   (if-format "\n%s\n" (plist-get info :html-head))
   (org-reveal-stylesheets info)
   (if (plist-get info :reveal-mathjax)
       (org-html--build-mathjax-config info))
   (if-format "\n%s\n" (plist-get info :reveal-head))
   "</head>\n<body>\n"

   "<div class=\"reveal\">\n<div class=\"slides\">\n<section"
   (if-format " %s " (plist-get info :reveal-title-slide-attr))
   ">\n"
   (format-spec (plist-get info :reveal-title-slide-temp) (org-html-format-spec info))
   (if-format " <h3>%s </h3>"
              (mapconcat 'identity
                         (split-string (plist-get info :other) "\n")
                         "</h3><h3>"))
   "</section>\n"
   contents
   "</div>\n</div>\n"
   (org-reveal-scripts info)
   "</body>\n</html>\n"))



(defun org-reveal-export-to-html
    (&optional async subtreep visible-only body-only ext-plist)
  "Export current buffer to a reveal.js HTML file."
  (interactive)
  (let* ((extension (concat "." org-html-extension))
         (file (org-export-output-file-name extension subtreep)))
    (org-export-to-file 'reveal file
      async subtreep visible-only body-only ext-plist)))

(defun org-reveal-export-to-html-and-browse
    (&optional async subtreep visible-only body-only ext-plist)
  "Export current buffer to a reveal.js and browse HTML file."
  (interactive)
  (browse-url-of-file
   (expand-file-name
    (org-reveal-export-to-html async subtreep visible-only body-only ext-plist))))

(provide 'ox-reveal)

;;; ox-reveal.el ends here
